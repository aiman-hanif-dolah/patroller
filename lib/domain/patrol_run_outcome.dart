import 'report/patrol_log_parser.dart';

/// Forces test-mode builds not to inherit develop's hot-restart wait loop.
///
/// `patrol develop` sets `PATROL_HOT_RESTART=true`. Stale iOS config / DerivedData
/// can leave that define active for a later `patrol test`, so the last Dart test
/// hangs (`All tests were executed…`) until XCTest SIGKILLs the runner and
/// xcodebuild exits 65 — even when assertions passed.
const String patrolHotRestartOffDefine = 'PATROL_HOT_RESTART=false';

/// CLI args that disable develop hot-restart for non-interactive `patrol test`.
List<String> patrolTestModeDartDefineArgs() => [
      '--dart-define',
      patrolHotRestartOffDefine,
    ];

/// Strip ANSI / stream tags for matching.
String _normalizePatrolLog(String raw) {
  return raw
      .replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '')
      .replaceAll(RegExp(r'\[stdout\]|\[stderr\]'), '')
      .toLowerCase();
}

/// True when logs show develop's end-of-cycle prompt during a non-develop run.
bool hasDevelopHotRestartWaitMessage(String raw) {
  return _normalizePatrolLog(raw).contains('all tests were executed');
}

/// True when xcodebuild reported exit 65 (generic iOS test/build failure).
bool hasXcodebuildExit65(String raw) {
  return _normalizePatrolLog(raw).contains('xcodebuild exited with code 65');
}

/// Develop hot-restart contamination: tests looked green, then xcodebuild 65.
///
/// Do **not** treat this as success — XCTest often SIGKILLs the hung runner, so
/// the suite did not finish cleanly. Callers should surface this diagnosis and
/// ensure `PATROL_HOT_RESTART=false` on test invocations.
bool isStaleHotRestartTestFailure(String raw) {
  if (!hasXcodebuildExit65(raw)) return false;
  if (!hasDevelopHotRestartWaitMessage(raw)) return false;
  final counts = PatrolLogParser().parseSuiteCounts(raw);
  if (counts == null) return true;
  return counts.failed == 0;
}
