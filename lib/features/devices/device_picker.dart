import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../models/models.dart';
import '../../providers/runner_provider.dart';
import '../../widgets/accessible_icon_button.dart';

class DevicePickerList extends ConsumerStatefulWidget {
  const DevicePickerList({super.key, this.onSelected});

  final VoidCallback? onSelected;

  @override
  ConsumerState<DevicePickerList> createState() => _DevicePickerListState();
}

class _DevicePickerListState extends ConsumerState<DevicePickerList> {
  @override
  void initState() {
    super.initState();
    // One-shot refresh so externally booted sims appear when picker opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(runnerProvider.notifier).refreshDevices(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final runner = ref.watch(
      runnerProvider.select(
        (s) => (devices: s.devices, selectedId: s.selectedDevice?.id),
      ),
    );
    final devices = runner.devices;

    if (devices.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No simulators found. Refresh to scan again.',
          style: TextStyle(fontSize: 12, color: p.textMuted),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return _DeviceRow(
          device: device,
          selected: runner.selectedId == device.id,
          onSelect: () {
            ref.read(runnerProvider.notifier).setSelectedDevice(device);
            widget.onSelected?.call();
          },
          onBoot: device.state == DeviceState.shutdown &&
                  isSelectableDevice(device)
              ? () => ref.read(runnerProvider.notifier).bootDevice(device.id)
              : null,
        );
      },
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.selected,
    required this.onSelect,
    this.onBoot,
  });

  final DeviceInfo device;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onBoot;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final selectable = isSelectableDevice(device);
    final reason = getDeviceUnavailableReason(device);

    return InkWell(
      onTap: selectable ? onSelect : null,
      child: Opacity(
        opacity: selectable ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: selected ? p.surfaceMuted : Colors.transparent,
          child: Row(
            children: [
              Icon(Icons.smartphone, size: 14, color: p.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: p.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      reason ?? device.type.name,
                      style: TextStyle(
                        fontSize: 10,
                        color: p.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onBoot != null)
                AccessibleIconButton(
                  icon: Icons.play_arrow,
                  label: 'Boot ${device.name}',
                  onPressed: onBoot,
                  size: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              if (selectable) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: device.state == DeviceState.booted
                        ? PatrolColors.psPassed
                        : device.state == DeviceState.shutdown
                            ? PatrolColors.psCancelled
                            : p.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  device.state?.name ?? 'unknown',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: p.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}