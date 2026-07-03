import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/hierarchy.dart';

const _runnerHost = 'localhost';

class XCTestClient {
  XCTestClient(this.port, {http.Client? client})
      : _client = client ?? http.Client();

  final int port;
  final http.Client _client;

  String _baseUrl(String path) => 'http://$_runnerHost:$port$path';

  Future<void> status() async {
    await _request('/status');
  }

  Future<XCTestDeviceInfo> deviceInfo() async {
    final json = await _requestJson('/deviceInfo');
    return XCTestDeviceInfo.fromJson(json);
  }

  Future<List<int>> screenshot({bool compressed = false}) async {
    final response = await _client
        .get(Uri.parse(_baseUrl('/screenshot?compressed=$compressed')))
        .timeout(const Duration(seconds: 30));
    _ensureOk('/screenshot', response);
    return response.bodyBytes;
  }

  Future<bool> isScreenStatic() async {
    final result = await _requestJson('/isScreenStatic');
    if (result is bool) return result;
    if (result is Map<String, dynamic>) {
      return result['isScreenStatic'] as bool? ?? false;
    }
    return false;
  }

  Future<void> tap(double x, double y, {double? duration}) async {
    final body = <String, dynamic>{'x': x, 'y': y};
    if (duration != null) body['duration'] = duration;
    await _post('/touch', body);
  }

  Future<void> swipe({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    double duration = 0.2,
  }) async {
    await _post('/swipeV2', {
      'startX': fromX,
      'startY': fromY,
      'endX': toX,
      'endY': toY,
      'duration': duration,
      'appIds': <String>[],
    });
  }

  Future<void> inputText(String text) async {
    await _post('/inputText', {'text': text, 'appIds': <String>[]});
  }

  Future<void> pressKey(String key) async {
    final normalized = _normalizeKey(key);
    await _post('/pressKey', {'key': normalized});
  }

  Future<void> pressButton(String name) async {
    await _post('/pressButton', {'button': name.toLowerCase()});
  }

  Future<HierarchyNode> viewHierarchy({String? appId}) async {
    final appIds = appId != null ? [appId] : <String>[];
    final response = await _postJson('/viewHierarchy', {
      'appIds': appIds,
      'excludeKeyboardElements': false,
    });
    return _normalizeHierarchyNode(response);
  }

  Future<String?> runningApp() async {
    final result = await _postJson('/runningApp', {'appIds': <String>[]});
    if (result is String) return result;
    if (result is Map<String, dynamic>) {
      return result['runningAppBundleId'] as String? ??
          result['bundleId'] as String? ??
          result['appId'] as String?;
    }
    return null;
  }

  Future<void> launchApp(String bundleId) async {
    await _post('/launchApp', {'bundleId': bundleId});
  }

  Future<void> terminateApp(String appId) async {
    await _post('/terminateApp', {'appId': appId});
  }

  Future<Map<String, dynamic>> keyboard() async {
    final result = await _postJson('/keyboard', {'appIds': <String>[]});
    if (result is Map<String, dynamic>) return result;
    return {};
  }

  Future<void> setOrientation(String orientation) async {
    await _post('/setOrientation', {'orientation': orientation});
  }

  Future<void> eraseText(int charactersToErase) async {
    await _post('/eraseText', {
      'charactersToErase': charactersToErase,
      'appIds': <String>[],
    });
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse(_baseUrl(path)),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    _ensureOk(path, response);
  }

  Future<dynamic> _postJson(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse(_baseUrl(path)),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    _ensureOk(path, response);
    return jsonDecode(response.body);
  }

  Future<dynamic> _requestJson(String path) async {
    final response = await _request(path);
    return jsonDecode(response.body);
  }

  Future<http.Response> _request(String path) async {
    final response = await _client
        .get(Uri.parse(_baseUrl(path)))
        .timeout(const Duration(seconds: 30));
    _ensureOk(path, response);
    return response;
  }

  void _ensureOk(String path, http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(
      'Simulator driver $path failed with HTTP ${response.statusCode}',
    );
  }

  String _normalizeKey(String key) {
    final normalized = key.trim().toLowerCase();
    return switch (normalized) {
      'backspace' || 'delete' => 'delete',
      'enter' || 'return' => 'return',
      'tab' => 'tab',
      'space' => 'space',
      'escape' || 'esc' => 'escape',
      _ => throw Exception(
          'The simulator driver does not support key "${key.trim()}" on iOS.',
        ),
    };
  }
}

HierarchyNode _normalizeHierarchyNode(dynamic value) {
  final map = value is Map<String, dynamic>
      ? value
      : <String, dynamic>{};
  final element = (map['axElement'] as Map<String, dynamic>?) ?? map;
  final frameRaw = element['frame'];
  final childrenRaw = element['children'] ?? map['children'];
  final children = childrenRaw is List
      ? childrenRaw
          .map((child) => _normalizeHierarchyNode(child))
          .toList()
      : <HierarchyNode>[];

  ElementFrame? frame;
  if (frameRaw is Map<String, dynamic>) {
    frame = ElementFrame(
      x: _frameNum(frameRaw, 'X', 'x'),
      y: _frameNum(frameRaw, 'Y', 'y'),
      width: _frameNum(frameRaw, 'Width', 'width'),
      height: _frameNum(frameRaw, 'Height', 'height'),
    );
  }

  final width = frame?.width ?? 0;
  final height = frame?.height ?? 0;

  return HierarchyNode(
    type: _elementType(element),
    label: element['label'] as String? ??
        element['title'] as String? ??
        element['value'] as String?,
    accessibilityId: element['accessibilityId'] as String? ??
        element['identifier'] as String?,
    value: element['value'] as String?,
    enabled: element['enabled'] as bool?,
    visible: frame != null ? width > 0 && height > 0 : null,
    frame: frame,
    children: children,
  );
}

double _frameNum(Map<String, dynamic> frame, String upper, String lower) {
  return (frame[upper] as num?)?.toDouble() ??
      (frame[lower] as num?)?.toDouble() ??
      0;
}

String? _elementType(Map<String, dynamic> element) {
  final type = element['type'] as String?;
  if (type != null) return type;
  final elementType = element['elementType'];
  if (elementType is int) return 'AX$elementType';
  return null;
}