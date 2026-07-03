import '../models/hierarchy.dart';

const _axTypeNames = <int, String>{
  9: 'Button',
  21: 'NavigationBar',
  22: 'TabBar',
  37: 'SegmentedControl',
  40: 'Switch',
  42: 'Link',
  43: 'Image',
  44: 'Icon',
  45: 'SearchField',
  46: 'ScrollView',
  48: 'StaticText',
  49: 'TextField',
  50: 'SecureTextField',
  52: 'TextView',
  75: 'Cell',
};

const _interactiveTypes = {
  'Button',
  'Link',
  'Cell',
  'Switch',
  'SegmentedControl',
  'TextField',
  'SecureTextField',
  'SearchField',
  'TextView',
};

const _textTypes = {
  'StaticText',
  'TextField',
  'SecureTextField',
  'SearchField',
  'TextView',
};

String? normalizeElementType(String? type) {
  if (type == null) return null;
  final trimmed = type.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^AX(\d+)$').firstMatch(trimmed);
  if (match != null) {
    final code = int.tryParse(match.group(1)!);
    if (code != null && _axTypeNames.containsKey(code)) {
      return _axTypeNames[code];
    }
  }
  return trimmed;
}

double frameArea(ElementFrame? frame) {
  if (frame == null) return 0;
  return (frame.width < 0 ? 0 : frame.width) * (frame.height < 0 ? 0 : frame.height);
}

bool frameContainsPoint(ElementFrame? frame, double x, double y) {
  if (frame == null) return false;
  return x >= frame.x &&
      x <= frame.x + frame.width &&
      y >= frame.y &&
      y <= frame.y + frame.height;
}

String nodeText(HierarchyNode node) {
  return (node.label ?? node.value ?? node.accessibilityId ?? '').trim();
}

bool isInteractiveType(String? type) {
  final normalized = normalizeElementType(type);
  return normalized != null && _interactiveTypes.contains(normalized);
}

bool isTextType(String? type) {
  final normalized = normalizeElementType(type);
  return normalized != null && _textTypes.contains(normalized);
}

bool isVisibleWithFrame(HierarchyNode node) {
  return node.visible != false && frameArea(node.frame) > 0;
}

bool isMeaningfulNode(HierarchyNode node) {
  if (node.visible == false) return false;
  if (frameArea(node.frame) <= 0) return false;
  if (nodeText(node).isNotEmpty) return true;
  return isInteractiveType(node.type);
}

class NearestElementMatch {
  const NearestElementMatch({
    this.label,
    this.type,
    required this.frame,
  });

  final String? label;
  final String? type;
  final ElementFrame frame;
}

class _NearestCandidate {
  const _NearestCandidate({required this.node, required this.depth});

  final HierarchyNode node;
  final int depth;
}

void flattenHierarchy(
  HierarchyNode node,
  int depth,
  List<({HierarchyNode node, int depth})> out,
) {
  out.add((node: node, depth: depth));
  for (final child in node.children ?? const <HierarchyNode>[]) {
    flattenHierarchy(child, depth + 1, out);
  }
}

void _collectCandidatesAtPoint(
  HierarchyNode node,
  double x,
  double y,
  int depth,
  List<_NearestCandidate> out,
) {
  final frame = node.frame;
  if (frame != null &&
      frameArea(frame) > 0 &&
      node.visible != false &&
      frameContainsPoint(frame, x, y)) {
    out.add(_NearestCandidate(node: node, depth: depth));
  }
  for (final child in node.children ?? const <HierarchyNode>[]) {
    _collectCandidatesAtPoint(child, x, y, depth + 1, out);
  }
}

double _candidateScore(_NearestCandidate candidate) {
  var score = candidate.depth * 10.0;
  if (nodeText(candidate.node).isNotEmpty) score += 100;
  if (isInteractiveType(candidate.node.type)) score += 60;
  if (isTextType(candidate.node.type)) score += 30;
  final area = frameArea(candidate.node.frame);
  score -= (area > 0 ? (area.clamp(1, double.infinity) as double).toString().length : 1)
      .clamp(0, 9)
      .toDouble();
  return score;
}

NearestElementMatch? findNearestElement(HierarchyNode root, double x, double y) {
  final candidates = <_NearestCandidate>[];
  _collectCandidatesAtPoint(root, x, y, 0, candidates);
  if (candidates.isEmpty) return null;

  final meaningful = candidates.where((c) => isMeaningfulNode(c.node)).toList();
  final pool = meaningful.isNotEmpty ? meaningful : candidates;
  final best = pool.reduce(
    (current, next) => _candidateScore(next) > _candidateScore(current) ? next : current,
  );

  return NearestElementMatch(
    label: nodeText(best.node).isEmpty ? null : nodeText(best.node),
    type: normalizeElementType(best.node.type),
    frame: best.node.frame!,
  );
}

String nodeLabel(HierarchyNode node) {
  return node.label ??
      node.accessibilityId ??
      normalizeElementType(node.type) ??
      node.type ??
      'Element';
}