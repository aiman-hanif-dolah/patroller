import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'app_provider.dart';
import 'runner_provider.dart';

TestFile? _findFile(List<TestFile> files, String? path) {
  if (path == null) return null;
  return files.where((f) => f.absolutePath == path).firstOrNull;
}

/// File currently executing in the runner (single test or Test All item).
final activeRunFileProvider = Provider<TestFile?>((ref) {
  final runner = ref.watch(runnerProvider);
  final app = ref.watch(appProvider);
  return _findFile(app.testFiles, runner.currentRun?.targetFile);
});

/// Active file while Test All is running (same path as [activeRunFileProvider]).
final currentQueueFileProvider = Provider<TestFile?>((ref) {
  final runner = ref.watch(runnerProvider);
  final app = ref.watch(appProvider);
  if (runner.runAllContext == null) return null;
  return _findFile(app.testFiles, runner.currentRun?.targetFile);
});

/// Suite context for Develop All / Test All: list of files + currently active one.
class SuiteContext {
  const SuiteContext({required this.files, this.current});
  final List<TestFile> files;
  final TestFile? current;
}

final suiteContextProvider = Provider<SuiteContext?>((ref) {
  final runner = ref.watch(runnerProvider);
  final app = ref.watch(appProvider);
  final targetFiles = runner.currentRun?.targetFiles;
  if (targetFiles == null || targetFiles.isEmpty) return null;
  final files = targetFiles
      .map((p) => app.testFiles.where((f) => f.absolutePath == p).firstOrNull)
      .whereType<TestFile>()
      .toList();
  final current = _findFile(app.testFiles, runner.currentRun?.targetFile);
  return SuiteContext(files: files, current: current);
});