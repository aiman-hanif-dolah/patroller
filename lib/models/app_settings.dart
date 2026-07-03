import 'enums.dart';

class AppSettings {
  const AppSettings({
    required this.patrolPath,
    required this.flutterPath,
    required this.dartPath,
    required this.xcrunPath,
    required this.defaultRunMode,
    required this.testDirectory,
    required this.testSuffix,
    required this.extraPatrolArgs,
    required this.extraFlutterArgs,
    required this.preferredEditor,
    required this.editorCommand,
    required this.theme,
    required this.logRetentionCount,
    required this.autoScrollLogs,
    required this.confirmBeforeRun,
    required this.confirmBeforeClearHistory,
    required this.showRawStderr,
    required this.enableExperimentalParser,
    required this.enableSimulatorEnrichment,
    required this.stopQueueOnFirstFailure,
    this.lastProjectPath,
    required this.xctestRunnerPort,
    required this.previewPollIntervalMs,
    required this.previewIdlePollIntervalMs,
    required this.previewActivePollIntervalMs,
    required this.previewInteractionPollIntervalMs,
    required this.hierarchyPollIntervalMs,
    required this.autoStartDriver,
    required this.rightPanelWidth,
    required this.logsPanelWidth,
    required this.previewPanelWidth,
    required this.previewCollapsed,
  });

  final String patrolPath;
  final String flutterPath;
  final String dartPath;
  final String xcrunPath;
  final RunMode defaultRunMode;
  final String testDirectory;
  final String testSuffix;
  final List<String> extraPatrolArgs;
  final List<String> extraFlutterArgs;
  final PreferredEditor preferredEditor;
  final String editorCommand;
  final AppTheme theme;
  final int logRetentionCount;
  final bool autoScrollLogs;
  final bool confirmBeforeRun;
  final bool confirmBeforeClearHistory;
  final bool showRawStderr;
  final bool enableExperimentalParser;
  final bool enableSimulatorEnrichment;
  final bool stopQueueOnFirstFailure;
  final String? lastProjectPath;
  final int xctestRunnerPort;
  final int previewPollIntervalMs;
  final int previewIdlePollIntervalMs;
  final int previewActivePollIntervalMs;
  final int previewInteractionPollIntervalMs;
  final int hierarchyPollIntervalMs;
  final bool autoStartDriver;
  final int rightPanelWidth;
  final int logsPanelWidth;
  final int previewPanelWidth;
  final bool previewCollapsed;

  static AppSettings defaults() => const AppSettings(
        patrolPath: 'patrol',
        flutterPath: 'flutter',
        dartPath: 'dart',
        xcrunPath: 'xcrun',
        defaultRunMode: RunMode.test,
        testDirectory: 'patrol_test',
        testSuffix: '_test.dart',
        extraPatrolArgs: [],
        extraFlutterArgs: [],
        preferredEditor: PreferredEditor.vscode,
        editorCommand: 'code -g {file}:{line}',
        theme: AppTheme.dark,
        logRetentionCount: 100,
        autoScrollLogs: true,
        confirmBeforeRun: true,
        confirmBeforeClearHistory: true,
        showRawStderr: true,
        enableExperimentalParser: false,
        enableSimulatorEnrichment: true,
        stopQueueOnFirstFailure: false,
        lastProjectPath: null,
        xctestRunnerPort: 22087,
        previewPollIntervalMs: 33,
        previewIdlePollIntervalMs: 500,
        previewActivePollIntervalMs: 100,
        previewInteractionPollIntervalMs: 50,
        hierarchyPollIntervalMs: 1500,
        autoStartDriver: true,
        rightPanelWidth: 380,
        logsPanelWidth: 480,
        previewPanelWidth: 390,
        previewCollapsed: false,
      );

  AppSettings copyWith({
    String? patrolPath,
    String? flutterPath,
    String? dartPath,
    String? xcrunPath,
    RunMode? defaultRunMode,
    String? testDirectory,
    String? testSuffix,
    List<String>? extraPatrolArgs,
    List<String>? extraFlutterArgs,
    PreferredEditor? preferredEditor,
    String? editorCommand,
    AppTheme? theme,
    int? logRetentionCount,
    bool? autoScrollLogs,
    bool? confirmBeforeRun,
    bool? confirmBeforeClearHistory,
    bool? showRawStderr,
    bool? enableExperimentalParser,
    bool? enableSimulatorEnrichment,
    bool? stopQueueOnFirstFailure,
    String? lastProjectPath,
    int? xctestRunnerPort,
    int? previewPollIntervalMs,
    int? previewIdlePollIntervalMs,
    int? previewActivePollIntervalMs,
    int? previewInteractionPollIntervalMs,
    int? hierarchyPollIntervalMs,
    bool? autoStartDriver,
    int? rightPanelWidth,
    int? logsPanelWidth,
    int? previewPanelWidth,
    bool? previewCollapsed,
  }) =>
      AppSettings(
        patrolPath: patrolPath ?? this.patrolPath,
        flutterPath: flutterPath ?? this.flutterPath,
        dartPath: dartPath ?? this.dartPath,
        xcrunPath: xcrunPath ?? this.xcrunPath,
        defaultRunMode: defaultRunMode ?? this.defaultRunMode,
        testDirectory: testDirectory ?? this.testDirectory,
        testSuffix: testSuffix ?? this.testSuffix,
        extraPatrolArgs: extraPatrolArgs ?? this.extraPatrolArgs,
        extraFlutterArgs: extraFlutterArgs ?? this.extraFlutterArgs,
        preferredEditor: preferredEditor ?? this.preferredEditor,
        editorCommand: editorCommand ?? this.editorCommand,
        theme: theme ?? this.theme,
        logRetentionCount: logRetentionCount ?? this.logRetentionCount,
        autoScrollLogs: autoScrollLogs ?? this.autoScrollLogs,
        confirmBeforeRun: confirmBeforeRun ?? this.confirmBeforeRun,
        confirmBeforeClearHistory:
            confirmBeforeClearHistory ?? this.confirmBeforeClearHistory,
        showRawStderr: showRawStderr ?? this.showRawStderr,
        enableExperimentalParser:
            enableExperimentalParser ?? this.enableExperimentalParser,
        enableSimulatorEnrichment:
            enableSimulatorEnrichment ?? this.enableSimulatorEnrichment,
        stopQueueOnFirstFailure:
            stopQueueOnFirstFailure ?? this.stopQueueOnFirstFailure,
        lastProjectPath: lastProjectPath ?? this.lastProjectPath,
        xctestRunnerPort: xctestRunnerPort ?? this.xctestRunnerPort,
        previewPollIntervalMs: previewPollIntervalMs ?? this.previewPollIntervalMs,
        previewIdlePollIntervalMs:
            previewIdlePollIntervalMs ?? this.previewIdlePollIntervalMs,
        previewActivePollIntervalMs:
            previewActivePollIntervalMs ?? this.previewActivePollIntervalMs,
        previewInteractionPollIntervalMs: previewInteractionPollIntervalMs ??
            this.previewInteractionPollIntervalMs,
        hierarchyPollIntervalMs: hierarchyPollIntervalMs ?? this.hierarchyPollIntervalMs,
        autoStartDriver: autoStartDriver ?? this.autoStartDriver,
        rightPanelWidth: rightPanelWidth ?? this.rightPanelWidth,
        logsPanelWidth: logsPanelWidth ?? this.logsPanelWidth,
        previewPanelWidth: previewPanelWidth ?? this.previewPanelWidth,
        previewCollapsed: previewCollapsed ?? this.previewCollapsed,
      );

  Map<String, dynamic> toJson() => {
        'patrolPath': patrolPath,
        'flutterPath': flutterPath,
        'dartPath': dartPath,
        'xcrunPath': xcrunPath,
        'defaultRunMode': defaultRunMode.toJson(),
        'testDirectory': testDirectory,
        'testSuffix': testSuffix,
        'extraPatrolArgs': extraPatrolArgs,
        'extraFlutterArgs': extraFlutterArgs,
        'preferredEditor': preferredEditor.toJson(),
        'editorCommand': editorCommand,
        'theme': theme.toJson(),
        'logRetentionCount': logRetentionCount,
        'autoScrollLogs': autoScrollLogs,
        'confirmBeforeRun': confirmBeforeRun,
        'confirmBeforeClearHistory': confirmBeforeClearHistory,
        'showRawStderr': showRawStderr,
        'enableExperimentalParser': enableExperimentalParser,
        'enableSimulatorEnrichment': enableSimulatorEnrichment,
        'stopQueueOnFirstFailure': stopQueueOnFirstFailure,
        'lastProjectPath': lastProjectPath,
        'xctestRunnerPort': xctestRunnerPort,
        'previewPollIntervalMs': previewPollIntervalMs,
        'previewIdlePollIntervalMs': previewIdlePollIntervalMs,
        'previewActivePollIntervalMs': previewActivePollIntervalMs,
        'previewInteractionPollIntervalMs': previewInteractionPollIntervalMs,
        'hierarchyPollIntervalMs': hierarchyPollIntervalMs,
        'autoStartDriver': autoStartDriver,
        'rightPanelWidth': rightPanelWidth,
        'logsPanelWidth': logsPanelWidth,
        'previewPanelWidth': previewPanelWidth,
        'previewCollapsed': previewCollapsed,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AppSettings.defaults();
    return AppSettings(
      patrolPath: json['patrolPath'] as String? ?? defaults.patrolPath,
      flutterPath: json['flutterPath'] as String? ?? defaults.flutterPath,
      dartPath: json['dartPath'] as String? ?? defaults.dartPath,
      xcrunPath: json['xcrunPath'] as String? ?? defaults.xcrunPath,
      defaultRunMode: RunMode.fromJson(json['defaultRunMode'] as String? ?? 'test'),
      testDirectory: json['testDirectory'] as String? ?? defaults.testDirectory,
      testSuffix: json['testSuffix'] as String? ?? defaults.testSuffix,
      extraPatrolArgs:
          (json['extraPatrolArgs'] as List<dynamic>? ?? []).cast<String>(),
      extraFlutterArgs:
          (json['extraFlutterArgs'] as List<dynamic>? ?? []).cast<String>(),
      preferredEditor:
          PreferredEditor.fromJson(json['preferredEditor'] as String? ?? 'vscode'),
      editorCommand: json['editorCommand'] as String? ?? defaults.editorCommand,
      theme: AppTheme.fromJson(json['theme'] as String? ?? 'dark'),
      logRetentionCount: json['logRetentionCount'] as int? ?? defaults.logRetentionCount,
      autoScrollLogs: json['autoScrollLogs'] as bool? ?? defaults.autoScrollLogs,
      confirmBeforeRun: json['confirmBeforeRun'] as bool? ?? defaults.confirmBeforeRun,
      confirmBeforeClearHistory: json['confirmBeforeClearHistory'] as bool? ??
          defaults.confirmBeforeClearHistory,
      showRawStderr: json['showRawStderr'] as bool? ?? defaults.showRawStderr,
      enableExperimentalParser: json['enableExperimentalParser'] as bool? ??
          defaults.enableExperimentalParser,
      enableSimulatorEnrichment: json['enableSimulatorEnrichment'] as bool? ??
          defaults.enableSimulatorEnrichment,
      stopQueueOnFirstFailure: json['stopQueueOnFirstFailure'] as bool? ??
          defaults.stopQueueOnFirstFailure,
      lastProjectPath: json['lastProjectPath'] as String?,
      xctestRunnerPort: json['xctestRunnerPort'] as int? ?? defaults.xctestRunnerPort,
      previewPollIntervalMs:
          json['previewPollIntervalMs'] as int? ?? defaults.previewPollIntervalMs,
      previewIdlePollIntervalMs: json['previewIdlePollIntervalMs'] as int? ??
          defaults.previewIdlePollIntervalMs,
      previewActivePollIntervalMs: json['previewActivePollIntervalMs'] as int? ??
          defaults.previewActivePollIntervalMs,
      previewInteractionPollIntervalMs:
          json['previewInteractionPollIntervalMs'] as int? ??
              defaults.previewInteractionPollIntervalMs,
      hierarchyPollIntervalMs:
          json['hierarchyPollIntervalMs'] as int? ?? defaults.hierarchyPollIntervalMs,
      autoStartDriver: json['autoStartDriver'] as bool? ?? defaults.autoStartDriver,
      rightPanelWidth: json['rightPanelWidth'] as int? ?? defaults.rightPanelWidth,
      logsPanelWidth: json['logsPanelWidth'] as int? ?? defaults.logsPanelWidth,
      previewPanelWidth:
          json['previewPanelWidth'] as int? ?? defaults.previewPanelWidth,
      previewCollapsed:
          json['previewCollapsed'] as bool? ?? defaults.previewCollapsed,
    );
  }
}