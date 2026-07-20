import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path/path.dart' as p;

import '../models/enums.dart';
import '../models/recording.dart';
import '../models/run_record.dart';
import '../services/patrol_studio_facade.dart';

/// Local HTTP + WebSocket server that lets external tooling (the Patroller
/// DevTools extension panel, the DevTools sidecar, or any client) drive
/// Patroller's capabilities: runs, devices, inspector tree, and recording.
class PatrollerExtensionServer {
  PatrollerExtensionServer({
    required this.facade,
    this.port = 8771,
    this.address = '127.0.0.1',
  });

  final PatrolStudioFacade facade;
  final int port;
  final String address;

  HttpServer? _server;
  final _clients = <WebSocketChannel>{};
  final _subs = <StreamSubscription<dynamic>>[];

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    final router = Router()
      ..get('/health', _health)
      ..get('/devices', _devices)
      ..post('/devices/boot', _bootDevice)
      ..post('/devices/shutdown', _shutdownDevice)
      ..get('/runs', _listRuns)
      ..post('/runs', _startRun)
      ..post('/runs/<runId>/stop', _stopRun)
      ..get('/driver/status', _driverStatus)
      ..post('/driver/ensure', _ensureDriver)
      ..post('/driver/repair', _repairDriver)
      ..post('/driver/stop', _stopDriver)
      ..get('/inspector/hierarchy', _hierarchy)
      ..get('/recordings', _listRecordings)
      ..post('/recordings', _saveRecording)
      ..post('/recordings/<id>/replay', _replayRecording);

    // shelf_web_socket 2.x+ passes WebSocketChannel (not dart:io WebSocket).
    final wsHandler = webSocketHandler((WebSocketChannel channel, _) {
      _clients.add(channel);
      channel.stream.listen(
        (event) {
          channel.sink.add(jsonEncode({'type': 'ack', 'payload': event}));
        },
        onDone: () => _clients.remove(channel),
        onError: (_) => _clients.remove(channel),
      );
    });

    final panelDir = _resolvePanelBuildDir();
    final panelStatic = panelDir != null
        ? createStaticHandler(panelDir, defaultDocument: 'index.html')
        : null;

    final cascade = Cascade()
        .add((req) {
          if (req.url.path == 'ws') return wsHandler(req);
          if (panelStatic != null &&
              (req.url.path == 'panel' || req.url.path.startsWith('panel/'))) {
            return _servePanel(req, panelStatic);
          }
          return router.call(req);
        })
        .add(router.call);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(cascade.handler);

    _server = await shelf_io.serve(handler, address, port);
    _bridgeStreams();
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final c in _clients) {
      await c.sink.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  void _bridgeStreams() {
    _subs.add(
      facade.runner.onStatus().listen(
        (u) => _broadcast({'type': 'runStatus', 'payload': u.toJson()}),
      ),
    );
    _subs.add(
      facade.runner.onLog().listen(
        (e) => _broadcast({'type': 'log', 'payload': e.toJson()}),
      ),
    );
    _subs.add(
      facade.externalRecording.onAction().listen(
        (a) => _broadcast({'type': 'recordingAction', 'payload': a.toJson()}),
      ),
    );
  }

  void _broadcast(Map<String, dynamic> message) {
    final text = jsonEncode(message);
    for (final c in _clients) {
      c.sink.add(text);
    }
  }

  // ── handlers ─────────────────────────────────────────────────────────────

  Future<Response> _health(Request req) async {
    return _json({'status': 'ok', 'server': 'patroller-extension'});
  }

  Future<Response> _devices(Request req) async {
    final devices = await facade.devices.list();
    return _json(devices.map((d) => d.toJson()).toList());
  }

  Future<Response> _bootDevice(Request req) async {
    final body = await _body(req);
    final udid = body['udid'] as String? ?? '';
    if (udid.isEmpty) return _bad('udid required');
    final name = await facade.devices.boot(udid);
    return _json({'name': name});
  }

  Future<Response> _shutdownDevice(Request req) async {
    final body = await _body(req);
    final udid = body['udid'] as String? ?? '';
    if (udid.isEmpty) return _bad('udid required');
    final name = await facade.devices.shutdown(udid);
    return _json({'name': name});
  }

  Future<Response> _listRuns(Request req) async {
    final state = await facade.runner.getActiveSession();
    return _json(state.toJson());
  }

  Future<Response> _startRun(Request req) async {
    final body = await _body(req);
    final config = RunConfig.fromJson(body);
    final record = await facade.runner.start(config);
    return _json(record.toJson());
  }

  Future<Response> _stopRun(Request req, String runId) async {
    final result = await facade.runner.stop(runId);
    return _json(result.toJson());
  }

  Future<Response> _driverStatus(Request req) async {
    return _json(facade.simulator.driverStatus().toJson());
  }

  Future<Response> _ensureDriver(Request req) async {
    final body = await _body(req);
    final status = await facade.simulator.ensureDriver(
      udid: body['udid'] as String,
      deviceType: DeviceType.fromJson(body['deviceType'] as String? ?? 'iOS Simulator'),
    );
    return _json(status.toJson());
  }

  Future<Response> _repairDriver(Request req) async {
    final body = await _body(req);
    final status = await facade.simulator.repairDriver(
      udid: body['udid'] as String,
      deviceType: DeviceType.fromJson(body['deviceType'] as String? ?? 'iOS Simulator'),
    );
    return _json(status.toJson());
  }

  Future<Response> _stopDriver(Request req) async {
    facade.simulator.stopDriver();
    return _json({'status': 'stopped'});
  }

  Future<Response> _hierarchy(Request req) async {
    final udid = req.url.queryParameters['udid'] ?? '';
    final appId = req.url.queryParameters['appId'];
    final deviceType = DeviceType.fromJson(
      req.url.queryParameters['deviceType'] ?? 'iOS Simulator',
    );
    if (udid.isEmpty) return _bad('udid required');
    final node = await facade.simulator.viewHierarchy(udid, appId, deviceType);
    return _json(node.toJson());
  }

  Future<Response> _listRecordings(Request req) async {
    final projectPath = req.url.queryParameters['projectPath'] ?? '';
    final recordings = await facade.recordings.getAll(projectPath);
    return _json(recordings.map((r) => r.toJson()).toList());
  }

  Future<Response> _saveRecording(Request req) async {
    final body = await _body(req);
    final draft = RecordingDraft.fromJson(body);
    final recording = await facade.recordings.save(draft);
    return _json(recording.toJson());
  }

  Future<Response> _replayRecording(Request req, String id) async {
    final body = await _body(req);
    final projectPath = body['projectPath'] as String? ?? '';
    final udid = body['udid'] as String? ?? '';
    final deviceType = DeviceType.fromJson(
      body['deviceType'] as String? ?? 'iOS Simulator',
    );
    final result = await facade.recordings.replay(
      id,
      projectPath,
      udid,
      deviceType,
    );
    return _json(result.toJson());
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Serves the built extension under `/panel`, rewriting `<base href="/">`
  /// to `/panel/` so assets resolve correctly. The build ships with `/` so
  /// Flutter DevTools can rewrite base href when loading as a package
  /// extension (DDS only rewrites the exact `/` value).
  Future<Response> _servePanel(Request req, Handler panelStatic) async {
    final stripped = req.url.path.replaceFirst(RegExp(r'^panel/?'), '');
    final rewritten = stripped.isEmpty ? '/' : '/$stripped';
    final host = req.headers['host'] ?? 'localhost';
    final inner = Request(
      req.method,
      Uri.parse('http://$host$rewritten'),
      headers: req.headers,
      body: req.read(),
      context: req.context,
    );
    final response = await panelStatic(inner);
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('text/html')) return response;
    final body = await response.readAsString();
    final updated = body.replaceFirst(
      RegExp(r'<base href="\/"\s?\/?>'),
      '<base href="/panel/">',
    );
    return response.change(body: updated);
  }

  /// Locates the built DevTools web panel so it can be served at `/panel`.
  String? _resolvePanelBuildDir() {
    final candidates = [
      p.join(
        p.dirname(Platform.resolvedExecutable),
        '..',
        'Resources',
        'patroller-devtools-panel',
      ),
      p.join(Directory.current.path, 'extension', 'devtools', 'build'),
      p.join(
        Directory.current.path,
        '..',
        'extension',
        'devtools',
        'build',
      ),
    ];
    for (final candidate in candidates) {
      final dir = Directory(p.normalize(candidate));
      if (dir.existsSync() && File(p.join(dir.path, 'index.html')).existsSync()) {
        return dir.path;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _body(Request req) async {
    final text = await req.readAsString();
    if (text.isEmpty) return <String, dynamic>{};
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Response _json(Object body) =>
      Response.ok(jsonEncode(body), headers: _cors());

  Response _bad(String message) =>
      Response.badRequest(body: jsonEncode({'error': message}), headers: _cors());

  Map<String, String> _cors() => {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      };
}
