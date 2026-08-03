import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test file deletion', () {
    test('file deletion safely deletes temporary test file', () async {
      final tempDir = Directory.systemTemp.createTempSync('patroller_test_delete');
      final testFile = File('${tempDir.path}/sample_test.dart');
      await testFile.writeAsString('void main() {}');

      expect(await testFile.exists(), true);
      await testFile.delete();
      expect(await testFile.exists(), false);

      tempDir.deleteSync(recursive: true);
    });
  });
}
