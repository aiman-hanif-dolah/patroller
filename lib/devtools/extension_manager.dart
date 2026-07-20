import '../services/patrol_studio_facade.dart';

import 'extension_server.dart';

export 'extension_server.dart';

/// Sole owner of the Patroller DevTools extension server lifecycle.
///
/// All start/stop/restart calls must go through [PatrolStudioFacade] so callers
/// share one manager instance and do not orphan HttpServers.
class PatrollerExtensionManager {
  PatrollerExtensionManager(this.facade, {int port = 8771}) : _port = port;

  final PatrolStudioFacade facade;
  int _port;

  PatrollerExtensionServer? _server;

  int get port => _port;

  PatrollerExtensionServer? get server => _server;

  bool get isRunning => _server?.isRunning ?? false;

  /// Starts the server, or no-ops if already running on [port].
  ///
  /// If a server is running on a different port, it is stopped and restarted.
  Future<void> start({int? port}) async {
    if (port != null) _port = port;
    if (_server != null && _server!.isRunning) {
      if (_server!.port == _port) return;
      await stop();
    }
    _server = PatrollerExtensionServer(facade: facade, port: _port);
    await _server!.start();
  }

  Future<void> stop() async {
    await _server?.stop();
    _server = null;
  }

  Future<void> restart({int? port}) async {
    await stop();
    await start(port: port);
  }
}
