import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/services/preview_stream_service.dart';

void main() {
  group('fingerprintBuffer', () {
    test('identical buffers produce identical fingerprints', () {
      final a = Uint8List.fromList(List.generate(8000, (i) => i % 251));
      final b = Uint8List.fromList(List.generate(8000, (i) => i % 251));
      expect(fingerprintBuffer(a), fingerprintBuffer(b));
    });

    test('different buffers produce different fingerprints', () {
      final a = Uint8List.fromList(List.generate(8000, (i) => i % 251));
      final b = Uint8List.fromList(List.generate(8000, (i) => (i + 1) % 251));
      expect(fingerprintBuffer(a), isNot(fingerprintBuffer(b)));
    });

    test('uses full buffer not just a small sample', () {
      final a = Uint8List.fromList(List.filled(12000, 7));
      final b = Uint8List.fromList(List.filled(12000, 7));
      b[11000] = 9;
      expect(fingerprintBuffer(a), isNot(fingerprintBuffer(b)));
    });
  });
}