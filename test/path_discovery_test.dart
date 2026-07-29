import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:patroller/services/cli_env.dart';
import 'package:patroller/services/mcp_service.dart';

void main() {
  group('path discovery', () {
    test('home falls back to USERPROFILE', () {
      expect(
        userHomeDirectory({'USERPROFILE': r'C:\Users\developer'}),
        r'C:\Users\developer',
      );
    });

    test('PUB_CACHE overrides platform defaults', () {
      expect(
        pubCacheBinDirectory(
          environment: {'PUB_CACHE': '/opt/dart-cache'},
          isWindows: false,
        ),
        p.join('/opt/dart-cache', 'bin'),
      );
    });

    test('Windows pub cache uses LOCALAPPDATA', () {
      expect(
        pubCacheBinDirectory(
          environment: {'LOCALAPPDATA': r'C:\Users\developer\AppData\Local'},
          isWindows: true,
        ),
        p.join(r'C:\Users\developer\AppData\Local', 'Pub', 'Cache', 'bin'),
      );
    });
  });

  group('Patrol MCP wrapper', () {
    final service = McpService();

    test('builds a POSIX wrapper', () {
      final wrapper = service.buildPatrolWrapperScript(
        projectPath: '/work/app',
        dartExecutable: '/opt/dart/bin/dart',
        flutterExecutable: '/opt/flutter/bin/flutter',
        windows: false,
      );

      expect(wrapper, contains('#!/usr/bin/env sh'));
      expect(wrapper, contains('cd "\$PROJECT_ROOT"'));
      expect(wrapper, contains('exec "/opt/dart/bin/dart"'));
    });

    test('builds a native Windows wrapper', () {
      final wrapper = service.buildPatrolWrapperScript(
        projectPath: r'C:\work\app',
        dartExecutable: r'C:\sdk\dart.exe',
        flutterExecutable: r'C:\sdk\flutter.bat',
        windows: true,
      );

      expect(wrapper, startsWith('@echo off'));
      expect(wrapper, contains('cd /d "%PROJECT_ROOT%"'));
      expect(wrapper, contains(r'"C:\sdk\dart.exe" pub global run'));
      expect(wrapper, isNot(contains('#!/usr/bin/env sh')));
    });
  });
}
