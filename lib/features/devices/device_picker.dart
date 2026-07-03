import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../models/models.dart';
import '../../providers/runner_provider.dart';

class DevicePickerMenu extends ConsumerWidget {
  const DevicePickerMenu({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runner = ref.watch(runnerProvider);
    final devices = runner.devices;

    return Material(
      elevation: 8,
      color: PatrolColors.mist,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 280,
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PatrolColors.pebble),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select simulator',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PatrolColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        ref.read(runnerProvider.notifier).refreshDevices(),
                    icon: const Icon(Icons.refresh, size: 14),
                    tooltip: 'Refresh devices',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: PatrolColors.pebble),
            Flexible(
              child: devices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No devices found',
                        style: TextStyle(
                          fontSize: 12,
                          color: PatrolColors.steel,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return _DeviceRow(
                          device: device,
                          selected: runner.selectedDevice?.id == device.id,
                          onSelect: () {
                            ref
                                .read(runnerProvider.notifier)
                                .setSelectedDevice(device);
                            onClose();
                          },
                          onBoot: device.state == DeviceState.shutdown &&
                              isSelectableDevice(device)
                              ? () => ref
                                  .read(runnerProvider.notifier)
                                  .bootSimulator()
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
                IconButton(
                  onPressed: onBoot,
                  icon: const Icon(Icons.play_arrow, size: 14),
                  tooltip: 'Boot simulator',
                  visualDensity: VisualDensity.compact,
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