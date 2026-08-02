import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/routine_models.dart';

void main() {
  test('only models with explicit zero costs are verified free', () {
    expect(
      const OpenCodeModel(
        id: 'provider/free',
        provider: 'provider',
        name: 'free',
        inputCost: 0,
        outputCost: 0,
      ).verifiedFree,
      isTrue,
    );
    expect(
      const OpenCodeModel(
        id: 'provider/unknown',
        provider: 'provider',
        name: 'unknown',
        inputCost: null,
        outputCost: null,
      ).verifiedFree,
      isFalse,
    );
  });

  test('routine readiness exposes failed checks and effective write paths', () {
    const report = RoutineReadinessReport(
      status: RoutineReadiness.repairable,
      checks: [
        RoutineCheck(
          id: 'patrol',
          label: 'Patrol',
          ok: false,
          detail: 'missing',
          repairable: true,
        ),
      ],
      projectPath: '/tmp/project',
      entrypoint: 'lib/main.dart',
      preview: ['flutter pub add --dev patrol'],
    );

    expect(report.ok, isTrue);
    expect(report.failures.single.id, 'patrol');
    expect(report.effectiveWriteLocations, contains('lib/main.dart'));
    expect(report.effectiveWriteLocations, contains('patrol_test/**'));
  });

  test('ProjectDependency exposes removal preview command and affected files', () {
    const dep = ProjectDependency(
      name: 'some_package',
      section: 'dependencies',
      constraint: '^1.0.0',
    );
    expect(dep.removeCommand, 'flutter pub remove some_package');
    expect(dep.affectedFiles, ['pubspec.yaml', 'pubspec.lock']);
  });

  test('PermissionRequest holds tool and description metadata', () {
    const req = PermissionRequest(
      id: 'req_123',
      tool: 'marionette',
      description: 'Interact with debug Flutter tree',
    );
    expect(req.id, 'req_123');
    expect(req.tool, 'marionette');
    expect(req.description, contains('Flutter tree'));
  });

  test('RoutinePlan supports allowDirtyWorktree configuration', () {
    const plan = RoutinePlan(
      projectPath: '/tmp/app',
      goal: 'Explore',
      model: 'provider/free',
      allowDirtyWorktree: true,
    );
    expect(plan.allowDirtyWorktree, isTrue);
  });

  test('RoutineResult tracks stopping reason and test pass/fail sweeps', () {
    final now = DateTime.now();
    final result = RoutineResult(
      status: RoutineStatus.completed,
      message: 'Done',
      startedAt: now,
      finishedAt: now.add(const Duration(minutes: 10)),
      baselinePassed: true,
      finalSweepPassed: true,
      passedTests: ['patrol_test/home_test.dart'],
      failedTests: [],
      changedFiles: ['patrol_test/home_test.dart'],
      stoppingReason: 'Agent converged and verified all tests pass',
    );

    expect(result.status, RoutineStatus.completed);
    expect(result.baselinePassed, isTrue);
    expect(result.finalSweepPassed, isTrue);
    expect(result.stoppingReason, contains('converged'));
  });
}
