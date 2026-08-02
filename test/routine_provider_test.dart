import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/routine_models.dart';
import 'package:patroller/providers/routine_provider.dart';

void main() {
  test('RoutineState copyWith and initial defaults', () {
    const state = RoutineState();
    expect(state.status, RoutineStatus.idle);
    expect(state.busy, isFalse);
    expect(state.goal, contains('Explore stable user journeys'));

    final updated = state.copyWith(status: RoutineStatus.running);
    expect(updated.status, RoutineStatus.running);
    expect(updated.busy, isTrue);
  });

  test('RoutineState status labels and platform notes', () {
    expect(routineStatusLabel(RoutineStatus.idle), 'Idle');
    expect(routineStatusLabel(RoutineStatus.awaitingApproval), 'Approval required');
    expect(routineStatusLabel(RoutineStatus.running), 'Routine running');
    expect(routineStatusLabel(RoutineStatus.completed), 'Completed');
    expect(routineStatusLabel(RoutineStatus.needsAttention), 'Needs attention');
  });
}
