import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

const String kDefaultPatrollerUrl = String.fromEnvironment(
  'PATROLLER_URL',
  defaultValue: 'http://localhost:8771',
);

class PatrollerClient {
  PatrollerClient(this.baseUrl);
  String baseUrl;

  Future<http.Response> get(String path) =>
      http.get(Uri.parse('$baseUrl$path'));

  Future<http.Response> post(String path, [Map<String, dynamic>? body]) =>
      http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      );

  void connectWs(void Function(Map<String, dynamic>) onMessage) {
    final httpUri = Uri.parse('$baseUrl/ws');
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final channel = WebSocketChannel.connect(httpUri.replace(scheme: wsScheme));
    channel.stream.listen((m) {
      try {
        onMessage(jsonDecode(m.toString()) as Map<String, dynamic>);
      } catch (_) {}
    });
  }
}

class PatrollerPanel extends StatefulWidget {
  const PatrollerPanel({super.key, this.serverUrl});

  /// Override the Patroller extension server URL (tests / custom embeds).
  final String? serverUrl;

  @override
  State<PatrollerPanel> createState() => _PatrollerPanelState();
}

class _PatrollerPanelState extends State<PatrollerPanel> {
  late PatrollerClient _client;
  bool _connected = false;
  late String _serverUrl;
  Timer? _reconnectTimer;

  List<dynamic> _devices = [];
  Map<String, dynamic>? _driver;
  List<dynamic> _recordings = [];
  final List<String> _logs = [];
  String _projectPath = '';
  Map<String, dynamic>? _hierarchy;

  @override
  void initState() {
    super.initState();
    _serverUrl = widget.serverUrl ?? kDefaultPatrollerUrl;
    _client = PatrollerClient(_serverUrl);
    _connect();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void _rebuildClient() {
    _client = PatrollerClient(_serverUrl);
  }

  Future<void> _connect() async {
    try {
      final health = await _client.get('/health');
      if (health.statusCode != 200) {
        throw StateError('health ${health.statusCode}');
      }
      _client.connectWs(_onWs);
      if (mounted) setState(() => _connected = true);
      await _refreshAll();
    } catch (_) {
      if (mounted) setState(() => _connected = false);
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (!_connected && mounted) _connect();
      });
    }
  }

  void _onWs(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    if (type == 'log') {
      final p = data['payload'] as Map<String, dynamic>;
      setState(() {
        _logs.add('${p['source'] ?? ''}: ${p['text'] ?? ''}');
        if (_logs.length > 300) _logs.removeAt(0);
      });
    } else if (type == 'runStatus' || type == 'recordingAction') {
      _loadDriver();
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadDevices(), _loadDriver(), _loadRecordings()]);
  }

  Future<void> _loadDevices() async {
    try {
      final res = await _client.get('/devices');
      setState(() => _devices = jsonDecode(res.body) as List<dynamic>);
    } catch (_) {}
  }

  Future<void> _loadDriver() async {
    try {
      final res = await _client.get('/driver/status');
      setState(() => _driver = jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _loadRecordings() async {
    try {
      final res = await _client
          .get('/recordings?projectPath=${Uri.encodeComponent(_projectPath)}');
      setState(() => _recordings = jsonDecode(res.body) as List<dynamic>);
    } catch (_) {}
  }

  Future<void> _boot(String udid) async {
    await _client.post('/devices/boot', {'udid': udid});
    await _loadDevices();
  }

  Future<void> _shutdown(String udid) async {
    await _client.post('/devices/shutdown', {'udid': udid});
    await _loadDevices();
  }

  Future<void> _ensureDriver(String udid) async {
    await _client.post('/driver/ensure', {
      'udid': udid,
      'deviceType': 'iOS Simulator',
    });
    await _loadDriver();
  }

  Future<void> _inspect(String udid) async {
    final res = await _client.get(
      '/inspector/hierarchy?udid=$udid&deviceType=${Uri.encodeComponent('iOS Simulator')}',
    );
    if (!mounted) return;
    setState(() => _hierarchy = jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> _startRun() async {
    if (_projectPath.trim().isEmpty) return;
    await _client.post('/runs', {
      'projectPath': _projectPath,
      'runMode': 'test',
    });
  }

  Future<void> _replay(String id) async {
    await _client.post('/recordings/$id/replay', {
      'projectPath': _projectPath,
      'udid': '',
      'deviceType': 'iOS Simulator',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          elevation: 1,
          child: ListTile(
            title: const Text('Patroller'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: _serverUrl,
                  child: Chip(
                    label: Text(_connected ? 'connected' : 'offline'),
                    backgroundColor: _connected ? Colors.green : Colors.red,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _refreshAll,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _connected
              ? DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Devices'),
                          Tab(text: 'Driver'),
                          Tab(text: 'Runs'),
                          Tab(text: 'Recordings'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _devicesTab(),
                            _driverTab(),
                            _runsTab(),
                            _recordingsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Not connected to Patroller extension server.',
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 280,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Server URL',
                            hintText: 'http://localhost:8771',
                          ),
                          controller: TextEditingController(text: _serverUrl),
                          onSubmitted: (v) {
                            _serverUrl = v;
                            _rebuildClient();
                            _connect();
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: _connect,
                        child: const Text('Reconnect'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _devicesTab() => ListView(
        children: _devices.map((d) {
          final name = d['name'] as String? ?? '';
          final udid = d['id'] as String? ?? '';
          final state =
              (d['state'] is Map ? d['state']['name'] : d['state']) ?? '';
          return ListTile(
            title: Text(name),
            subtitle: Text('$udid · $state'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.power),
                  tooltip: 'Boot',
                  onPressed: () => _boot(udid),
                ),
                IconButton(
                  icon: const Icon(Icons.stop_circle),
                  tooltip: 'Shutdown',
                  onPressed: () => _shutdown(udid),
                ),
                IconButton(
                  icon: const Icon(Icons.visibility),
                  tooltip: 'Inspect hierarchy',
                  onPressed: () => _inspect(udid),
                ),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Ensure driver',
                  onPressed: () => _ensureDriver(udid),
                ),
              ],
            ),
          );
        }).toList(),
      );

  Widget _driverTab() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('State: ${_driver?['state'] ?? 'unknown'}'),
            if (_driver?['port'] != null) Text('Port: ${_driver!['port']}'),
            if (_driver?['error'] != null)
              Text(
                'Error: ${_driver!['error']}',
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadDriver,
              child: const Text('Refresh driver status'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Inspector hierarchy',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: _hierarchy == null
                  ? const Text(
                      'Use a device\'s Inspect action to load the tree.',
                    )
                  : SingleChildScrollView(
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(_hierarchy),
                      ),
                    ),
            ),
          ],
        ),
      );

  Widget _runsTab() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Project path',
                hintText: '/path/to/flutter/project',
              ),
              onChanged: (v) => _projectPath = v,
              onSubmitted: (_) => _startRun(),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start run (all tests)'),
              onPressed: _startRun,
            ),
            const SizedBox(height: 12),
            const Text(
              'Live logs',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView(
                children: _logs.reversed.map((l) => Text(l)).toList(),
              ),
            ),
          ],
        ),
      );

  Widget _recordingsTab() => ListView(
        children: _recordings.map((r) {
          final name = r['name'] as String? ?? '';
          final id = r['id'] as String? ?? '';
          return ListTile(
            title: Text(name),
            subtitle: Text(id),
            trailing: IconButton(
              icon: const Icon(Icons.replay),
              tooltip: 'Replay',
              onPressed: () => _replay(id),
            ),
          );
        }).toList(),
      );
}
