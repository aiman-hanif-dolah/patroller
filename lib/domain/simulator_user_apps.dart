import '../models/hierarchy.dart';

/// Parses `xcrun simctl listapps <udid>` output for non-system bundle IDs.
List<String> parseSimulatorUserBundleIds(
  String listAppsOutput, {
  String? excludeBundleId,
}) {
  final re = RegExp(r'^\s{4}([A-Za-z0-9_.-]+)\s=\s\{', multiLine: true);
  return re
      .allMatches(listAppsOutput)
      .map((m) => m.group(1)!)
      .where(
        (id) => !id.startsWith('com.apple.') && id != excludeBundleId,
      )
      .toList();
}

bool isInspectableHierarchyEmpty(HierarchyNode node) {
  final children = node.children;
  return children == null || children.isEmpty;
}