// ignore_for_file: avoid_print
//
// CLI: generate a Patroller HTML report for any Flutter + Patrol project.
//
// Usage:
//   dart run bin/patroller_report.dart --project /path/to/app --logs /path/to/*.log
//   dart run bin/patroller_report.dart -p . -l ~/Library/Logs/my-patrol/*.log -o ~/Downloads/out.html
//
// Options:
//   --project, -p   Flutter project root (required)
//   --logs, -l      Glob or one-or-more log file paths (required unless --help)
//   --out, -o       Output HTML path (default: ~/Downloads/<project>-patrol-report-<ts>.html)
//   --device, -d    Optional device label for the report header
//   --mode, -m      Optional run mode label (test/develop/mock/…)
//   --name, -n      Override project display name
//   --help, -h

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:patroller/services/report_export.dart';

void main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _usage();
    exit(args.isEmpty ? 64 : 0);
  }

  String? project;
  String? out;
  String? device;
  String? mode;
  String? name;
  final logSpecs = <String>[];

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String? next() => i + 1 < args.length ? args[++i] : null;
    switch (a) {
      case '--project':
      case '-p':
        project = next();
      case '--out':
      case '-o':
        out = next();
      case '--device':
      case '-d':
        device = next();
      case '--mode':
      case '-m':
        mode = next();
      case '--name':
      case '-n':
        name = next();
      case '--logs':
      case '-l':
        final v = next();
        if (v != null) logSpecs.add(v);
      default:
        if (a.startsWith('-')) {
          stderr.writeln('Unknown option: $a');
          _usage();
          exit(64);
        }
        // Bare path: treat as log if it looks like a log, else project
        if (a.endsWith('.log') || a.contains('*')) {
          logSpecs.add(a);
        } else if (project == null) {
          project = a;
        } else {
          logSpecs.add(a);
        }
    }
  }

  final projectArg = project;
  if (projectArg == null || projectArg.isEmpty) {
    stderr.writeln('Error: --project is required');
    _usage();
    exit(64);
  }

  final projectPath = p.normalize(Directory(projectArg).absolute.path);
  if (!Directory(projectPath).existsSync()) {
    stderr.writeln('Error: project path does not exist: $projectPath');
    exit(2);
  }
  if (!File(p.join(projectPath, 'pubspec.yaml')).existsSync()) {
    stderr.writeln(
      'Warning: no pubspec.yaml under $projectPath — continuing anyway',
    );
  }

  if (logSpecs.isEmpty) {
    stderr.writeln('Error: provide at least one --logs path or glob');
    _usage();
    exit(64);
  }

  final logFiles = <File>[];
  for (final spec in logSpecs) {
    logFiles.addAll(_expandLogs(spec));
  }
  if (logFiles.isEmpty) {
    stderr.writeln('Error: no log files matched: $logSpecs');
    exit(2);
  }

  final projectName = name?.trim().isNotEmpty == true
      ? name!.trim()
      : p.basename(projectPath);

  final export = ReportExportService();
  final result = await export.exportFromLogFiles(
    projectPath: projectPath,
    projectName: projectName,
    logFiles: logFiles,
    device: device,
    runMode: mode,
    outputPath: out,
    alsoWriteStableName: out == null,
  );

  stdout.writeln('Report written: ${result.path}');
  stdout.writeln(
    'Scenarios: ${result.report.scenarioPassed} passed / '
    '${result.report.scenarioFailed} failed / '
    '${result.report.scenarioTotal} total '
    '(or target rollup ${result.report.targetPassedSum}/'
    '${result.report.targetFailedSum})',
  );
  stdout.writeln(
    'Leaves: ${result.report.leafPassed} passed / '
    '${result.report.leafFailed} failed / '
    '${result.report.leaves.length} listed',
  );
  exit(result.report.scenarioFailed > 0 || result.report.targetFailedSum > 0
      ? 1
      : 0);
}

List<File> _expandLogs(String spec) {
  final out = <File>[];
  if (spec.contains('*') || spec.contains('?')) {
    final dir = Directory(p.dirname(spec));
    final pattern = p.basename(spec);
    if (!dir.existsSync()) return out;
    final re = RegExp(
      '^${RegExp.escape(pattern).replaceAll('\\*', '.*').replaceAll('\\?', '.')}\$',
    );
    for (final e in dir.listSync()) {
      if (e is File && re.hasMatch(p.basename(e.path))) {
        out.add(e);
      }
    }
  } else {
    final f = File(spec);
    if (f.existsSync()) out.add(f);
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}

void _usage() {
  stdout.writeln('''
patroller_report — HTML Patrol report for any Flutter project

Usage:
  dart run bin/patroller_report.dart --project <path> --logs <file|glob> [...]
  dart run bin/patroller_report.dart -p . -l ~/Library/Logs/my-app/*.log

Options:
  -p, --project   Flutter project root
  -l, --logs      Log file path or simple glob (basename * only)
  -o, --out       Output HTML path (default: Patrol Studio/reports/)
  -d, --device    Device label for report header
  -m, --mode      Mode label (test, mock, live, …)
  -n, --name      Display name override
  -h, --help      Show this help

Exit codes: 0 all green · 1 failures present · 2 bad input · 64 usage
''');
}
