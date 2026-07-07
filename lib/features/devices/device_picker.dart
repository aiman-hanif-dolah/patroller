import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../models/models.dart';
import '../../providers/runner_provider.dart';
import '../../widgets/accessible_icon_button.dart';

class DevicePickerList extends ConsumerWidget {
  const DevicePickerList({super.key, this.onSelected});

  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runner = ref.watch(runnerProvider);
    final devices = runner.devices;

    if (devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No simulators found.',
              style: TextStyle(fontSize: 12, color: PatrolColors.steel),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  ref.read(runnerProvider.notifier).refreshDevices(),
              icon: const Icon(Icons.refresh, size: 12),
              label: const Text('Refresh'),
            ),
          ],
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
          selected: runner.selectedDevice?.id == device.id,
          onSelect: () {
            ref.read(runnerProvider.notifier).setSelectedDevice(device);
            onSelected?.call();
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
    final selectable = isSelectableDevice(device);
    final reason = getDeviceUnavailableReason(device);

    return InkWell(
      onTap: selectable ? onSelect : null,
      child: Opacity(
        opacity: selectable ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: selected ? PatrolColors.fog : Colors.transparent,
          child: Row(
            children: [
              const Icon(Icons.smartphone, size: 14, color: PatrolColors.steel),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: PatrolColors.ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      reason ?? device.type.name,
                      style: const TextStyle(
                        fontSize: 10,
                        color: PatrolColors.steel,
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
              if (selectable)
                Text(
                  device.state?.name ?? 'unknown',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: device.state == DeviceState.booted
                        ? PatrolColors.psPassed
                        : device.state == DeviceState.shutdown
                            ? PatrolColors.psCancelled
                            : PatrolColors.steel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}