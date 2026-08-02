import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:patroller/services/routine_service.dart';

void main() {
  test('applyMarionetteBinding injects binding into main.dart with kDebugMode guard', () async {
    final tempDir = Directory.systemTemp.createTempSync('marionette_binding_test_');
    try {
      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
      final mainFile = File(p.join(libDir.path, 'main.dart'));
      mainFile.writeAsStringSync('''
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
''');

      final service = RoutineService();
      await service.applyMarionetteBinding(tempDir.path, 'lib/main.dart');

      final updated = mainFile.readAsStringSync();
      expect(updated, contains('MarionetteBinding.ensureInitialized()'));
      expect(updated, contains('kDebugMode'));
      expect(updated, contains('marionette_flutter'));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
