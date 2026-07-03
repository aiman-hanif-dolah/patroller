import 'dart:async';
import 'dart:io';

enum ProcessStopOutcome {
  stopped,
  forceKilled,
  notFound,
  alreadyExited,
  failed,
}

class ProcessStopResult {
  const ProcessStopResult({required this.outcome, this.error});

  final ProcessStopOutcome outcome;
  final String? error;
}

class _ProcessEntry {
  _ProcessEntry({
    required this.process,
    required this.runId,
    required this.startTime,
  }) : exitCodeFuture = process.exitCode;

  final Process process;
  final String runId;
  final int startTime;
  final Future<int> exitCodeFuture;
  int? completedExitCode;
}

class ProcessRegistry {
  final Map<String, _ProcessEntry> _processes = {};

  void register(String runId, Process process) {
    final entry = _ProcessEntry(
      process: process,
      runId: runId,
      startTime: DateTime.now().millisecondsSinceEpoch,
    );
    unawaited(
      entry.exitCodeFuture.then((code) {
        entry.completedExitCode = code;
      }).catchError((_) {
        entry.completedExitCode = null;
      }),
    );
    _processes[runId] = entry;
  }

  bool has(String runId) => _processes.containsKey(runId);

  void remove(String runId) {
    _processes.remove(runId);
  }

  List<String> getRunIds() => _processes.keys.toList();

  void sendInput(String runId, String input) {
    final entry = _processes[runId];
    if (entry == null) {
      throw StateError('No active run: $runId');
    }
    entry.process.stdin.write(input);
  }

  /// Returns `null` while running, exit code (or null on error) after exit.
  int? tryWait(String runId) {
    final entry = _processes[runId];
    if (entry == null) return null;
    if (entry.completedExitCode != null) {
      final code = entry.completedExitCode;
      _processes.remove(runId);
      return code;
    }
    return null;
  }

  Future<ProcessStopResult> stop(
    String runId, {
    int timeoutMs = 5000,
    bool force = false,
  }) async {
    final entry = _processes[runId];
    if (entry == null) {
      return const ProcessStopResult(outcome: ProcessStopOutcome.notFound);
    }

    if (entry.completedExitCode != null) {
      _processes.remove(runId);
      return const ProcessStopResult(outcome: ProcessStopOutcome.alreadyExited);
    }

    final pid = entry.process.pid;

    if (force) {
      final killResult = await _killProcessGroupOrChild(pid, force: true);
      _processes.remove(runId);
      return ProcessStopResult(
        outcome: killResult.ok
            ? ProcessStopOutcome.forceKilled
            : ProcessStopOutcome.failed,
        error: killResult.error,
      );
    }

    final killResult = await _killProcessGroupOrChild(pid, force: false);
    if (!killResult.ok) {
      _processes.remove(runId);
      return ProcessStopResult(
        outcome: ProcessStopOutcome.failed,
        error: killResult.error,
      );
    }

    try {
      await entry.exitCodeFuture.timeout(Duration(milliseconds: timeoutMs));
      _processes.remove(runId);
      return const ProcessStopResult(outcome: ProcessStopOutcome.stopped);
    } on TimeoutException {
      final forceResult = await _killProcessGroupOrChild(pid, force: true);
      _processes.remove(runId);
      return ProcessStopResult(
        outcome: forceResult.ok
            ? ProcessStopOutcome.forceKilled
            : ProcessStopOutcome.failed,
        error: forceResult.error,
      );
    } catch (e) {
      _processes.remove(runId);
      return ProcessStopResult(outcome: ProcessStopOutcome.failed, error: e.toString());
    }
  }

  Future<List<ProcessStopResult>> stopAll({
    int timeoutMs = 5000,
    bool force = false,
  }) async {
    final results = <ProcessStopResult>[];
    for (final runId in getRunIds()) {
      results.add(await stop(runId, timeoutMs: timeoutMs, force: force));
    }
    return results;
  }
}

class _KillResult {
  const _KillResult({required this.ok, this.error});

  final bool ok;
  final String? error;
}

Future<_KillResult> _killProcessGroupOrChild(int pid, {required bool force}) async {
  if (pid <= 0) {
    return const _KillResult(ok: false, error: 'Process pid is not available');
  }

  if (Platform.isWindows) {
    final result = await Process.run(
      'taskkill',
      [
        if (force) '/F',
        '/T',
        '/PID',
        '$pid',
      ],
      runInShell: true,
    );
    if (result.exitCode == 0 || result.exitCode == 128) {
      return const _KillResult(ok: true);
    }
    final stderr = '${result.stderr}'.trim();
    return _KillResult(
      ok: false,
      error: stderr.isEmpty
          ? 'taskkill failed with code ${result.exitCode}'
          : stderr,
    );
  }

  final signal = force ? 'KILL' : 'TERM';
  var groupResult = await Process.run('kill', ['-$signal', '-$pid']);
  if (groupResult.exitCode == 0) {
    return const _KillResult(ok: true);
  }

  final childResult = await Process.run('kill', [force ? '-9' : '-15', '$pid']);
  if (childResult.exitCode == 0) {
    return const _KillResult(ok: true);
  }

  final groupErr = '${groupResult.stderr}'.trim();
  final childErr = '${childResult.stderr}'.trim();
  if (groupErr.contains('No such process') || childErr.contains('No such process')) {
    return const _KillResult(ok: true);
  }

  return _KillResult(
    ok: false,
    error: groupErr.isEmpty ? childErr : '$groupErr; $childErr',
  );
}

final ProcessRegistry processRegistry = ProcessRegistry();