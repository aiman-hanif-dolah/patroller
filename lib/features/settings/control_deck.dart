import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/settings_validation.dart';
import '../../models/models.dart';
import '../../providers/settings_provider.dart';

/// Compact bento settings strip - sits under the Logs column so Workspace
/// keeps full height on the top-right.
class ControlDeck extends ConsumerStatefulWidget {
  const ControlDeck({super.key});

  @override
  ConsumerState<ControlDeck> createState() => _ControlDeckState();
}

class _ControlDeckState extends ConsumerState<ControlDeck> {
  static const _debounce = Duration(milliseconds: 400);

  Timer? _saveTimer;
  AppSettings? _draft;
  Map<String, String> _fieldErrors = {};
  String? _saveError;

  final _retentionCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _patrolCtrl = TextEditingController();
  final _flutterCtrl = TextEditingController();
  final _dartCtrl = TextEditingController();
  final _xcrunCtrl = TextEditingController();

  bool _controllersSynced = false;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _retentionCtrl.dispose();
    _portCtrl.dispose();
    _patrolCtrl.dispose();
    _flutterCtrl.dispose();
    _dartCtrl.dispose();
    _xcrunCtrl.dispose();
    super.dispose();
  }

  AppSettings get _settings =>
      _draft ?? ref.read(settingsProvider).settings;

  void _syncControllers(AppSettings s) {
    void setIfChanged(TextEditingController c, String value) {
      if (c.text != value) {
        c.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }

    setIfChanged(_retentionCtrl, '${s.logRetentionCount}');
    setIfChanged(_portCtrl, '${s.devtoolsExtensionPort}');
    setIfChanged(_patrolCtrl, s.patrolPath);
    setIfChanged(_flutterCtrl, s.flutterPath);
    setIfChanged(_dartCtrl, s.dartPath);
    setIfChanged(_xcrunCtrl, s.xcrunPath);
    _controllersSynced = true;
  }

  void _scheduleSave(AppSettings next) {
    _draft = next;
    final errors = validateAppSettings(next);
    setState(() {
      _fieldErrors = {for (final e in errors) e.field: e.message};
      _saveError = null;
    });
    if (errors.isNotEmpty) return;

    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, () async {
      final draft = _draft;
      if (draft == null || !mounted) return;
      try {
        await ref.read(settingsProvider.notifier).update(draft);
        if (!mounted) return;
        setState(() {
          _draft = null;
          _saveError = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _saveError = e.toString());
      }
    });
  }

  void _patch(AppSettings Function(AppSettings) updater) {
    _scheduleSave(updater(_settings));
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final loaded = ref.watch(settingsProvider.select((s) => s.loaded));
    final persisted = ref.watch(settingsProvider.select((s) => s.settings));

    if (!loaded) {
      return const SizedBox(
        height: 36,
        child: Center(child: LinearProgressIndicator(minHeight: 2)),
      );
    }

    if (!_controllersSynced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controllersSynced) return;
        _syncControllers(persisted);
        setState(() {});
      });
    }

    final s = _draft ?? persisted;
    final collapsed = ref.watch(
      settingsProvider.select((st) => st.settings.controlDeckCollapsed),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // During panel resize or collapse animation, skip bento rows entirely
        // so dropdown/checkbox rows are never laid out at ~45-70px width.
        const contentMinWidth = 200.0;
        final showContent =
            !collapsed && constraints.maxWidth >= contentMinWidth;

        return Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    ref.read(settingsProvider.notifier).updatePartial({
                      'controlDeckCollapsed': !collapsed,
                    });
                  },
                  borderRadius: collapsed
                      ? BorderRadius.circular(10)
                      : const BorderRadius.vertical(top: Radius.circular(10)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'CONTROLS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                              color: p.text,
                            ),
                          ),
                        ),
                        Icon(
                          collapsed ? Icons.expand_more : Icons.expand_less,
                          size: 16,
                          color: p.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: showContent
                    ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_saveError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _saveError!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: PatrolColors.rose300,
                              ),
                            ),
                          ),
                        // Row 1: Logs | System
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _BentoTile(
                                  title: 'Logs',
                                  accent: PatrolColors.amber,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _CompactCheck(
                                        label:
                                            'Stop Test All on first failure',
                                        value: s.stopQueueOnFirstFailure,
                                        onChanged: (v) => _patch(
                                          (x) => x.copyWith(
                                            stopQueueOnFirstFailure: v,
                                          ),
                                        ),
                                      ),
                                      _CompactCheck(
                                        label: 'Auto-scroll',
                                        value: s.autoScrollLogs,
                                        onChanged: (v) => _patch(
                                          (x) =>
                                              x.copyWith(autoScrollLogs: v),
                                        ),
                                      ),
                                      _CompactCheck(
                                        label: 'Raw stderr',
                                        value: s.showRawStderr,
                                        onChanged: (v) => _patch(
                                          (x) =>
                                              x.copyWith(showRawStderr: v),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      _CompactField(
                                        label: 'Retention',
                                        controller: _retentionCtrl,
                                        error:
                                            _fieldErrors['logRetentionCount'],
                                        width: 56,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        onChanged: (v) {
                                          final parsed = parsePositiveInt(
                                            v,
                                            min: 10,
                                            max: 1000,
                                          );
                                          if (parsed != null) {
                                            _patch(
                                              (x) => x.copyWith(
                                                logRetentionCount: parsed,
                                              ),
                                            );
                                          } else {
                                            setState(() {
                                              _fieldErrors = {
                                                ..._fieldErrors,
                                                'logRetentionCount': '10-1000',
                                              };
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 6,
                                child: _BentoTile(
                                  title: 'System',
                                  accent: PatrolColors.violet400,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _LabeledDropdown<AppTheme>(
                                        label: 'Theme',
                                        value: s.theme,
                                        items: const [
                                          DropdownMenuItem(
                                            value: AppTheme.light,
                                            child: Text('Light'),
                                          ),
                                          DropdownMenuItem(
                                            value: AppTheme.dark,
                                            child: Text('Dark'),
                                          ),
                                          DropdownMenuItem(
                                            value: AppTheme.system,
                                            child: Text('System'),
                                          ),
                                        ],
                                        onChanged: (v) {
                                          if (v == null) return;
                                          final next =
                                              _settings.copyWith(theme: v);
                                          _draft = next;
                                          setState(() {});
                                          // Apply immediately so MaterialApp
                                          // themeMode updates without waiting
                                          // for the debounced save.
                                          ref
                                              .read(settingsProvider.notifier)
                                              .update(next)
                                              .then((_) {
                                            if (mounted) {
                                              setState(() => _draft = null);
                                            }
                                          });
                                        },
                                      ),
                                      _CompactCheck(
                                        label: 'DevTools extension',
                                        value: s.enableDevtoolsExtension,
                                        onChanged: (v) => _patch(
                                          (x) => x.copyWith(
                                            enableDevtoolsExtension: v,
                                          ),
                                        ),
                                      ),
                                      _CompactField(
                                        label: 'Port',
                                        controller: _portCtrl,
                                        error: _fieldErrors[
                                            'devtoolsExtensionPort'],
                                        width: 56,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        onChanged: (v) {
                                          final parsed = parsePositiveInt(
                                            v,
                                            min: 1024,
                                            max: 65535,
                                          );
                                          if (parsed != null) {
                                            _patch(
                                              (x) => x.copyWith(
                                                devtoolsExtensionPort: parsed,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      _CompactCheck(
                                        label: 'Confirm full suite',
                                        value: s.confirmBeforeRun,
                                        onChanged: (v) => _patch(
                                          (x) =>
                                              x.copyWith(confirmBeforeRun: v),
                                        ),
                                      ),
                                      _CompactCheck(
                                        label: 'Confirm clear history',
                                        value: s.confirmBeforeClearHistory,
                                        onChanged: (v) => _patch(
                                          (x) => x.copyWith(
                                            confirmBeforeClearHistory: v,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Row 2: CLI Paths - full width, 2×2 path grid
                        _BentoTile(
                          title: 'CLI paths',
                          accent: PatrolColors.orange400,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _PathField(
                                      label: 'Patrol',
                                      controller: _patrolCtrl,
                                      error: _fieldErrors['patrolPath'],
                                      onChanged: (v) => _patch(
                                        (x) => x.copyWith(patrolPath: v),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _PathField(
                                      label: 'Flutter',
                                      controller: _flutterCtrl,
                                      error: _fieldErrors['flutterPath'],
                                      onChanged: (v) => _patch(
                                        (x) => x.copyWith(flutterPath: v),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _PathField(
                                      label: 'Dart',
                                      controller: _dartCtrl,
                                      error: _fieldErrors['dartPath'],
                                      onChanged: (v) => _patch(
                                        (x) => x.copyWith(dartPath: v),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _PathField(
                                      label: 'xcrun',
                                      controller: _xcrunCtrl,
                                      error: _fieldErrors['xcrunPath'],
                                      onChanged: (v) => _patch(
                                        (x) => x.copyWith(xcrunPath: v),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.title,
    required this.accent,
    required this.child,
  });

  final String title;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  // Theme primary ink - never accent green/amber/violet/orange.
                  color: p.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: p.textSecondary),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 2,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              isExpanded: true,
              style: TextStyle(fontSize: 12, color: p.text),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactCheck extends StatelessWidget {
  const _CompactCheck({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: value,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 11, color: p.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactField extends StatelessWidget {
  const _CompactField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.error,
    this.width = 120,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? error;
  final double width;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: p.textSecondary),
          ),
        ),
        SizedBox(
          width: width,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              errorText: error,
              errorStyle: const TextStyle(fontSize: 9),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _PathField extends StatelessWidget {
  const _PathField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.error,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: p.textSecondary),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                errorText: error,
                errorStyle: const TextStyle(fontSize: 9),
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Browse $label',
            icon: const Icon(Icons.folder_open, size: 14),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                dialogTitle: 'Select $label executable',
              );
              final path = result?.files.single.path;
              if (path != null) {
                controller.text = path;
                onChanged(path);
              }
            },
          ),
        ],
      ),
    );
  }
}
