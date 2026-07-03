import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/patrol_studio_facade.dart';
import 'facade_provider.dart';
import 'health_provider.dart';
import 'log_provider.dart';

class SettingsState {
  const SettingsState({
    required this.settings,
    required this.loaded,
    this.validationErrors = const {},
  });

  final AppSettings settings;
  final bool loaded;
  final Map<String, String> validationErrors;

  SettingsState copyWith({
    AppSettings? settings,
    bool? loaded,
    Map<String, String>? validationErrors,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      loaded: loaded ?? this.loaded,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._ref)
      : super(SettingsState(
          settings: AppSettings.defaults(),
          loaded: false,
        )) {
    load();
  }

  final Ref _ref;

  PatrolStudioFacade get _facade => _ref.read(patrolStudioFacadeProvider);

  Future<void> load() async {
    try {
      final settings = await _facade.settings.get();
      state = SettingsState(settings: settings, loaded: true);
      _ref.read(logProvider.notifier).applySettings(settings);
    } catch (_) {
      final defaults = _facade.settings.getDefaults();
      state = SettingsState(settings: defaults, loaded: true);
      _ref.read(logProvider.notifier).applySettings(defaults);
    }
  }

  Future<void> update(AppSettings settings) async {
    await _facade.settings.set(settings.toJson());
    state = state.copyWith(settings: settings, validationErrors: {});
    _ref.read(logProvider.notifier).applySettings(settings);
  }

  Future<void> updatePartial(Map<String, dynamic> partial) async {
    final updated = await _facade.settings.set(partial);
    state = state.copyWith(settings: updated);
    _ref.read(logProvider.notifier).applySettings(updated);
    _ref.read(healthProvider.notifier).markStale();
  }

  void setValidationErrors(Map<String, String> errors) {
    state = state.copyWith(validationErrors: errors);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref),
);