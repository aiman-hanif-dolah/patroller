import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'app_paths.dart';
import 'cli_env.dart';

class SettingsStore {
  SettingsStore._() {
    _bootstrap();
  }

  static final SettingsStore instance = SettingsStore._();

  late AppSettings _settings;
  late String _settingsPath;
  bool _loaded = false;

  void _bootstrap() {
    final dir = patrolStudioUserDataDirSync();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _settingsPath = p.join(dir.path, 'settings.json');
    _settings = _loadFromDisk(_settingsPath);
    _loaded = true;
  }

  AppSettings _sanitizeExecutableSettings(AppSettings settings) {
    final defaults = AppSettings.defaults();
    return settings.copyWith(
      patrolPath: sanitizeConfiguredExecutablePath(
        settings.patrolPath,
        defaults.patrolPath,
      ),
      flutterPath: sanitizeConfiguredExecutablePath(
        settings.flutterPath,
        defaults.flutterPath,
      ),
      dartPath: sanitizeConfiguredExecutablePath(
        settings.dartPath,
        defaults.dartPath,
      ),
      xcrunPath: sanitizeConfiguredExecutablePath(
        settings.xcrunPath,
        defaults.xcrunPath,
      ),
    );
  }

  AppSettings _loadFromDisk(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return AppSettings.defaults();
      }
      final parsed = jsonDecode(file.readAsStringSync());
      if (parsed is! Map<String, dynamic>) {
        return AppSettings.defaults();
      }

      final defaults = AppSettings.defaults();
      final merged = <String, dynamic>{
        ...defaults.toJson(),
        ...parsed,
      };
      var loaded = AppSettings.fromJson(merged);
      final sanitized = _sanitizeExecutableSettings(loaded);
      final needsSave = sanitized.patrolPath != loaded.patrolPath ||
          sanitized.flutterPath != loaded.flutterPath ||
          sanitized.dartPath != loaded.dartPath ||
          sanitized.xcrunPath != loaded.xcrunPath;
      loaded = sanitized;
      if (needsSave) {
        _saveToDisk(path, loaded);
      }
      return loaded;
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  void _saveToDisk(String path, AppSettings settings) {
    try {
      final json = const JsonEncoder.withIndent('  ').convert(settings.toJson());
      File(path).writeAsStringSync(json);
    } catch (_) {}
  }

  AppSettings get() => _settings;

  Future<AppSettings> getAsync() async {
    if (!_loaded) _bootstrap();
    return _settings;
  }

  AppSettings getDefaults() => AppSettings.defaults();

  AppSettings updatePartial(Map<String, dynamic> partialMap) {
    final defaults = AppSettings.defaults();
    final current = _settings.toJson();
    current.addAll(partialMap);

    if (partialMap.containsKey('patrolPath')) {
      current['patrolPath'] = sanitizeConfiguredExecutablePath(
        partialMap['patrolPath'] as String?,
        defaults.patrolPath,
      );
    }
    if (partialMap.containsKey('flutterPath')) {
      current['flutterPath'] = sanitizeConfiguredExecutablePath(
        partialMap['flutterPath'] as String?,
        defaults.flutterPath,
      );
    }
    if (partialMap.containsKey('dartPath')) {
      current['dartPath'] = sanitizeConfiguredExecutablePath(
        partialMap['dartPath'] as String?,
        defaults.dartPath,
      );
    }
    if (partialMap.containsKey('xcrunPath')) {
      current['xcrunPath'] = sanitizeConfiguredExecutablePath(
        partialMap['xcrunPath'] as String?,
        defaults.xcrunPath,
      );
    }

    clearAugmentedPathCache();
    _settings = AppSettings.fromJson(current);
    _saveToDisk(_settingsPath, _settings);
    return _settings;
  }

  AppSettings update(AppSettings partial) {
    final defaults = AppSettings.defaults();
    final merged = _settings.copyWith(
      patrolPath: partial.patrolPath != _settings.patrolPath
          ? sanitizeConfiguredExecutablePath(partial.patrolPath, defaults.patrolPath)
          : _settings.patrolPath,
      flutterPath: partial.flutterPath != _settings.flutterPath
          ? sanitizeConfiguredExecutablePath(partial.flutterPath, defaults.flutterPath)
          : _settings.flutterPath,
      dartPath: partial.dartPath != _settings.dartPath
          ? sanitizeConfiguredExecutablePath(partial.dartPath, defaults.dartPath)
          : _settings.dartPath,
      xcrunPath: partial.xcrunPath != _settings.xcrunPath
          ? sanitizeConfiguredExecutablePath(partial.xcrunPath, defaults.xcrunPath)
          : _settings.xcrunPath,
      defaultRunMode:
          partial.defaultRunMode != _settings.defaultRunMode ? partial.defaultRunMode : _settings.defaultRunMode,
      testDirectory:
          partial.testDirectory != _settings.testDirectory ? partial.testDirectory : _settings.testDirectory,
      testSuffix: partial.testSuffix != _settings.testSuffix ? partial.testSuffix : _settings.testSuffix,
      extraPatrolArgs: !_listEquals(partial.extraPatrolArgs, _settings.extraPatrolArgs)
          ? partial.extraPatrolArgs
          : _settings.extraPatrolArgs,
      extraFlutterArgs: !_listEquals(partial.extraFlutterArgs, _settings.extraFlutterArgs)
          ? partial.extraFlutterArgs
          : _settings.extraFlutterArgs,
      preferredEditor: partial.preferredEditor != _settings.preferredEditor
          ? partial.preferredEditor
          : _settings.preferredEditor,
      editorCommand: partial.editorCommand != _settings.editorCommand
          ? partial.editorCommand
          : _settings.editorCommand,
      theme: partial.theme != _settings.theme ? partial.theme : _settings.theme,
      logRetentionCount: partial.logRetentionCount != _settings.logRetentionCount
          ? partial.logRetentionCount
          : _settings.logRetentionCount,
      autoScrollLogs: partial.autoScrollLogs != _settings.autoScrollLogs
          ? partial.autoScrollLogs
          : _settings.autoScrollLogs,
      confirmBeforeRun: partial.confirmBeforeRun != _settings.confirmBeforeRun
          ? partial.confirmBeforeRun
          : _settings.confirmBeforeRun,
      confirmBeforeClearHistory:
          partial.confirmBeforeClearHistory != _settings.confirmBeforeClearHistory
              ? partial.confirmBeforeClearHistory
              : _settings.confirmBeforeClearHistory,
      showRawStderr: partial.showRawStderr != _settings.showRawStderr
          ? partial.showRawStderr
          : _settings.showRawStderr,
      enableExperimentalParser:
          partial.enableExperimentalParser != _settings.enableExperimentalParser
              ? partial.enableExperimentalParser
              : _settings.enableExperimentalParser,
      enableSimulatorEnrichment:
          partial.enableSimulatorEnrichment != _settings.enableSimulatorEnrichment
              ? partial.enableSimulatorEnrichment
              : _settings.enableSimulatorEnrichment,
      stopQueueOnFirstFailure:
          partial.stopQueueOnFirstFailure != _settings.stopQueueOnFirstFailure
              ? partial.stopQueueOnFirstFailure
              : _settings.stopQueueOnFirstFailure,
      lastProjectPath: partial.lastProjectPath ?? _settings.lastProjectPath,
      xctestRunnerPort: partial.xctestRunnerPort != _settings.xctestRunnerPort
          ? partial.xctestRunnerPort
          : _settings.xctestRunnerPort,
      previewPollIntervalMs: partial.previewPollIntervalMs != _settings.previewPollIntervalMs
          ? partial.previewPollIntervalMs
          : _settings.previewPollIntervalMs,
      previewIdlePollIntervalMs:
          partial.previewIdlePollIntervalMs != _settings.previewIdlePollIntervalMs
              ? partial.previewIdlePollIntervalMs
              : _settings.previewIdlePollIntervalMs,
      previewActivePollIntervalMs:
          partial.previewActivePollIntervalMs != _settings.previewActivePollIntervalMs
              ? partial.previewActivePollIntervalMs
              : _settings.previewActivePollIntervalMs,
      previewInteractionPollIntervalMs:
          partial.previewInteractionPollIntervalMs !=
                  _settings.previewInteractionPollIntervalMs
              ? partial.previewInteractionPollIntervalMs
              : _settings.previewInteractionPollIntervalMs,
      hierarchyPollIntervalMs:
          partial.hierarchyPollIntervalMs != _settings.hierarchyPollIntervalMs
              ? partial.hierarchyPollIntervalMs
              : _settings.hierarchyPollIntervalMs,
      autoStartDriver: partial.autoStartDriver != _settings.autoStartDriver
          ? partial.autoStartDriver
          : _settings.autoStartDriver,
      rightPanelWidth: partial.rightPanelWidth != _settings.rightPanelWidth
          ? partial.rightPanelWidth
          : _settings.rightPanelWidth,
      logsPanelWidth: partial.logsPanelWidth != _settings.logsPanelWidth
          ? partial.logsPanelWidth
          : _settings.logsPanelWidth,
    );

    clearAugmentedPathCache();
    _settings = merged;
    _saveToDisk(_settingsPath, _settings);
    return _settings;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}