import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/hierarchy_analysis.dart';
import '../../models/models.dart';
import '../../providers/facade_provider.dart';
import '../../providers/inspector_provider.dart';
import '../../providers/preview_provider.dart';
import '../../providers/recording_provider.dart';
import '../../providers/runner_provider.dart';
import '../../providers/settings_provider.dart';

class HierarchyInspector extends ConsumerStatefulWidget {
  const HierarchyInspector({super.key});

  @override
  ConsumerState<HierarchyInspector> createState() => _HierarchyInspectorState();
}

class _HierarchyInspectorState extends ConsumerState<HierarchyInspector> {
  String _query = '';
  bool _showRaw = false;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final device = ref.read(runnerProvider).selectedDevice;
    if (device == null) return;

    ref.read(inspectorProvider.notifier).setLoading(true);

    try {
      final driverStatus =
          ref.read(patrolStudioFacadeProvider).simulator.driverStatus();
      if (driverStatus.state != DriverState.ready) {
        ref.read(inspectorProvider.notifier).setDriverUnavailable();
        ref.read(previewProvider.notifier).setHighlight(null);
        return;
      }

      final tree = await ref.read(patrolStudioFacadeProvider).simulator.viewHierarchy(
            device.id,
            null,
            device.type,
          );
      if (!mounted) return;
      ref.read(inspectorProvider.notifier).setHierarchy(tree);
      _syncHighlight(tree);
    } catch (e) {
      if (!mounted) return;
      ref.read(inspectorProvider.notifier).setError(
            e.toString().replaceFirst('Exception: ', ''),
          );
    } finally {
      if (mounted) {
        ref.read(inspectorProvider.notifier).setLoading(false);
      }
    }
  }

  void _syncHighlight(HierarchyNode? node) {
    ref.read(previewProvider.notifier).setHighlight(node?.frame);
  }

  void _setupPolling() {
    _pollTimer?.cancel();
    final device = ref.read(runnerProvider).selectedDevice;
    final settings = ref.read(settingsProvider).settings;
    if (device == null) return;
    _pollTimer = Timer.periodic(
      Duration(milliseconds: settings.hierarchyPollIntervalMs),
      (_) => _refresh(),
    );
  }

  Future<void> _tapSelected() async {
    final device = ref.read(runnerProvider).selectedDevice;
    final node = ref.read(inspectorProvider).selectedNode;
    if (device == null || node?.frame == null) return;

    await ref.read(patrolStudioFacadeProvider).simulator.tapElement(
          device.id,
          node!.frame!,
          device.type,
        );
    ref.read(previewProvider.notifier).burst();

    var scaleX = 1.0;
    var scaleY = 1.0;
    try {
      final info = await ref.read(patrolStudioFacadeProvider).simulator.deviceInfo(
            device.id,
            device.type,
          );
      if (info.widthPixels != 0 && info.widthPoints != 0) {
        scaleX = info.widthPixels / info.widthPoints;
      }
      if (info.heightPixels != 0 && info.heightPoints != 0) {
        scaleY = info.heightPixels / info.heightPoints;
      } else {
        scaleY = scaleX;
      }
    } catch (_) {}

    final frame = node.frame!;
    ref.read(recordingProvider.notifier).recordAction(
          RecordingActionType.tap,
          x: ((frame.x + frame.width / 2) * scaleX).roundToDouble(),
          y: ((frame.y + frame.height / 2) * scaleY).roundToDouble(),
          targetLabel: nodeText(node).isEmpty ? null : nodeText(node),
          targetType: normalizeElementType(node.type),
          targetFrame: frame,
        );
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(runnerProvider).selectedDevice;
    final inspector = ref.watch(inspectorProvider);
    ref.watch(settingsProvider.select((s) => s.settings.hierarchyPollIntervalMs));

    ref.listen(runnerProvider.select((s) => s.selectedDevice?.id), (prev, next) {
      if (prev != next) {
        ref.read(inspectorProvider.notifier).reset();
        ref.read(previewProvider.notifier).setHighlight(null);
        _query = '';
        _refresh();
        _setupPolling();
      }
    });

    if (_pollTimer == null && device != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refresh();
        _setupPolling();
      });
    }

    ref.listen(inspectorProvider.select((s) => s.selectedNode), (prev, next) {
      _syncHighlight(next);
    });

    final nodes = inspector.hierarchy != null
        ? () {
            final flat = <({HierarchyNode node, int depth})>[];
            flattenHierarchy(inspector.hierarchy!, 0, flat);
            return flat;
          }()
        : <({HierarchyNode node, int depth})>[];

    final orderedNodes = _showRaw
        ? nodes
        : [...nodes]
          ..sort(
            (a, b) => (isMeaningfulNode(b.node) ? 1 : 0) -
                (isMeaningfulNode(a.node) ? 1 : 0),
          );

    final trimmedQuery = _query.trim();
    final filteredNodes = trimmedQuery.isEmpty
        ? orderedNodes
        : orderedNodes.where((entry) {
            final text =
                '${nodeLabel(entry.node)} ${entry.node.value ?? ''}'.toLowerCase();
            return text.contains(trimmedQuery.toLowerCase());
          }).toList();

    final selectedInResults = inspector.selectedNode != null &&
        filteredNodes.any((e) => identical(e.node, inspector.selectedNode));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(fontSize: 12, color: PatrolColors.ink),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: const TextStyle(color: PatrolColors.steel),
                        prefixIcon: const Icon(Icons.search, size: 14, color: PatrolColors.steel),
                        suffixIcon: trimmedQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 14),
                                onPressed: () => setState(() => _query = ''),
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        filled: true,
                        fillColor: PatrolColors.fog,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: PatrolColors.pebble),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _showRaw = !_showRaw),
                    style: TextButton.styleFrom(
                      foregroundColor: _showRaw ? PatrolColors.ink : PatrolColors.steel,
                      backgroundColor: _showRaw ? PatrolColors.fog : Colors.transparent,
                    ),
                    child: const Text('Raw', style: TextStyle(fontSize: 12)),
                  ),
                  IconButton(
                    onPressed: inspector.loading ? null : _refresh,
                    icon: Icon(
                      Icons.refresh,
                      size: 16,
                      color: PatrolColors.steel,
                    ),
                  ),
                ],
              ),
              if (inspector.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    inspector.error!,
                    style: const TextStyle(fontSize: 11, color: PatrolColors.red400),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: PatrolColors.pebble),
        Expanded(child: _buildBody(device, inspector, filteredNodes, trimmedQuery, selectedInResults)),
        if (inspector.selectedNode != null && selectedInResults) ...[
          const Divider(height: 1, color: PatrolColors.pebble),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  nodeLabel(inspector.selectedNode!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PatrolColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                if (inspector.selectedNode!.type != null)
                  Text(
                    'Type: ${normalizeElementType(inspector.selectedNode!.type) ?? inspector.selectedNode!.type}',
                    style: const TextStyle(fontSize: 10, color: PatrolColors.steel),
                  ),
                if (inspector.selectedNode!.accessibilityId != null)
                  Text(
                    'ID: ${inspector.selectedNode!.accessibilityId}',
                    style: const TextStyle(fontSize: 10, color: PatrolColors.steel),
                  ),
                if (inspector.selectedNode!.value != null)
                  Text(
                    'Value: ${inspector.selectedNode!.value}',
                    style: const TextStyle(fontSize: 10, color: PatrolColors.steel),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: inspector.selectedNode!.frame == null ? null : _tapSelected,
                  style: FilledButton.styleFrom(
                    backgroundColor: PatrolColors.ember,
                    foregroundColor: PatrolColors.obsidian,
                  ),
                  child: const Text('Tap selected element'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBody(
    DeviceInfo? device,
    InspectorState inspector,
    List<({HierarchyNode node, int depth})> filteredNodes,
    String trimmedQuery,
    bool selectedInResults,
  ) {
    if (device == null) {
      return const Center(
        child: Text(
          'Select a booted iOS Simulator.',
          style: TextStyle(fontSize: 12, color: PatrolColors.steel),
        ),
      );
    }

    if (inspector.driverUnavailable) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Simulator driver is unavailable. Boot the simulator or check Health.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: PatrolColors.steel),
          ),
        ),
      );
    }

    if (inspector.loading && inspector.hierarchy == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (inspector.hierarchy == null && inspector.error == null) {
      return const Center(
        child: Text(
          'No hierarchy loaded.',
          style: TextStyle(fontSize: 12, color: PatrolColors.steel),
        ),
      );
    }

    if (inspector.hierarchy != null &&
        (inspector.hierarchy!.children?.isEmpty ?? true)) {
      return const Center(
        child: Text(
          'Hierarchy is empty.',
          style: TextStyle(fontSize: 12, color: PatrolColors.steel),
        ),
      );
    }

    if (trimmedQuery.isNotEmpty && filteredNodes.isEmpty) {
      return const Center(
        child: Text(
          'No matching elements',
          style: TextStyle(fontSize: 12, color: PatrolColors.steel),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredNodes.length,
      itemBuilder: (context, index) {
        final entry = filteredNodes[index];
        final node = entry.node;
        final meaningful = isMeaningfulNode(node);
        final selected = identical(inspector.selectedNode, node);
        return Material(
          color: selected
              ? PatrolColors.pebble.withValues(alpha: 0.6)
              : Colors.transparent,
          child: InkWell(
            onTap: () => ref.read(inspectorProvider.notifier).selectNode(node),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                _showRaw ? 12.0 + entry.depth * 12 : 12,
                8,
                12,
                8,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: PatrolColors.pebble),
                ),
              ),
              child: Opacity(
                opacity: meaningful || _showRaw ? 1 : 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nodeLabel(node),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PatrolColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (normalizeElementType(node.type) != null)
                          Text(
                            normalizeElementType(node.type)!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: PatrolColors.steel,
                            ),
                          ),
                        if (node.frame != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${node.frame!.x.round()}, ${node.frame!.y.round()} · ${node.frame!.width.round()} x ${node.frame!.height.round()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: PatrolColors.steel,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}