import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/report/html_report_generator.dart';
import '../domain/report/report_aggregator.dart';
import '../domain/report/report_models.dart';
import '../models/models.dart';
import 'app_paths.dart';

/// Result of writing a Patrol HTML report to disk.
class ReportExportResult {
  const ReportExportResult({
    required this.path,
    required this.report,
  });

  final String path;
  final BatchReport report;
}

/// Writes HTML reports under Patrol Studio app data (not Downloads).
/// The desktop UI prompts the user to open the file after generation.
class ReportExportService {
  ReportExportService({
    ReportAggregator? aggregator,
    HtmlReportGenerator? generator,
  })  : _aggregator = aggregator ?? ReportAggregator(),
        _generator = generator ?? const HtmlReportGenerator();

  final ReportAggregator _aggregator;
  final HtmlReportGenerator _generator;

  /// Default output directory: …/Patrol Studio/reports
  /// Uses sync home-based paths so CLI (`dart run`) does not pull in Flutter.
  Future<Directory> defaultReportsDir() async => defaultReportsDirSync();

  /// Sync path for CLI and desktop (no path_provider / dart:ui).
  Directory defaultReportsDirSync() {
    final root = patrolStudioUserDataDirSync();
    final dir = Directory(p.join(root.path, 'reports'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  String defaultFileName(String projectName, {DateTime? at}) {
    final t = at ?? DateTime.now();
    final stamp =
        '${t.year}${_two(t.month)}${_two(t.day)}-${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';
    final safe = projectName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final base = safe.isEmpty ? 'patrol-report' : '$safe-patrol-report';
    return '$base-$stamp.html';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Future<ReportExportResult> exportFromRecords({
    required String projectPath,
    required String projectName,
    required List<RunRecord> records,
    String? queueLabel,
    String? queueId,
    String? device,
    String? runMode,
    String? outputPath,
    bool alsoWriteStableName = false,
  }) async {
    final report = _aggregator.fromRunRecords(
      projectPath: projectPath,
      projectName: projectName,
      records: records,
      queueLabel: queueLabel,
      queueId: queueId,
      device: device,
      runMode: runMode,
    );
    return _writeReport(
      report,
      outputPath: outputPath,
      alsoWriteStableName: alsoWriteStableName,
    );
  }

  Future<ReportExportResult> exportFromLogFiles({
    required String projectPath,
    required String projectName,
    required List<File> logFiles,
    String? device,
    String? runMode,
    String? outputPath,
    bool alsoWriteStableName = false,
  }) async {
    final report = _aggregator.fromLogFiles(
      projectPath: projectPath,
      projectName: projectName,
      logFiles: logFiles,
      device: device,
      runMode: runMode,
    );
    return _writeReport(
      report,
      outputPath: outputPath,
      alsoWriteStableName: alsoWriteStableName,
    );
  }

  Future<ReportExportResult> _writeReport(
    BatchReport report, {
    String? outputPath,
    bool alsoWriteStableName = false,
  }) async {
    final reportsDir = await defaultReportsDir();

    final File outFile;
    if (outputPath != null && outputPath.isNotEmpty) {
      outFile = File(outputPath);
      final parent = outFile.parent;
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
    } else {
      outFile = File(
        p.join(
          reportsDir.path,
          defaultFileName(report.projectName, at: report.generatedAt),
        ),
      );
    }

    final html = _generator.generate(report);
    await outFile.writeAsString(html);

    if (alsoWriteStableName && outputPath == null) {
      final stable = File(
        p.join(
          reportsDir.path,
          '${_stableBase(report.projectName)}-patrol-report.html',
        ),
      );
      await stable.writeAsString(html);
    }

    return ReportExportResult(path: outFile.path, report: report);
  }

  String _stableBase(String projectName) {
    final safe = projectName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return safe.isEmpty ? 'project' : safe.toLowerCase();
  }
}
