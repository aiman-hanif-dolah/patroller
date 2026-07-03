import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

class InspectorState {
  const InspectorState({
    this.hierarchy,
    this.selectedNode,
    this.loading = false,
    this.error,
    this.driverUnavailable = false,
  });

  final HierarchyNode? hierarchy;
  final HierarchyNode? selectedNode;
  final bool loading;
  final String? error;
  final bool driverUnavailable;

  InspectorState copyWith({
    HierarchyNode? hierarchy,
    HierarchyNode? selectedNode,
    bool? loading,
    String? error,
    bool? driverUnavailable,
    bool clearHierarchy = false,
    bool clearSelected = false,
    bool clearError = false,
  }) {
    return InspectorState(
      hierarchy: clearHierarchy ? null : (hierarchy ?? this.hierarchy),
      selectedNode: clearSelected ? null : (selectedNode ?? this.selectedNode),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      driverUnavailable: driverUnavailable ?? this.driverUnavailable,
    );
  }
}

class InspectorNotifier extends StateNotifier<InspectorState> {
  InspectorNotifier() : super(const InspectorState());

  void setHierarchy(HierarchyNode? hierarchy) {
    state = state.copyWith(
      hierarchy: hierarchy,
      selectedNode: hierarchy,
      clearError: true,
      driverUnavailable: false,
    );
  }

  void selectNode(HierarchyNode? node) {
    state = state.copyWith(selectedNode: node, clearSelected: node == null);
  }

  void setLoading(bool loading) {
    state = state.copyWith(loading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error, loading: false);
  }

  void setDriverUnavailable() {
    state = state.copyWith(
      driverUnavailable: true,
      clearHierarchy: true,
      clearSelected: true,
      loading: false,
    );
  }

  void reset() {
    state = const InspectorState();
  }
}

final inspectorProvider =
    StateNotifierProvider<InspectorNotifier, InspectorState>(
  (ref) => InspectorNotifier(),
);