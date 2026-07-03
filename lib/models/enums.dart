enum TestStatus {
  idle,
  queued,
  running,
  passed,
  failed,
  cancelled;

  String toJson() => name;

  static TestStatus fromJson(String value) =>
      TestStatus.values.firstWhere((e) => e.name == value, orElse: () => TestStatus.idle);
}

enum RunLifecycle {
  starting,
  running,
  stopping,
  stopped,
  cancelled,
  failed,
  passed,
  interrupted;

  String toJson() => name;

  static RunLifecycle fromJson(String value) =>
      RunLifecycle.values.firstWhere((e) => e.name == value, orElse: () => RunLifecycle.stopped);
}

enum StopOutcome {
  stopped,
  cancelled,
  forceKilled,
  notFound,
  failed;

  String toJson() => name;

  static StopOutcome fromJson(String value) =>
      StopOutcome.values.firstWhere((e) => e.name == value, orElse: () => StopOutcome.failed);
}

enum RunMode {
  test,
  develop,
  developSuite,
  fullSuite;

  String toJson() {
    switch (this) {
      case RunMode.test:
        return 'test';
      case RunMode.develop:
        return 'develop';
      case RunMode.developSuite:
        return 'develop-suite';
      case RunMode.fullSuite:
        return 'full-suite';
    }
  }

  static RunMode fromJson(String value) {
    switch (value) {
      case 'develop':
        return RunMode.develop;
      case 'develop-suite':
        return RunMode.developSuite;
      case 'full-suite':
        return RunMode.fullSuite;
      default:
        return RunMode.test;
    }
  }
}

enum RunRecordStatus {
  queued,
  running,
  passed,
  failed,
  cancelled,
  skipped,
  error;

  String toJson() => name;

  static RunRecordStatus fromJson(String value) =>
      RunRecordStatus.values.firstWhere((e) => e.name == value, orElse: () => RunRecordStatus.error);
}

enum LogStreamType {
  stdout,
  stderr;

  String toJson() => name;

  static LogStreamType fromJson(String value) =>
      LogStreamType.values.firstWhere((e) => e.name == value, orElse: () => LogStreamType.stdout);
}

enum LogSource {
  patrol,
  flutter,
  xcode,
  device,
  system,
  unknown;

  String toJson() {
    switch (this) {
      case LogSource.patrol:
        return 'Patrol';
      case LogSource.flutter:
        return 'Flutter';
      case LogSource.xcode:
        return 'Xcode';
      case LogSource.device:
        return 'Device';
      case LogSource.system:
        return 'System';
      case LogSource.unknown:
        return 'Unknown';
    }
  }

  static LogSource fromJson(String value) {
    switch (value) {
      case 'Patrol':
        return LogSource.patrol;
      case 'Flutter':
        return LogSource.flutter;
      case 'Xcode':
        return LogSource.xcode;
      case 'Device':
        return LogSource.device;
      case 'System':
        return LogSource.system;
      default:
        return LogSource.unknown;
    }
  }
}

enum DeviceType {
  iosSimulator,
  androidEmulator,
  physicalIos,
  physicalAndroid,
  web,
  desktop,
  unknown;

  String toJson() {
    switch (this) {
      case DeviceType.iosSimulator:
        return 'iOS Simulator';
      case DeviceType.androidEmulator:
        return 'Android Emulator';
      case DeviceType.physicalIos:
        return 'physical iOS';
      case DeviceType.physicalAndroid:
        return 'physical Android';
      case DeviceType.web:
        return 'web';
      case DeviceType.desktop:
        return 'desktop';
      case DeviceType.unknown:
        return 'unknown';
    }
  }

  static DeviceType fromJson(String value) {
    switch (value) {
      case 'iOS Simulator':
        return DeviceType.iosSimulator;
      case 'Android Emulator':
        return DeviceType.androidEmulator;
      case 'physical iOS':
        return DeviceType.physicalIos;
      case 'physical Android':
        return DeviceType.physicalAndroid;
      case 'web':
        return DeviceType.web;
      case 'desktop':
        return DeviceType.desktop;
      default:
        return DeviceType.unknown;
    }
  }
}

enum DeviceState {
  booted,
  shutdown,
  unknown;

  String toJson() => name;

  static DeviceState fromJson(String value) =>
      DeviceState.values.firstWhere((e) => e.name == value, orElse: () => DeviceState.unknown);
}

enum HealthStatus {
  passed,
  warning,
  failed;

  String toJson() => name;

  static HealthStatus fromJson(String value) =>
      HealthStatus.values.firstWhere((e) => e.name == value, orElse: () => HealthStatus.failed);
}

enum Confidence {
  low,
  medium,
  high;

  String toJson() => name;

  static Confidence fromJson(String value) =>
      Confidence.values.firstWhere((e) => e.name == value, orElse: () => Confidence.low);
}

enum QueueStatus {
  running,
  completed,
  stopped,
  failed;

  String toJson() => name;

  static QueueStatus fromJson(String value) =>
      QueueStatus.values.firstWhere((e) => e.name == value, orElse: () => QueueStatus.failed);
}

enum TestCaseType {
  patrolTest,
  testWidgets,
  test,
  group;

  String toJson() {
    switch (this) {
      case TestCaseType.patrolTest:
        return 'patrolTest';
      case TestCaseType.testWidgets:
        return 'testWidgets';
      case TestCaseType.test:
        return 'test';
      case TestCaseType.group:
        return 'group';
    }
  }

  static TestCaseType fromJson(String value) {
    switch (value) {
      case 'patrolTest':
        return TestCaseType.patrolTest;
      case 'testWidgets':
        return TestCaseType.testWidgets;
      case 'group':
        return TestCaseType.group;
      default:
        return TestCaseType.test;
    }
  }
}

enum PreferredEditor {
  vscode,
  cursor,
  androidStudio,
  custom;

  String toJson() {
    switch (this) {
      case PreferredEditor.vscode:
        return 'vscode';
      case PreferredEditor.cursor:
        return 'cursor';
      case PreferredEditor.androidStudio:
        return 'android-studio';
      case PreferredEditor.custom:
        return 'custom';
    }
  }

  static PreferredEditor fromJson(String value) {
    switch (value) {
      case 'cursor':
        return PreferredEditor.cursor;
      case 'android-studio':
        return PreferredEditor.androidStudio;
      case 'custom':
        return PreferredEditor.custom;
      default:
        return PreferredEditor.vscode;
    }
  }
}

enum AppTheme {
  system,
  dark,
  light;

  String toJson() => name;

  static AppTheme fromJson(String value) =>
      AppTheme.values.firstWhere((e) => e.name == value, orElse: () => AppTheme.dark);
}

enum QueueRunOutcome {
  passed,
  failed,
  cancelled,
  skipped,
  error;
}