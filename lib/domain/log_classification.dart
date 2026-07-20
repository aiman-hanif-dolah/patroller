import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';
import '../models/models.dart';
import 'log_sanitizer.dart';

enum LogCategory { error, warning, patrol, flutter, system, info }

class LogCategoryStyle {
  const LogCategoryStyle({
    required this.text,
    required this.tag,
    required this.label,
    this.background,
  });

  final Color text;
  final Color tag;
  final String label;
  final Color? background;
}

const logCategoryStyles = <LogCategory, LogCategoryStyle>{
  LogCategory.error: LogCategoryStyle(
    text: PatrolColors.red400,
    tag: PatrolColors.psFailed,
    background: Color(0x14EF4444),
    label: 'Error',
  ),
  LogCategory.warning: LogCategoryStyle(
    text: PatrolColors.orange400,
    tag: Color(0xFFF97316),
    label: 'Warn',
  ),
  LogCategory.patrol: LogCategoryStyle(
    text: PatrolColors.green400,
    tag: PatrolColors.psPassed,
    label: 'Patrol',
  ),
  LogCategory.info: LogCategoryStyle(
    text: Color(0xFFFACC15),
    tag: Color(0xFFEAB308),
    label: 'Info',
  ),
  LogCategory.flutter: LogCategoryStyle(
    text: Color(0xFF60A5FA),
    tag: Color(0xFF3B82F6),
    label: 'Flutter',
  ),
  LogCategory.system: LogCategoryStyle(
    text: Color(0xFFF472B6),
    tag: Color(0xFFEC4899),
    label: 'SDK',
  ),
};

final _errorPatterns = [
  RegExp(r'\berror\b', caseSensitive: false),
  RegExp(r'\bfailed?\b', caseSensitive: false),
  RegExp(r'\bexception\b', caseSensitive: false),
  RegExp(r'\bfatal\b', caseSensitive: false),
  RegExp(r'\bassertion\b', caseSensitive: false),
  RegExp(r'\btraceback\b', caseSensitive: false),
  RegExp(r'\bstack trace\b', caseSensitive: false),
  RegExp(r'\buncaught\b', caseSensitive: false),
  RegExp(r'\bcrash(?:es|ed)?\b', caseSensitive: false),
];

final _warningPatterns = [
  RegExp(r'\bwarning\b', caseSensitive: false),
  RegExp(r'\bwarn\b', caseSensitive: false),
  RegExp(r'overridden!', caseSensitive: false),
  RegExp(r'!\s+[a-z_][\w.-]*', caseSensitive: false),
  RegExp(r'resolving dependencies', caseSensitive: false),
  RegExp(r'changed \d+ dependenc', caseSensitive: false),
  RegExp(r'packages? have newer versions', caseSensitive: false),
  RegExp(r'outdated', caseSensitive: false),
  RegExp(r'cocoapods', caseSensitive: false),
  RegExp(r'swift package manager', caseSensitive: false),
  RegExp(r'\bspm\b', caseSensitive: false),
  RegExp(r'pod install', caseSensitive: false),
  RegExp(r'package\.resolved', caseSensitive: false),
];

final _dependencyWarningPatterns = [
  RegExp(r'resolving dependencies', caseSensitive: false),
  RegExp(r'got dependencies', caseSensitive: false),
  RegExp(r'changed \d+ dependenc', caseSensitive: false),
  RegExp(r'packages? have newer versions', caseSensitive: false),
  RegExp(r'cocoapods', caseSensitive: false),
  RegExp(r'swift package manager', caseSensitive: false),
  RegExp(r'pod install', caseSensitive: false),
];

final _patrolFailurePatterns = [
  RegExp(r'patrol.*failed', caseSensitive: false),
  RegExp(r'test failed', caseSensitive: false),
  RegExp(r'assertion failed', caseSensitive: false),
  RegExp(r'══╡.*exception', caseSensitive: false),
  RegExp(r'expected:.*actual:', caseSensitive: false),
];

final _patrolPatterns = [
  RegExp(r'\bpatrol\b', caseSensitive: false),
  RegExp(r'integrationtest', caseSensitive: false),
];

final _flutterPatterns = [
  RegExp(r'\bflutter\b', caseSensitive: false),
  RegExp(r'\bdart\b', caseSensitive: false),
  RegExp(r'pub get', caseSensitive: false),
  RegExp(r'resolving dependencies', caseSensitive: false),
  RegExp(r'downloading packages', caseSensitive: false),
  RegExp(r'got dependencies', caseSensitive: false),
  RegExp(r'changed \d+ dependenc', caseSensitive: false),
  RegExp(r'dart pub', caseSensitive: false),
  RegExp(r'running "flutter', caseSensitive: false),
  RegExp(r'flutter tool', caseSensitive: false),
  RegExp(r'syncing files to device', caseSensitive: false),
  RegExp(r'launching lib/', caseSensitive: false),
];

final _systemPatterns = [
  RegExp(r'moeflutter', caseSensitive: false),
  RegExp(r'core_moe\w*', caseSensitive: false),
  RegExp(r'\[\s*v\s*\]:', caseSensitive: false),
  RegExp(r'pushservice', caseSensitive: false),
  RegExp(r'push token', caseSensitive: false),
  RegExp(r'\bapns\b', caseSensitive: false),
  RegExp(r'_handler\(\)', caseSensitive: false),
  RegExp(r'fromstring\(\)', caseSensitive: false),
];

bool _matchesAny(String text, List<RegExp> patterns) {
  return patterns.any((pattern) => pattern.hasMatch(text));
}

bool isDependencyToolWarning(String text) {
  return _matchesAny(text, _dependencyWarningPatterns);
}

bool isPatrolFailureOutput(String text) {
  return _matchesAny(text, _patrolFailurePatterns) ||
      _matchesAny(text, _errorPatterns);
}

LogCategory classifyLog(LogEvent log) {
  final text = sanitizeLogText(log.text);
  if (_matchesAny(text, _dependencyWarningPatterns)) return LogCategory.warning;
  if (_matchesAny(text, _warningPatterns)) return LogCategory.warning;
  if (_matchesAny(text, _patrolFailurePatterns)) return LogCategory.error;
  if (_matchesAny(text, _errorPatterns)) return LogCategory.error;
  if (log.streamType == LogStreamType.stderr &&
      !_matchesAny(text, _flutterPatterns)) {
    return LogCategory.error;
  }

  if (log.source == LogSource.patrol || _matchesAny(text, _patrolPatterns)) {
    return LogCategory.patrol;
  }
  if (log.source == LogSource.flutter || _matchesAny(text, _flutterPatterns)) {
    return LogCategory.flutter;
  }
  if (_matchesAny(text, _systemPatterns)) return LogCategory.system;

  return LogCategory.info;
}

enum LogFilterKey {
  error,
  warning,
  patrol,
  flutter,
  xcode,
  device,
  system,
  unknown,
  info,
}

enum LogFilterMode { include, exclude }

enum LogStreamFilter { all, stdout, stderr }

class LogFilters {
  const LogFilters({
    required this.mode,
    required this.stream,
    required this.sources,
  });

  final LogFilterMode mode;
  final LogStreamFilter stream;
  final Map<LogFilterKey, bool> sources;

  static const defaults = LogFilters(
    mode: LogFilterMode.include,
    stream: LogStreamFilter.all,
    sources: {
      LogFilterKey.error: true,
      LogFilterKey.warning: true,
      LogFilterKey.patrol: true,
      LogFilterKey.flutter: true,
      LogFilterKey.xcode: true,
      LogFilterKey.device: true,
      LogFilterKey.system: true,
      LogFilterKey.unknown: true,
      LogFilterKey.info: true,
    },
  );

  LogFilters copyWith({
    LogFilterMode? mode,
    LogStreamFilter? stream,
    Map<LogFilterKey, bool>? sources,
  }) {
    return LogFilters(
      mode: mode ?? this.mode,
      stream: stream ?? this.stream,
      sources: sources ?? this.sources,
    );
  }
}

const logFilterLabels = {
  LogFilterKey.error: 'Error',
  LogFilterKey.warning: 'Warn',
  LogFilterKey.patrol: 'Patrol',
  LogFilterKey.flutter: 'Flutter',
  LogFilterKey.xcode: 'Xcode',
  LogFilterKey.device: 'Device',
  LogFilterKey.system: 'System',
  LogFilterKey.unknown: 'Unknown',
  LogFilterKey.info: 'Info',
};

LogFilterKey getLogFilterKey(LogEvent log) {
  final category = classifyLog(log);
  if (category == LogCategory.error) return LogFilterKey.error;
  if (category == LogCategory.warning) return LogFilterKey.warning;
  if (log.source == LogSource.xcode) return LogFilterKey.xcode;
  if (log.source == LogSource.device) return LogFilterKey.device;
  if (category == LogCategory.patrol) return LogFilterKey.patrol;
  if (category == LogCategory.flutter) return LogFilterKey.flutter;
  if (category == LogCategory.system) return LogFilterKey.system;
  if (log.source == LogSource.unknown) return LogFilterKey.unknown;
  return LogFilterKey.info;
}

bool isLogFilterActive(LogFilters filters) {
  if (filters.stream != LogStreamFilter.all) return true;
  final allEnabled = LogFilterKey.values.every((key) => filters.sources[key] ?? true);
  final noneEnabled = LogFilterKey.values.every((key) => !(filters.sources[key] ?? true));
  if (filters.mode == LogFilterMode.include) return !allEnabled;
  return !noneEnabled;
}

bool matchesLogFilters(LogEvent log, LogFilters filters, String search) {
  if (filters.stream != LogStreamFilter.all &&
      log.streamType.name != filters.stream.name) {
    return false;
  }

  final key = getLogFilterKey(log);
  final anySourceSelected =
      LogFilterKey.values.any((k) => filters.sources[k] ?? true);

  if (filters.mode == LogFilterMode.include) {
    if (anySourceSelected && !(filters.sources[key] ?? true)) return false;
  } else if (filters.sources[key] ?? false) {
    return false;
  }

  if (search.trim().isEmpty) return true;
  return sanitizeLogText(log.text).toLowerCase().contains(search.toLowerCase());
}

String formatLogLineCount(int total, int filtered, bool filtersActive) {
  if (!filtersActive) return '$total lines';
  return '$filtered / $total lines';
}

bool _isCollapsibleWarningBlock(LogEvent log) {
  final text = sanitizeLogText(log.text);
  final category = classifyLog(log);
  return isDependencyToolWarning(text) ||
      category == LogCategory.warning ||
      (category == LogCategory.flutter && _matchesAny(text, _flutterPatterns));
}

const dependencyNoticeBlockPrefix = '[[DEPENDENCY_NOTICES]]';

bool isDependencyNoticeBlock(LogEvent log) =>
    log.text.startsWith(dependencyNoticeBlockPrefix);

List<LogEvent> summarizeDependencyNotices(List<LogEvent> logs) {
  if (logs.isEmpty) return logs;

  final visible = <LogEvent>[];
  final hiddenBodies = <String>[];
  var hiddenCount = 0;

  for (final log in logs) {
    if (isDependencyToolWarning(sanitizeLogText(log.text))) {
      hiddenCount++;
      hiddenBodies.add(log.rawText ?? log.text);
      continue;
    }
    visible.add(log);
  }

  if (hiddenCount == 0) return visible;

  final summary = LogEvent(
    runId: visible.isNotEmpty ? visible.first.runId : logs.first.runId,
    streamType: LogStreamType.stdout,
    timestamp: visible.isNotEmpty ? visible.first.timestamp : logs.last.timestamp,
    text:
        '$dependencyNoticeBlockPrefix$hiddenCount dependency notice${hiddenCount == 1 ? '' : 's'}',
    lineNumber: visible.isNotEmpty ? visible.first.lineNumber : logs.first.lineNumber,
    source: LogSource.system,
    rawText: hiddenBodies.join('\n'),
  );

  return [summary, ...visible];
}

@Deprecated('Use summarizeDependencyNotices')
List<LogEvent> groupDependencyNotices(List<LogEvent> logs) =>
    summarizeDependencyNotices(logs);

List<LogEvent> collapseRepeatedLogBlocks(List<LogEvent> logs) {
  if (logs.length < 3) return logs;
  final result = <LogEvent>[];
  var index = 0;
  while (index < logs.length) {
    final current = logs[index];
    if (!_isCollapsibleWarningBlock(current)) {
      result.add(current);
      index++;
      continue;
    }

    var end = index + 1;
    while (end < logs.length && _isCollapsibleWarningBlock(logs[end])) {
      end++;
    }

    final blockLength = end - index;
    if (blockLength >= 3) {
      result.add(current);
      result.add(
        LogEvent(
          runId: current.runId,
          streamType: current.streamType,
          timestamp: current.timestamp,
          text: '… ${blockLength - 2} similar messages collapsed …',
          lineNumber: current.lineNumber,
          source: LogSource.system,
        ),
      );
      result.add(logs[end - 1]);
      index = end;
      continue;
    }

    for (var i = index; i < end; i++) {
      result.add(logs[i]);
    }
    index = end;
  }
  return result;
}

String formatLogTimestamp(String timestamp) {
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null) return timestamp;
  final local = parsed.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  final s = local.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}