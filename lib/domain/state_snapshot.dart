import '../models/hierarchy.dart';
import '../models/recording.dart';
import 'hierarchy_analysis.dart';

const _maxVisibleTexts = 8;
const _maxPrimaryActions = 6;
const _maxRawPreviewLines = 15;

bool isStableTextAnchor(String text) {
  final trimmed = text.trim();
  if (trimmed.length < 2 || trimmed.length > 60) return false;
  if (RegExp(r'^[\d\s.,:%/-]+$').hasMatch(trimmed)) return false;
  if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(trimmed)) return false;
  return true;
}

List<String> deriveVisibleTexts(HierarchyNode root) {
  final flat = <({HierarchyNode node, int depth})>[];
  flattenHierarchy(root, 0, flat);
  final seen = <String>{};
  final texts = <String>[];
  for (final entry in flat) {
    final node = entry.node;
    if (!isVisibleWithFrame(node)) continue;
    if (!isTextType(node.type) && node.label == null) continue;
    final text = nodeText(node);
    if (!isStableTextAnchor(text) || seen.contains(text)) continue;
    seen.add(text);
    texts.add(text);
    if (texts.length >= _maxVisibleTexts) break;
  }
  return texts;
}

List<String> derivePrimaryActions(HierarchyNode root) {
  final flat = <({HierarchyNode node, int depth})>[];
  flattenHierarchy(root, 0, flat);
  final seen = <String>{};
  final actions = <String>[];
  for (final entry in flat) {
    final node = entry.node;
    if (!isVisibleWithFrame(node) || !isInteractiveType(node.type)) continue;
    final text = nodeText(node);
    if (text.isEmpty || seen.contains(text)) continue;
    seen.add(text);
    actions.add(text);
    if (actions.length >= _maxPrimaryActions) break;
  }
  return actions;
}

String? deriveTitle(HierarchyNode root) {
  final flat = <({HierarchyNode node, int depth})>[];
  flattenHierarchy(root, 0, flat);
  final navBar = flat
      .where((e) => normalizeElementType(e.node.type) == 'NavigationBar')
      .firstOrNull;
  if (navBar != null) {
    final navText = nodeText(navBar.node);
    if (navText.isNotEmpty) return navText;
    final navFlat = <({HierarchyNode node, int depth})>[];
    flattenHierarchy(navBar.node, 0, navFlat);
    final child = navFlat
        .where((e) => nodeText(e.node).isNotEmpty && e.node != navBar.node)
        .firstOrNull;
    if (child != null) return nodeText(child.node);
  }
  final firstText = flat
      .where(
        (e) =>
            isVisibleWithFrame(e.node) &&
            isTextType(e.node.type) &&
            isStableTextAnchor(nodeText(e.node)),
      )
      .firstOrNull;
  return firstText != null ? nodeText(firstText.node) : null;
}

String? deriveSelectedTab(HierarchyNode root) {
  final flat = <({HierarchyNode node, int depth})>[];
  flattenHierarchy(root, 0, flat);
  final tabBar = flat
      .where((e) => normalizeElementType(e.node.type) == 'TabBar')
      .firstOrNull;
  if (tabBar == null) return null;
  final tabFlat = <({HierarchyNode node, int depth})>[];
  flattenHierarchy(tabBar.node, 0, tabFlat);
  final selected = tabFlat.where((e) {
    return normalizeElementType(e.node.type) == 'Button' &&
        nodeText(e.node).isNotEmpty &&
        '${e.node.value ?? ''}' == '1';
  }).firstOrNull;
  return selected != null ? nodeText(selected.node) : null;
}

String computeScreenFingerprint(HierarchyNode root) {
  final flat = <({HierarchyNode node, int depth})>[];
  flattenHierarchy(root, 0, flat);
  final parts = <String>[];
  for (final entry in flat) {
    final node = entry.node;
    if (!isVisibleWithFrame(node)) continue;
    final text = nodeText(node);
    final type = normalizeElementType(node.type) ?? '';
    if (text.isEmpty && !isInteractiveType(node.type)) continue;
    parts.add('${entry.depth}:$type:$text');
  }
  final material = parts.join('|');
  var hash = 2166136261;
  for (final codeUnit in material.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 16777619) & 0xFFFFFFFF;
  }
  return '${hash.toRadixString(16)}-${parts.length.toRadixString(16)}';
}

String buildRawHierarchyPreview(HierarchyNode root) {
  final flat = <({HierarchyNode node, int depth})>[];
  flattenHierarchy(root, 0, flat);
  final lines = <String>[];
  for (final entry in flat) {
    if (lines.length >= _maxRawPreviewLines) break;
    final node = entry.node;
    final type = normalizeElementType(node.type) ?? 'Element';
    final text = nodeText(node);
    final frame = node.frame;
    final frameText = frame != null
        ? ' (${frame.x.round()},${frame.y.round()} ${frame.width.round()}x${frame.height.round()})'
        : '';
    final indent = '  ' * entry.depth.clamp(0, 8);
    lines.add('$indent$type${text.isEmpty ? '' : ' "$text"'}${frameText}');
  }
  return lines.join('\n');
}

RecordingStateSnapshot deriveStateSnapshot(
  HierarchyNode root,
  String id,
  int timestampMs,
) {
  return RecordingStateSnapshot(
    id: id,
    timestampMs: timestampMs,
    screenFingerprint: computeScreenFingerprint(root),
    visibleTexts: deriveVisibleTexts(root),
    primaryActions: derivePrimaryActions(root),
    selectedTab: deriveSelectedTab(root),
    title: deriveTitle(root),
    rawHierarchyPreview: buildRawHierarchyPreview(root),
  );
}

String summarizeSnapshot(RecordingStateSnapshot snapshot) {
  final parts = <String>[];
  if (snapshot.title != null && snapshot.title!.isNotEmpty) {
    parts.add(snapshot.title!);
  }
  if (snapshot.selectedTab != null && snapshot.selectedTab!.isNotEmpty) {
    parts.add('tab ${snapshot.selectedTab}');
  }
  if (parts.isEmpty && snapshot.visibleTexts.isNotEmpty) {
    parts.add(snapshot.visibleTexts.first);
  }
  return parts.join(' · ');
}