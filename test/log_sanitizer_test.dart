import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/core/theme/patrol_colors.dart';
import 'package:patroller/domain/log_sanitizer.dart';

void main() {
  group('sanitizeLogText', () {
    test('strips ANSI color codes with escape character', () {
      const input = '\x1B[36mwaitUntilExists\x1B[0m widgets with text "Login".';
      expect(
        sanitizeLogText(input),
        'waitUntilExists widgets with text "Login".',
      );
    });

    test('strips orphan CSI color codes when ESC was lost', () {
      const input = '[36mwaitUntilExists[0m widgets with text "Login".';
      expect(
        sanitizeLogText(input),
        'waitUntilExists widgets with text "Login".',
      );
    });

    test('strips terminal cursor control sequences', () {
      const input = '\x1B[A\x1B[K✅   1. waitUntilExists widgets';
      expect(sanitizeLogText(input), '✅   1. waitUntilExists widgets');
    });

    test('strips orphan cursor control fragments', () {
      const input = '[I][A][Q][K]✅   1. tap widgets with text "Continue".';
      expect(sanitizeLogText(input), '✅   1. tap widgets with text "Continue".');
    });

    test('preserves patrol step emojis and numbering', () {
      const input = '⏳   1. [33mtap[0m widgets with text "Login".';
      expect(
        sanitizeLogText(input),
        '⏳   1. tap widgets with text "Login".',
      );
    });
  });

  group('buildLogTextSpans', () {
    test('applies cyan color to waitUntilExists action', () {
      const input = '\x1B[36mwaitUntilExists\x1B[0m widgets with text "Login".';
      const defaultColor = Color(0xFF4ADE80);
      final spans = buildLogTextSpans(input, defaultColor: defaultColor);

      expect(spans.length, greaterThanOrEqualTo(2));
      expect(spans.first.text, 'waitUntilExists');
      expect(spans.first.style?.color, const Color(0xFF22D3EE));
      expect(spans[1].text, ' widgets with text "Login".');
      expect(spans[1].style?.color, defaultColor);
    });

    test('parses orphan color codes without escape character', () {
      const input = '[33mtap[0m widgets with text "Continue".';
      const defaultColor = Color(0xFF4ADE80);
      final spans = buildLogTextSpans(input, defaultColor: defaultColor);

      expect(spans.first.text, 'tap');
      expect(spans.first.style?.color, PatrolColors.orange400);
    });
  });
}