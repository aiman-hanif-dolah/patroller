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