import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('bundled simulator driver artifacts', () {
    test('runner zip exists in resources', () {
      final zip = File(
        p.join(
          Directory.current.path,
          'resources',
          'patrol-simulator-driver',
          'simulator',
          'Debug-iphonesimulator',
          'PatrolSimulatorDriverUITests-Runner.zip',
        ),
      );
      expect(zip.existsSync(), isTrue);
    });

    test('runner app exists after bundle extraction or zip only', () {
      final buildDir = p.join(
        Directory.current.path,
        'resources',
        'patrol-simulator-driver',
        'simulator',
        'Debug-iphonesimulator',
      );
      final app = Directory(
        p.join(buildDir, 'PatrolSimulatorDriverUITests-Runner.app'),
      );
      final zip = File(
        p.join(buildDir, 'PatrolSimulatorDriverUITests-Runner.zip'),
      );
      expect(app.existsSync() || zip.existsSync(), isTrue);
    });
  });
}