import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'app_paths.dart';

class CrashReport {
  CrashReport({
    required this.timestamp,
    required this.error,
    required this.stackTrace,
    this.library,
    this.context,
  });

  final String timestamp;
  final String error;
  final String stackTrace;
  final String? library;
  final String? context;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'error': error,
        'stackTrace': stackTrace,
        'library': library,
        'context': context,
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
      };

  factory CrashReport.fromJson(Map<String, dynamic> json) => CrashReport(
        timestamp: json['timestamp'] as String? ?? '',
        error: json['error'] as String? ?? 'Unknown error',
        stackTrace: json['stackTrace'] as String? ?? '',
        library: json['library'] as String?,
        context: json['context'] as String?,
      );

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.writeln('=== PATROLLER CRASH REPORT ===');
    buffer.writeln('Timestamp: $timestamp');
    buffer.writeln('OS: ${Platform.operatingSystem} (${Platform.operatingSystemVersion})');
    if (library != null && library!.isNotEmpty) {
      buffer.writeln('Library: $library');
    }
    if (context != null && context!.isNotEmpty) {
      buffer.writeln('Context: $context');
    }
    buffer.writeln('\n--- Error Details ---');
    buffer.writeln(error);
    buffer.writeln('\n--- Stack Trace ---');
    buffer.writeln(stackTrace);
    return buffer.toString();
  }
}

class CrashService {
  static CrashService? _instance;
  static CrashService get instance => _instance ??= CrashService._();

  CrashService._();

  File get _crashReportFile {
    final dir = patrolStudioUserDataDirSync();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File(p.join(dir.path, 'last_crash.json'));
  }

  /// Initialize crash handlers for Flutter framework and Dart platform errors.
  void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Print to default console output first
      FlutterError.presentError(details);

      recordCrash(
        error: details.exceptionAsString(),
        stackTrace: details.stack?.toString() ?? StackTrace.current.toString(),
        library: details.library,
        context: details.context?.toString(),
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        print('[CrashService] Captured platform dispatcher error: $error');
      }

      recordCrash(
        error: error.toString(),
        stackTrace: stackTrace.toString(),
      );
      return false; // Allow standard handling if necessary
    };
  }

  /// Persists a crash report to disk synchronously or asynchronously.
  void recordCrash({
    required String error,
    required String stackTrace,
    String? library,
    String? context,
  }) {
    try {
      final report = CrashReport(
        timestamp: DateTime.now().toIso8601String(),
        error: error,
        stackTrace: stackTrace,
        library: library,
        context: context,
      );

      final file = _crashReportFile;
      file.writeAsStringSync(jsonEncode(report.toJson()), flush: true);
    } catch (e) {
      if (kDebugMode) {
        print('[CrashService] Failed to record crash report: $e');
      }
    }
  }

  /// Checks whether a crash report from a previous app run exists.
  bool hasPendingCrashReport() {
    try {
      final file = _crashReportFile;
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves the latest saved crash report, if any.
  CrashReport? getLatestCrashReport() {
    try {
      final file = _crashReportFile;
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync();
      if (content.isEmpty) return null;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CrashReport.fromJson(json);
    } catch (e) {
      if (kDebugMode) {
        print('[CrashService] Failed to read crash report: $e');
      }
      return null;
    }
  }

  /// Clears the recorded crash report file.
  void clearCrashReport() {
    try {
      final file = _crashReportFile;
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CrashService] Failed to clear crash report: $e');
      }
    }
  }
}
