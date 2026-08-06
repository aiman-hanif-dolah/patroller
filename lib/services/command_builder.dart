import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/patrol_run_outcome.dart';
import '../models/models.dart';

class PatrolCommand {
  const PatrolCommand({
    required this.cmd,
    required this.args,
    required this.display,
  });

  final String cmd;
  final List<String> args;
  final String display;
}

class PatrolCommandInput {
  const PatrolCommandInput({
    required this.config,
    required this.patrolExecutable,
    this.extraPatrolArgs,
  });

  final RunConfig config;
  final String patrolExecutable;
  final List<String>? extraPatrolArgs;
}

String toProjectRelativePath(String projectPath, String filePath) {
  if (!p.isAbsolute(filePath)) {
    return filePath.replaceAll('\\', '/');
  }

  try {
    final project = Directory(projectPath).resolveSymbolicLinksSync();
    final file = File(filePath).resolveSymbolicLinksSync();
    final relative = p.relative(file, from: project);
    return relative.replaceAll('\\', '/');
  } catch (_) {
    return filePath.replaceAll('\\', '/');
  }
}

List<String> _developTargetArgs(RunConfig config) {
  final target = config.targetFile?.trim() ?? '';
  if (target.isEmpty) {
    throw ArgumentError(
      'Patrol develop requires exactly one --target test file.',
    );
  }
  return [
    '--target',
    toProjectRelativePath(config.projectPath, target),
  ];
}

String? _flutterCommandForProject(String projectPath) {
  final linked = File(
    p.join(projectPath, '.fvm', 'flutter_sdk', 'bin', 'flutter'),
  );
  if (linked.existsSync()) return linked.path;

  final versionFile = File(p.join(projectPath, '.fvm', 'version'));
  if (!versionFile.existsSync()) return null;
  final version = versionFile.readAsStringSync().trim();
  if (version.isEmpty) return null;

  final pinned = File(
    p.join(
      projectPath,
      '.fvm',
      'versions',
      version,
      'bin',
      'flutter',
    ),
  );
  return pinned.existsSync() ? pinned.path : null;
}

String? _flavorForEnvironment(TargetEnvironment environment) {
  switch (environment) {
    case TargetEnvironment.dev:
      return 'myastro_dev';
    case TargetEnvironment.stg:
      return 'myastro_stg';
    case TargetEnvironment.prod:
      return null;
  }
}

PatrolCommand buildPatrolCommand(PatrolCommandInput input) {
  final config = input.config;
  final args = <String>[];

  switch (config.runMode) {
    case RunMode.fullSuite:
      args.add('test');
      args.addAll(patrolTestModeDartDefineArgs());
      break;
    case RunMode.develop:
      args.add('develop');
      args.addAll(_developTargetArgs(config));
      break;
    case RunMode.developSuite:
      args.add('develop');
      args.addAll(_developTargetArgs(config));
      break;
    case RunMode.coverage:
      args.addAll([
        'test',
        '--target',
        toProjectRelativePath(
          config.projectPath,
          config.targetFile ?? '',
        ),
        '--coverage',
        ...patrolTestModeDartDefineArgs(),
      ]);
      break;
    case RunMode.test:
      args.addAll([
        'test',
        '--target',
        toProjectRelativePath(
          config.projectPath,
          config.targetFile ?? '',
        ),
        ...patrolTestModeDartDefineArgs(),
      ]);
      break;
  }

  final dataMode = config.userMode == UserMode.live ? 'live' : 'stg';
  final flavor = _flavorForEnvironment(config.env);
  final flutterCommand = _flutterCommandForProject(config.projectPath);
  final home = Platform.environment['HOME']?.trim();

  // Inject target environment, user mode, live profile, and the same runtime
  // guards used by run_patrol.sh. Patrol itself adds PATROL_ENABLED to the
  // native iOS build, which suppresses APNs/MoEngage registration.
  args.addAll([
    '--dart-define=PATROL_ENV=${config.env.name}',
    '--dart-define=PATROL_USER_MODE=${config.userMode.name}',
    '--dart-define=PATROL_DATA_MODE=$dataMode',
    '--dart-define=PATROL_NATIVE_ULM=1',
    if (home != null && home.isNotEmpty)
      '--dart-define=PATROL_LOG_DIR=${p.join(home, 'Library', 'Logs', 'myastro-patrol')}',
    if (dataMode == 'live') '--dart-define=PATROL_SKIP_NATIVE_PERMISSION_IPC=1',
  ]);

  if (flavor != null) {
    args.addAll(['--flavor', flavor]);
  }
  if (flutterCommand != null) {
    args.addAll(['--flutter-command', flutterCommand]);
  }
  if (config.runMode == RunMode.develop ||
      config.runMode == RunMode.developSuite) {
    args.add('--no-uninstall');
  }

  if (config.username != null && config.username!.isNotEmpty) {
    args.add('--dart-define=TEST_USERNAME=${config.username}');
    args.add('--dart-define=PATROL_LIVE_EMAIL=${config.username}');
  }
  if (config.password != null && config.password!.isNotEmpty) {
    args.add('--dart-define=TEST_PASSWORD=${config.password}');
    args.add('--dart-define=PATROL_LIVE_PASSWORD=${config.password}');
  }

  if (input.extraPatrolArgs != null && input.extraPatrolArgs!.isNotEmpty) {
    args.addAll(input.extraPatrolArgs!);
  }

  if (config.extraArgs != null) {
    args.addAll(config.extraArgs!);
  }

  if (config.deviceId != null && config.deviceId!.isNotEmpty) {
    args.addAll(['-d', config.deviceId!]);
  }

  final display = '${input.patrolExecutable} ${args.join(' ')}';
  return PatrolCommand(
      cmd: input.patrolExecutable, args: args, display: display);
}
