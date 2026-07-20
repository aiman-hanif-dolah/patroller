import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/models.dart';
import '../../providers/runner_provider.dart';
import 'device_picker.dart';

/// Clickable device chip for the toolbar / status strip.
/// Opens a popover with [DevicePickerList] so users can always pick a simulator.
class DeviceSelectorButton extends ConsumerWidget {
  const DeviceSelectorButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PatrolPalette.of(context);
    final device = ref.watch(runnerProvider.select((s) => s.selectedDevice));
    final hasDevice = device != null;
    final booted = device?.state == DeviceState.booted;
    // Status color lives on the adjacent PatrolStatusDot - keep label/icon white.
    final labelColor = hasDevice ? p.text : PatrolColors.ember;

    return Tooltip(
      message: hasDevice
          ? '${device.name} · ${device.state?.name ?? 'unknown'} - click to change'
          : 'No simulator selected - click to pick one',
      child: Material(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(PatrolRadius.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(PatrolRadius.chip),
          onTap: () => _openPicker(context, ref),
          child: Container(
            height: compact ? 28 : 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PatrolRadius.chip),
              border: Border.all(color: p.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_iphone_rounded, size: 14, color: labelColor),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    hasDevice
                        ? (booted
                            ? device.name
                            : '${device.name} (boot)')
                        : 'Select simulator',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 16, color: labelColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final p = PatrolPalette.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final offset =
        box?.localToGlobal(Offset.zero, ancestor: overlay) ?? Offset.zero;
    final size = box?.size ?? Size.zero;

    // Fire-and-forget refresh so menu opens immediately.
    unawaited(ref.read(runnerProvider.notifier).refreshDevices(silent: true));

    if (!context.mounted) return;

    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + 320,
        offset.dy,
      ),
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.border),
      ),
      constraints: const BoxConstraints(minWidth: 300, maxWidth: 340, maxHeight: 360),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 320,
            height: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                  child: Row(
                    children: [
                      Text(
                        'iOS Simulators',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          ref.read(runnerProvider.notifier).refreshDevices();
                        },
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: PatrolColors.sky400,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: p.border),
                Expanded(
                  child: DevicePickerList(
                    onSelected: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact label used in the workflow status strip (still opens picker).
class DeviceStatusChip extends ConsumerWidget {
  const DeviceStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PatrolPalette.of(context);
    final device = ref.watch(runnerProvider.select((s) => s.selectedDevice));
    final missing = device == null;
    final label = missing
        ? 'No device'
        : device.state == DeviceState.booted
            ? device.name
            : '${device.name} (boot)';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          // Reuse the same menu via a temporary overlay anchor.
          final messenger = ScaffoldMessenger.maybeOf(context);
          await ref.read(runnerProvider.notifier).refreshDevices(silent: true);
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: p.surface,
              title: const Text(
                'Select iOS Simulator',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 360,
                height: 320,
                child: DevicePickerList(
                  onSelected: () => Navigator.of(ctx).pop(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(runnerProvider.notifier).refreshDevices();
                  },
                  child: const Text('Refresh'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
          messenger; // keep analyzer quiet if unused
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_iphone_outlined,
                size: 12,
                color: missing ? PatrolColors.ember : p.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                'Device: $label',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: missing ? PatrolColors.ember : p.text,
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 14, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
