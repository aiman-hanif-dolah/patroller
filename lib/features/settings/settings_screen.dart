import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/settings_validation.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/panel_resize_handle.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onDirtyChanged,
    required this.onSavingChanged,
    required this.saveNotifier,
  });

  final ValueChanged<bool> onDirtyChanged;
  final ValueChanged<bool> onSavingChanged;
  final SettingsSaveNotifier saveNotifier;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class SettingsSaveNotifier {
  Future<bool> Function()? save;
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AppSettings _local = AppSettings.defaults();
  bool _initialized = false;
  bool _saving = false;
  String? _saveError;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    widget.saveNotifier.save = _handleSave;
  }

  @override
  void dispose() {
    widget.saveNotifier.save = null;
    super.dispose();
  }

  bool get _isDirty {
    final current = ref.read(settingsProvider).settings;
    return _local != current;
  }

  void _set<K>(K Function(AppSettings) getter, AppSettings Function(AppSettings, K) updater, K value) {
    setState(() {
      _local = updater(_local, value);
      _saveError = null;
      widget.onDirtyChanged(_isDirty);
    });
  }

  void _validateLocal() {
    final errors = validateAppSettings(_local);
    setState(() {
      _fieldErrors = {for (final e in errors) e.field: e.message};
    });
  }

  Future<bool> _handleSave() async {
    if (!_isDirty) return true;
    _validateLocal();
    if (_fieldErrors.isNotEmpty) {
      setState(() => _saveError = 'Fix validation errors before saving.');
      return false;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    widget.onSavingChanged(true);
    try {
      await ref.read(settingsProvider.notifier).update(_local);
      widget.onDirtyChanged(false);
      ref.read(appProvider.notifier).setHealthStale(true);
      return true;
    } catch (e) {
      setState(() => _saveError = e.toString());
      return false;
    } finally {
      setState(() => _saving = false);
      widget.onSavingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final loaded = ref.watch(settingsProvider).loaded;
    if (loaded && !_initialized) {
      _local = ref.read(settingsProvider).settings;
      _initialized = true;
    }
    if (!loaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_saveError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PatrolColors.rose300.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: PatrolColors.rose300.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _saveError!,
                style: const TextStyle(color: PatrolColors.rose300),
              ),
            ),
          _section('General'),
          _row(
            'Theme',
            DropdownButton<AppTheme>(
              value: _local.theme,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: AppTheme.light, child: Text('Light')),
                DropdownMenuItem(value: AppTheme.dark, child: Text('Dark')),
                DropdownMenuItem(value: AppTheme.system, child: Text('System')),
              ],
              onChanged: (v) {
                if (v != null) {
                  _set(
                    (s) => s.theme,
                    (s, v) => s.copyWith(theme: v),
                    v,
                  );
                }
              },
            ),
          ),
          _checkboxRow(
            'Confirm before full suite',
            _local.confirmBeforeRun,
            (v) => _set(
              (s) => s.confirmBeforeRun,
              (s, v) => s.copyWith(confirmBeforeRun: v),
              v,
            ),
          ),
          _checkboxRow(
            'Confirm before clearing history',
            _local.confirmBeforeClearHistory,
            (v) => _set(
              (s) => s.confirmBeforeClearHistory,
              (s, v) => s.copyWith(confirmBeforeClearHistory: v),
              v,
            ),
          ),
          _section('Run'),
          _row(
            'Default mode',
            DropdownButton<RunMode>(
              value: _local.defaultRunMode,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: RunMode.test, child: Text('Test')),
                DropdownMenuItem(
                  value: RunMode.develop,
                  child: Text('Develop'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  _set(
                    (s) => s.defaultRunMode,
                    (s, v) => s.copyWith(defaultRunMode: v),
                    v,
                  );
                }
              },
            ),
          ),
          _row(
            'Test directory',
            TextField(
              controller: TextEditingController(text: _local.testDirectory),
              onChanged: (v) => _set(
                (s) => s.testDirectory,
                (s, v) => s.copyWith(testDirectory: v),
                v,
              ),
            ),
          ),
          _checkboxRow(
            'Stop Test All on first failure',
            _local.stopQueueOnFirstFailure,
            (v) => _set(
              (s) => s.stopQueueOnFirstFailure,
              (s, v) => s.copyWith(stopQueueOnFirstFailure: v),
              v,
            ),
          ),
          _section('Logs'),
          _numericRow(
            field: 'logRetentionCount',
            label: 'Retention count',
            value: '${_local.logRetentionCount}',
            min: 10,
            max: 1000,
            onValid: (parsed) => _set(
              (s) => s.logRetentionCount,
              (s, v) => s.copyWith(logRetentionCount: v),
              parsed,
            ),
          ),
          _checkboxRow(
            'Auto-scroll',
            _local.autoScrollLogs,
            (v) => _set(
              (s) => s.autoScrollLogs,
              (s, v) => s.copyWith(autoScrollLogs: v),
              v,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show raw stderr'),
            subtitle: Text(
              'Off hides dependency notices behind a collapsible summary.',
              style: TextStyle(fontSize: 11, color: p.textMuted),
            ),
            value: _local.showRawStderr,
            onChanged: (value) => _set(
              (s) => s.showRawStderr,
              (s, v) => s.copyWith(showRawStderr: v),
              value,
            ),
          ),
          _section('CLI Paths'),
          _pathRow(
            field: 'patrolPath',
            label: 'Patrol',
            value: _local.patrolPath,
            onChanged: (v) => _set(
              (s) => s.patrolPath,
              (s, v) => s.copyWith(patrolPath: v),
              v,
            ),
          ),
          _pathRow(
            field: 'flutterPath',
            label: 'Flutter',
            value: _local.flutterPath,
            onChanged: (v) => _set(
              (s) => s.flutterPath,
              (s, v) => s.copyWith(flutterPath: v),
              v,
            ),
          ),
          _pathRow(
            field: 'dartPath',
            label: 'Dart',
            value: _local.dartPath,
            onChanged: (v) => _set(
              (s) => s.dartPath,
              (s, v) => s.copyWith(dartPath: v),
              v,
            ),
          ),
          _pathRow(
            field: 'xcrunPath',
            label: 'xcrun',
            value: _local.xcrunPath,
            onChanged: (v) => _set(
              (s) => s.xcrunPath,
              (s, v) => s.copyWith(xcrunPath: v),
              v,
            ),
          ),
          _section('Layout'),
          _numericRow(
            field: 'rightPanelWidth',
            label: 'Right panel width',
            value: '${_local.rightPanelWidth}',
            min: rightPanelMinWidth.round(),
            max: rightPanelMaxWidth.round(),
            onValid: (parsed) => _set(
              (s) => s.rightPanelWidth,
              (s, v) => s.copyWith(rightPanelWidth: v),
              parsed,
            ),
          ),
          _numericRow(
            field: 'logsPanelWidth',
            label: 'Logs panel width',
            value: '${_local.logsPanelWidth}',
            min: logsPanelMinWidth.round(),
            max: logsPanelMaxWidth.round(),
            onValid: (parsed) => _set(
              (s) => s.logsPanelWidth,
              (s, v) => s.copyWith(logsPanelWidth: v),
              parsed,
            ),
          ),
          _section('DevTools Extension'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable DevTools extension server'),
            subtitle: Text(
              'Exposes Patroller over a local HTTP/WebSocket server so the '
              'DevTools panel can drive runs, devices, inspector, and recordings.',
              style: TextStyle(fontSize: 11, color: p.textMuted),
            ),
            value: _local.enableDevtoolsExtension,
            onChanged: (value) => _set(
              (s) => s.enableDevtoolsExtension,
              (s, v) => s.copyWith(enableDevtoolsExtension: v),
              value,
            ),
          ),
          _numericRow(
            field: 'devtoolsExtensionPort',
            label: 'Extension port',
            value: '${_local.devtoolsExtensionPort}',
            min: 1024,
            max: 65535,
            onValid: (parsed) => _set(
              (s) => s.devtoolsExtensionPort,
              (s, v) => s.copyWith(devtoolsExtensionPort: v),
              parsed,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                final reset = AppSettings.resetLayoutDefaults(_local);
                setState(() => _local = reset);
                _validateLocal();
                widget.onDirtyChanged(_isDirty);
                await ref.read(settingsProvider.notifier).updatePartial({
                  'logsCollapsed': reset.logsCollapsed,
                  'rightCollapsed': reset.rightCollapsed,
                  'controlDeckCollapsed': reset.controlDeckCollapsed,
                  'logsPanelWidth': reset.logsPanelWidth,
                  'rightPanelWidth': reset.rightPanelWidth,
                });
              },
              icon: const Icon(Icons.restart_alt, size: 14),
              label: const Text('Reset layout'),
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    final p = PatrolPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: p.textMuted,
        ),
      ),
    );
  }

  Widget _row(String label, Widget child) {
    final p = PatrolPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: p.textSecondary),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _checkboxRow(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
    );
  }

  Widget _numericRow({
    required String field,
    required String label,
    required String value,
    required int min,
    required int max,
    required ValueChanged<int> onValid,
  }) {
    final p = PatrolPalette.of(context);
    final error = _fieldErrors[field];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: p.textSecondary),
            ),
          ),
          Expanded(
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                errorText: error,
                helperText: '$min–$max',
                helperStyle: const TextStyle(fontSize: 10),
              ),
              controller: TextEditingController(text: value),
              onChanged: (v) {
                final parsed = parsePositiveInt(v, min: min, max: max);
                setState(() {
                  if (parsed == null && v.trim().isNotEmpty) {
                    _fieldErrors = {
                      ..._fieldErrors,
                      field: 'Enter a number between $min and $max.',
                    };
                  } else {
                    final next = Map<String, String>.from(_fieldErrors)
                      ..remove(field);
                    _fieldErrors = next;
                  }
                });
                if (parsed != null) onValid(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pathRow({
    required String field,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final p = PatrolPalette.of(context);
    final error = _fieldErrors[field];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: p.textSecondary),
            ),
          ),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                errorText: error,
              ),
              controller: TextEditingController(text: value),
              onChanged: (v) {
                setState(() {
                  if (v.trim().isEmpty) {
                    _fieldErrors = {
                      ..._fieldErrors,
                      field: 'Path cannot be empty.',
                    };
                  } else {
                    final next = Map<String, String>.from(_fieldErrors)
                      ..remove(field);
                    _fieldErrors = next;
                  }
                });
                onChanged(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                dialogTitle: 'Select $label executable',
              );
              final path = result?.files.single.path;
              if (path != null) onChanged(path);
            },
            child: const Text('Browse'),
          ),
        ],
      ),
    );
  }
}