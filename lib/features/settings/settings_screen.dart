import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/settings_provider.dart';

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

  Future<bool> _handleSave() async {
    if (!_isDirty) return true;
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
            'Stop queue on failure',
            _local.stopQueueOnFirstFailure,
            (v) => _set(
              (s) => s.stopQueueOnFirstFailure,
              (s, v) => s.copyWith(stopQueueOnFirstFailure: v),
              v,
            ),
          ),
          _section('Logs'),
          _row(
            'Retention count',
            TextField(
              keyboardType: TextInputType.number,
              controller:
                  TextEditingController(text: '${_local.logRetentionCount}'),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null) {
                  _set(
                    (s) => s.logRetentionCount,
                    (s, v) => s.copyWith(logRetentionCount: v),
                    parsed,
                  );
                }
              },
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
          _section('CLI Paths'),
          _row(
            'Patrol',
            TextField(
              controller: TextEditingController(text: _local.patrolPath),
              onChanged: (v) => _set(
                (s) => s.patrolPath,
                (s, v) => s.copyWith(patrolPath: v),
                v,
              ),
            ),
          ),
          _row(
            'Flutter',
            TextField(
              controller: TextEditingController(text: _local.flutterPath),
              onChanged: (v) => _set(
                (s) => s.flutterPath,
                (s, v) => s.copyWith(flutterPath: v),
                v,
              ),
            ),
          ),
          _row(
            'Dart',
            TextField(
              controller: TextEditingController(text: _local.dartPath),
              onChanged: (v) => _set(
                (s) => s.dartPath,
                (s, v) => s.copyWith(dartPath: v),
                v,
              ),
            ),
          ),
          _row(
            'xcrun',
            TextField(
              controller: TextEditingController(text: _local.xcrunPath),
              onChanged: (v) => _set(
                (s) => s.xcrunPath,
                (s, v) => s.copyWith(xcrunPath: v),
                v,
              ),
            ),
          ),
          _section('Layout'),
          _row(
            'Right panel width',
            TextField(
              keyboardType: TextInputType.number,
              controller:
                  TextEditingController(text: '${_local.rightPanelWidth.round()}'),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) {
                  _set(
                    (s) => s.rightPanelWidth,
                    (s, v) => s.copyWith(rightPanelWidth: v),
                    parsed.round(),
                  );
                }
              },
            ),
          ),
          _row(
            'Logs panel width',
            TextField(
              keyboardType: TextInputType.number,
              controller:
                  TextEditingController(text: '${_local.logsPanelWidth.round()}'),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) {
                  _set(
                    (s) => s.logsPanelWidth,
                    (s, v) => s.copyWith(logsPanelWidth: v),
                    parsed.round(),
                  );
                }
              },
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
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: PatrolColors.steel,
        ),
      ),
    );
  }

  Widget _row(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: PatrolColors.graphite),
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
}