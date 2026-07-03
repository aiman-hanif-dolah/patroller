import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/enums.dart';
import '../models/hierarchy.dart';
import 'bundled_resources.dart';
import 'cli_env.dart';
import 'xctest_client.dart';

const _runnerReadyTimeoutMs = 120000;
const _driverArtifactRoot = 'patrol-simulator-driver';

const _driverArtifacts = (
  configFileName: 'patrol-simulator-driver-config.xctestrun',
  runnerAppFolderName: 'PatrolSimulatorDriverUITests-Runner.app',
  uiTestTargetName: 'PatrolSimulatorDriverUITests',
  runnerBundleId: 'studio.patrol.PatrolSimulatorDriverUITests.xctrunner',
);

class _XCTestSession {
  _XCTestSession({
    required this.udid,
    required this.port,
    required this.deviceType,
  });

  final String udid;
  final int port;
  final DeviceType deviceType;
  DriverState state = DriverState.starting;
  Process? xcodebuildProcess;
  Process? iproxyProcess;
  String? error;
  final List<String> logTail = [];
  Directory? workingDirectory;
}

class XCTestInstaller {
  XCTestInstaller._();

  static final XCTestInstaller instance = XCTestInstaller._();

  _XCTestSession? _activeSession;

  (DriverState, int?, String?, String?, String?) getSessionStatus() {
    final session = _activeSession;
    if (session == null) {
      return (DriverState.idle, null, null, null, null);
    }
    final logTail =
        session.logTail.isEmpty ? null : session.logTail.join('\n');
    return (
      session.state,
      session.port,
      session.udid,
      session.error,
      logTail,
    );
  }

  int? getActivePort() {
    final session = _activeSession;
    if (session == null || session.state != DriverState.ready) return null;
    return session.port;
  }

  DriverStatus getDriverStatus() {
    final (state, port, udid, error, logTail) = getSessionStatus();
    return DriverStatus(
      state: state,
      port: port,
      udid: udid,
      error: error,
      logTail: logTail,
    );
  }

  Directory _resolveSimulatorDriverRoot() {
    return resolveBundledResourceRoot(_driverArtifactRoot);
  }

  void _ensureFirstPartyArtifacts(Directory root) {
    final config = File(
      p.join(root.path, 'simulator', _driverArtifacts.configFileName),
    );
    if (!config.existsSync()) {
      throw Exception(
        'Patrol simulator driver is missing at ${root.path}. '
        'Run scripts/build-simulator-driver.sh and bundle resources into the app.',
      );
    }
  }

  Future<void> ensureSession({
    required String udid,
    required DeviceType deviceType,
    required int port,
    String? xcrunPath,
  }) async {
    final existing = _activeSession;
    if (existing != null &&
        existing.udid == udid &&
        existing.state == DriverState.ready) {
      return;
    }
    if (existing != null &&
        existing.udid == udid &&
        existing.state == DriverState.starting) {
      return _waitForSessionOutcome(udid, port);
    }

    if (existing != null && existing.udid != udid) {
      stopSession(existing.udid);
    }

    final session = _XCTestSession(
      udid: udid,
      port: port,
      deviceType: deviceType,
    );
    _activeSession = session;

    try {
      await _startSessionSync(session, xcrunPath: xcrunPath);
      await _waitForRunner(port);
      session.state = DriverState.ready;
      session.error = null;
    } catch (e) {
      session.state = DriverState.error;
      _appendLog(session, e.toString());
      session.error = _classifyRunnerFailure(session);
      rethrow;
    }
  }

  Future<void> _waitForSessionOutcome(String udid, int port) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start).inMilliseconds <
        _runnerReadyTimeoutMs) {
      final session = _activeSession;
      if (session == null || session.udid != udid) {
        throw Exception('Simulator driver session ended before becoming ready');
      }
      switch (session.state) {
        case DriverState.ready:
          return;
        case DriverState.error:
          throw Exception(
            session.error ?? 'Failed to start the simulator driver',
          );
        case DriverState.starting:
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        default:
          throw Exception('Simulator driver session ended before becoming ready');
      }
    }
    throw Exception('Timed out waiting for the simulator driver');
  }

  Future<void> _startSessionSync(
    _XCTestSession session, {
    String? xcrunPath,
  }) async {
    final artifacts = await _prepareArtifacts(session.udid, session.deviceType);
    session.workingDirectory = artifacts.directory;
    await _killStaleRunner(session, xcrunPath: xcrunPath);
    await _patchXctestRunConfig(session, artifacts.directory);

    final runnerApp = _findRunnerApp(
      artifacts.directory,
      session.deviceType,
    );
    await _installRunner(session, runnerApp, xcrunPath: xcrunPath);
    await _pregrantSimulatorPermissions(session, _driverArtifacts.runnerBundleId,
        xcrunPath: xcrunPath);

    if (session.deviceType == DeviceType.physicalIos) {
      await _launchPhysicalRunner(session, xcrunPath: xcrunPath);
    } else {
      await _launchSimulatorRunner(session);
    }
  }

  void stopSession([String? udid]) {
    final session = _activeSession;
    if (session == null) return;
    if (udid != null && session.udid != udid) return;

    session.state = DriverState.stopped;
    if (session.deviceType != DeviceType.physicalIos) {
      _terminateRunner(session.udid, _driverArtifacts.runnerBundleId);
    }
    session.xcodebuildProcess?.kill(ProcessSignal.sigterm);
    session.iproxyProcess?.kill(ProcessSignal.sigterm);
    final dir = session.workingDirectory;
    _activeSession = null;
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<_PreparedArtifacts> _prepareArtifacts(
    String udid,
    DeviceType deviceType,
  ) async {
    final source = _resolveArtifactSource(deviceType);
    _ensureFirstPartyArtifacts(_resolveSimulatorDriverRoot());
    if (!source.existsSync()) {
      throw Exception(
        'Simulator driver artifacts are missing at ${source.path}',
      );
    }
    final workingDirectory = Directory(
      p.join(Directory.systemTemp.path, 'patrol-xctest-runner', udid),
    );
    if (workingDirectory.existsSync()) {
      workingDirectory.deleteSync(recursive: true);
    }
    workingDirectory.createSync(recursive: true);
    await _copyDirRecursive(source, workingDirectory);
    await _extractRunnerZips(workingDirectory);
    return _PreparedArtifacts(directory: workingDirectory);
  }

  Directory _resolveArtifactSource(DeviceType deviceType) {
    final platformDirectory = deviceType == DeviceType.physicalIos
        ? 'device'
        : 'simulator';
    return Directory(
      p.join(_resolveSimulatorDriverRoot().path, platformDirectory),
    );
  }

  Future<void> _copyDirRecursive(Directory src, Directory dst) async {
    dst.createSync(recursive: true);
    await for (final entity in src.list(recursive: false, followLinks: false)) {
      final target = File(p.join(dst.path, p.basename(entity.path)));
      if (entity is Directory) {
        await _copyDirRecursive(entity, Directory(target.path));
      } else if (entity is File) {
        await entity.copy(target.path);
      }
    }
  }

  Future<void> _extractRunnerZips(Directory directory) async {
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is Directory) {
        await _extractRunnerZips(entity);
      } else if (entity is File && entity.path.endsWith('.zip')) {
        final parent = p.dirname(entity.path);
        final result = await Process.run(
          'ditto',
          ['-x', '-k', entity.path, parent],
          environment: developerToolEnv(),
        );
        if (result.exitCode != 0) {
          throw Exception('${result.stderr}');
        }
      }
    }
  }

  File _findRunnerApp(
    Directory directory,
    DeviceType deviceType,
  ) {
    final buildDir = deviceType == DeviceType.physicalIos
        ? 'Debug-iphoneos'
        : 'Debug-iphonesimulator';
    final appPath = File(
      p.join(
        directory.path,
        buildDir,
        _driverArtifacts.runnerAppFolderName,
      ),
    );
    if (!appPath.existsSync()) {
      throw Exception('Simulator driver app is missing at ${appPath.path}');
    }
    return appPath;
  }

  File _findXctestRunConfig(Directory directory) {
    final configPath =
        File(p.join(directory.path, _driverArtifacts.configFileName));
    if (!configPath.existsSync()) {
      throw Exception(
        'Simulator driver config is missing at ${configPath.path}',
      );
    }
    return configPath;
  }

  Future<void> _patchXctestRunConfig(
    _XCTestSession session,
    Directory directory,
  ) async {
    final configPath = _findXctestRunConfig(directory);
    if (session.deviceType != DeviceType.physicalIos) {
      final developerDir = await Process.run(
        resolveExecutable('xcode-select'),
        const ['-p'],
        environment: developerToolEnv(),
      );
      final platformsDir = p.join(
        '${developerDir.stdout}'.trim(),
        'Platforms',
      );
      var content = configPath.readAsStringSync();
      content = content
          .replaceAll('__TESTROOT__', directory.path)
          .replaceAll('__PLATFORMS__', platformsDir);
      configPath.writeAsStringSync(content);
    }

    for (final envKey in [
      'EnvironmentVariables',
      'TestingEnvironmentVariables',
      'UITargetAppEnvironmentVariables',
    ]) {
      await _setXctestRunEnv(
        configPath,
        _driverArtifacts.uiTestTargetName,
        envKey,
        'PORT',
        '${session.port}',
      );
    }
  }

  Future<void> _setXctestRunEnv(
    File configPath,
    String uiTestTargetName,
    String envKey,
    String key,
    String value,
  ) async {
    final target = ':$uiTestTargetName:$envKey:$key';
    final setResult = await Process.run(
      '/usr/libexec/PlistBuddy',
      ['-c', 'Set $target $value', configPath.path],
    );
    if (setResult.exitCode == 0) return;
    await Process.run(
      '/usr/libexec/PlistBuddy',
      ['-c', 'Add $target string $value', configPath.path],
    );
  }

  Future<void> _killStaleRunner(
    _XCTestSession session, {
    String? xcrunPath,
  }) async {
    if (session.deviceType != DeviceType.physicalIos) {
      _terminateRunner(
        session.udid,
        _driverArtifacts.runnerBundleId,
        xcrunPath: xcrunPath,
      );
    }
    await Process.run(
      'bash',
      [
        '-lc',
        'lsof -ti tcp:${session.port} | xargs kill -9 2>/dev/null || true',
      ],
      environment: developerToolEnv(),
    );
  }

  void _terminateRunner(
    String udid,
    String runnerBundleId, {
    String? xcrunPath,
  }) {
    Process.run(
      resolveExecutable('xcrun', configuredPath: xcrunPath),
      ['simctl', 'terminate', udid, runnerBundleId],
      environment: developerToolEnv(),
    );
  }

  Future<void> _installRunner(
    _XCTestSession session,
    File appPath, {
    String? xcrunPath,
  }) async {
    _appendLog(
      session,
      'simctl install ${p.basename(appPath.path)}',
    );
    final output = await Process.run(
      resolveExecutable('xcrun', configuredPath: xcrunPath),
      ['simctl', 'install', session.udid, appPath.path],
      environment: developerToolEnv(),
    );
    if (output.exitCode != 0) {
      throw Exception('${output.stderr}'.trim());
    }
  }

  Future<void> _pregrantSimulatorPermissions(
    _XCTestSession session,
    String runnerBundleId, {
    String? xcrunPath,
  }) async {
    if (session.deviceType != DeviceType.physicalIos) {
      final bundleIds = await _simulatorUserBundleIds(session, runnerBundleId,
          xcrunPath: xcrunPath);
      const services = [
        'location',
        'location-always',
        'photos',
        'photos-add',
        'camera',
        'microphone',
      ];
      for (final bundleId in bundleIds) {
        for (final service in services) {
          await Process.run(
            resolveExecutable('xcrun', configuredPath: xcrunPath),
            [
              'simctl',
              'privacy',
              session.udid,
              'grant',
              service,
              bundleId,
            ],
            environment: developerToolEnv(),
          );
        }
      }
      if (bundleIds.isNotEmpty) {
        _appendLog(
          session,
          'pregranted simulator permissions for ${bundleIds.length} user apps',
        );
      }
    }
  }

  Future<List<String>> _simulatorUserBundleIds(
    _XCTestSession session,
    String runnerBundleId, {
    String? xcrunPath,
  }) async {
    final output = await Process.run(
      resolveExecutable('xcrun', configuredPath: xcrunPath),
      ['simctl', 'listapps', session.udid],
      environment: developerToolEnv(),
    );
    if (output.exitCode != 0) return const [];
    final text = '${output.stdout}';
    final re = RegExp(r'^\s{4}([A-Za-z0-9_.-]+)\s=\s\{', multiLine: true);
    return re
        .allMatches(text)
        .map((m) => m.group(1)!)
        .where((id) => !id.startsWith('com.apple.') && id != runnerBundleId)
        .toList();
  }

  Future<void> _launchSimulatorRunner(_XCTestSession session) async {
    final configPath = _findXctestRunConfig(session.workingDirectory!);
    _appendLog(
      session,
      'xcodebuild test-without-building ${_driverArtifacts.runnerBundleId} on port ${session.port}',
    );
    final process = await Process.start(
      resolveExecutable('xcodebuild'),
      [
        'test-without-building',
        '-xctestrun',
        configPath.path,
        '-destination',
        'id=${session.udid}',
      ],
      environment: {
        ...developerToolEnv(),
        'PORT': '${session.port}',
      },
    );
    session.xcodebuildProcess = process;
    _captureProcessOutput(session, 'xcodebuild', process);
  }

  Future<void> _launchPhysicalRunner(
    _XCTestSession session, {
    String? xcrunPath,
  }) async {
    final iproxy = resolveExecutable('iproxy');
    final iproxyProcess = await Process.start(
      iproxy,
      ['${session.port}:22087', '-u', session.udid],
      environment: developerToolEnv(),
    );
    session.iproxyProcess = iproxyProcess;
    _captureProcessOutput(session, 'iproxy', iproxyProcess);

    final process = await Process.start(
      resolveExecutable('xcrun', configuredPath: xcrunPath),
      [
        'devicectl',
        'device',
        'process',
        'launch',
        '--terminate-existing',
        '--device',
        session.udid,
        _driverArtifacts.runnerBundleId,
      ],
      environment: developerToolEnv(),
    );
    session.xcodebuildProcess = process;
    _captureProcessOutput(session, 'devicectl', process);
  }

  Future<void> _waitForRunner(int port) async {
    final client = XCTestClient(port);
    final start = DateTime.now();
    String? lastError;
    while (DateTime.now().difference(start).inMilliseconds <
        _runnerReadyTimeoutMs) {
      try {
        await client.status();
        return;
      } catch (e) {
        lastError = e.toString();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    throw Exception(
      lastError ?? 'Timed out waiting for the simulator driver',
    );
  }

  void _captureProcessOutput(
    _XCTestSession session,
    String name,
    Process process,
  ) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _appendLog(session, '$name: $line'));
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _appendLog(session, '$name: $line'));
  }

  void _appendLog(_XCTestSession session, String text) {
    for (final line in text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
      session.logTail.add(line);
    }
    if (session.logTail.length > 80) {
      session.logTail.removeRange(0, session.logTail.length - 80);
    }
  }

  String _classifyRunnerFailure(_XCTestSession session) {
    final log = session.logTail.join('\n').toLowerCase();
    if (session.deviceType == DeviceType.physicalIos &&
        log.contains('iproxy') &&
        (log.contains('not found') || log.contains('enoent'))) {
      return 'Physical iOS preview requires iproxy. Install libimobiledevice with: brew install libimobiledevice';
    }
    if (log.contains('requires a development team') ||
        log.contains('development team')) {
      return 'Simulator driver signing failed. Open Xcode, select a development team for the driver runner, and trust the device.';
    }
    if (log.contains('code signing') ||
        log.contains('codesign') ||
        log.contains('provisioning profile')) {
      return 'Simulator driver code signing failed. Check your Apple development certificate, provisioning profile, and device trust.';
    }
    if (log.contains('timed out waiting')) {
      return 'Timed out waiting for the simulator driver. Quit other sessions using port 22087, then retry.';
    }
    if (log.contains('test crashed with signal kill') ||
        log.contains('signal kill')) {
      return 'The simulator driver was killed before it became ready. Close stale driver apps on the simulator and retry.';
    }
    return session.error ?? 'Failed to start the simulator driver.';
  }
}

class _PreparedArtifacts {
  const _PreparedArtifacts({required this.directory});

  final Directory directory;
}