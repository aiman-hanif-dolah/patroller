import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/patrol_colors.dart';
import '../../providers/settings_provider.dart';
import '../../services/patrol_studio_facade.dart';

/// In-app DevTools extension status + panel access.
class DevToolsPanel extends ConsumerStatefulWidget {
  const DevToolsPanel({super.key});

  @override
  ConsumerState<DevToolsPanel> createState() => _DevToolsPanelState();
}

class _DevToolsPanelState extends ConsumerState<DevToolsPanel> {
  bool _probing = false;
  bool? _healthy;
  String? _probeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  String get _port {
    return '${ref.read(settingsProvider).settings.devtoolsExtensionPort}';
  }

  String get _baseUrl => 'http://127.0.0.1:$_port';
  String get _panelUrl => '$_baseUrl/panel';

  bool get _serverRunning {
    final ext = PatrolStudioFacade.instance.extension;
    return ext?.isRunning ?? false;
  }

  Future<void> _probe() async {
    setState(() {
      _probing = true;
      _probeError = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      setState(() {
        _healthy = res.statusCode == 200;
        _probing = false;
      });
    } catch (e) {
      setState(() {
        _healthy = false;
        _probeError = e.toString();
        _probing = false;
      });
    }
  }

  Future<void> _ensureServer() async {
    final settings = ref.read(settingsProvider).settings;
    if (!settings.enableDevtoolsExtension) {
      await ref.read(settingsProvider.notifier).updatePartial({
        'enableDevtoolsExtension': true,
      });
    }
    try {
      await PatrolStudioFacade.instance.startExtensionServer(
        port: settings.devtoolsExtensionPort,
      );
    } catch (_) {}
    await _probe();
  }

  Future<void> _openPanel() async {
    await _ensureServer();
    if (Platform.isMacOS) {
      await Process.run('open', [_panelUrl]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', _panelUrl]);
    } else {
      await Process.run('xdg-open', [_panelUrl]);
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final settings = ref.watch(settingsProvider).settings;
    final enabled = settings.enableDevtoolsExtension;
    final running = _serverRunning || _healthy == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DevTools extension',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Patroller runs a local extension server so Flutter DevTools '
            '(and this panel) can drive devices, runs, and recordings.',
            style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.45),
          ),
          const SizedBox(height: 14),
          _StatusCard(
            enabled: enabled,
            running: running,
            healthy: _healthy,
            probing: _probing,
            port: settings.devtoolsExtensionPort,
            error: _probeError,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Btn(
                label: running ? 'Server running' : 'Start server',
                icon: Icons.play_circle_outline,
                color: PatrolColors.psPassed,
                enabled: !running || _healthy != true,
                onPressed: _ensureServer,
              ),
              _Btn(
                label: 'Open panel',
                icon: Icons.open_in_browser,
                color: PatrolColors.sky400,
                enabled: true,
                onPressed: _openPanel,
              ),
              _Btn(
                label: 'Recheck',
                icon: Icons.refresh,
                color: p.textMuted,
                enabled: !_probing,
                onPressed: _probe,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CopyRow(
            label: 'Panel URL',
            value: _panelUrl,
            onCopy: () => _copy(_panelUrl),
          ),
          const SizedBox(height: 8),
          _CopyRow(
            label: 'Health URL',
            value: '$_baseUrl/health',
            onCopy: () => _copy('$_baseUrl/health'),
          ),
          const SizedBox(height: 18),
          Text(
            'How to load',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A · Served from Patroller',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          const SizedBox(height: 6),
          const _Step(
            n: '1',
            text: 'Enable the extension server (above) and keep Patroller running.',
          ),
          const _Step(
            n: '2',
            text: 'Open the panel URL in a browser, or tap Open panel:',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 8),
            child: SelectableText(
              _panelUrl,
              style: const TextStyle(
                fontSize: 11,
                color: PatrolColors.amber,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'B · Flutter DevTools extension',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          const SizedBox(height: 6),
          const _Step(
            n: '1',
            text:
                'Add a path/dev_dependency on this Patroller repo in the Flutter app you are debugging.',
          ),
          const _Step(
            n: '2',
            text:
                'Run flutter pub get, open DevTools, and enable the Patroller extension.',
          ),
          const _Step(
            n: '3',
            text:
                'The Patroller tab talks to this server (default http://localhost:8771).',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border),
            ),
            child: Text(
              'Packaging: extension/devtools/config.yaml + build/, with '
              'devtools_extension/ as the Flutter web source (DevToolsExtension). '
              'See README → DevTools extension.',
              style: TextStyle(
                fontSize: 11,
                color: p.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.enabled,
    required this.running,
    required this.healthy,
    required this.probing,
    required this.port,
    this.error,
  });

  final bool enabled;
  final bool running;
  final bool? healthy;
  final bool probing;
  final int port;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final ok = healthy == true;
    final color = ok
        ? PatrolColors.psPassed
        : enabled
            ? PatrolColors.amber
            : PatrolColors.ember;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.cloud_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                probing
                    ? 'Checking…'
                    : ok
                        ? 'Healthy on port $port'
                        : enabled
                            ? 'Enabled - server not responding on $port'
                            : 'Disabled in settings',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: TextStyle(fontSize: 10, color: p.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Material(
      color: p.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 10,
                        color: p.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy, size: 14, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            child: Text(
              n,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: p.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
