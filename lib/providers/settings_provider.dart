import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/patrol_studio_facade.dart';
import 'facade_provider.dart';
import 'health_stale.dart';
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
    final log = File('${Platform.environment['HOME'] ?? ''}/patroller_ext_err.log');
    try {
      log.writeAsStringSync('load() entered\n', mode: FileMode.append);
    } catch (_) {}
    try {
      final settings = await _facade.settings.get();
      try {
        log.writeAsStringSync('got settings enable=${settings.enableDevtoolsExtension}\n', mode: FileMode.append);
      } catch (_) {}
      state = SettingsState(settings: settings, loaded: true);
      _ref.read(logProvider.notifier).applySettings(settings);
      await _applyExtensionServer(settings);
    } catch (_) {
      final defaults = _facade.settings.getDefaults();
      state = SettingsState(settings: defaults, loaded: true);
      _ref.read(logProvider.notifier).applySettings(defaults);
      await _applyExtensionServer(defaults);
    }
  }

  Future<void> _applyExtensionServer(AppSettings settings) async {
    final log = File(
      '${Platform.environment['HOME'] ?? ''}/patroller_ext_err.log',
    );
    try {
      log.writeAsStringSync('applyExtensionServer enable=${settings.enableDevtoolsExtension}\n', mode: FileMode.append);
    } catch (_) {}
    try {
      if (settings.enableDevtoolsExtension) {
        await _facade.startExtensionServer(port: settings.devtoolsExtensionPort);
        try {
          log.writeAsStringSync('OK started on ${settings.devtoolsExtensionPort}\n', mode: FileMode.append);
        } catch (_) {}
      } else {
        await _facade.stopExtensionServer();
      }
    } catch (e, st) {
      try {
        log.writeAsStringSync('ERR: $e\n$st\n', mode: FileMode.append);
      } catch (_) {}
    }
  }

  Future<void> update(AppSettings settings) async {
    // Apply locally first so theme / layout controls react immediately.
    state = state.copyWith(settings: settings, validationErrors: {});
    _ref.read(logProvider.notifier).applySettings(settings);
    await _facade.settings.set(settings.toJson());
    await _applyExtensionServer(settings);
  }

  static const _layoutOnlyKeys = {
    'logsCollapsed',
    'rightCollapsed',
    'logsPanelWidth',
    'rightPanelWidth',
    'previewPanelWidth',
    'previewCollapsed',
    'controlDeckCollapsed',
  };

  bool _isLayoutOnlyPartial(Map<String, dynamic> partial) =>
      partial.isNotEmpty && partial.keys.every(_layoutOnlyKeys.contains);

  Future<void> updatePartial(Map<String, dynamic> partial) async {
    final updated = await _facade.settings.set(partial);
    state = state.copyWith(settings: updated);
    final layoutOnly = _isLayoutOnlyPartial(partial);
    if (!layoutOnly) {
      _ref.read(logProvider.notifier).applySettings(updated);
      markHealthStale(_ref);
    }
    if (partial.containsKey('enableDevtoolsExtension') ||
        partial.containsKey('devtoolsExtensionPort')) {
      await _applyExtensionServer(updated);
    }
  }

  void setValidationErrors(Map<String, String> errors) {
    state = state.copyWith(validationErrors: errors);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref),
);