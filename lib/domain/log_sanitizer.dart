import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';

/// Strips terminal control sequences and orphan CSI fragments, returning
/// human-readable log text.
String sanitizeLogText(String text) {
  if (text.isEmpty) return text;
  return _stripAnsiAndControls(text);
}

/// Builds [TextSpan]s from Patrol CLI output that may contain ANSI color codes.
List<TextSpan> buildLogTextSpans(
  String text, {
  required Color defaultColor,
  TextStyle? baseStyle,
}) {
  if (text.isEmpty) {
    return [TextSpan(text: '', style: TextStyle(color: defaultColor))];
  }

  final style = baseStyle ?? const TextStyle(fontFamily: 'Menlo', fontSize: 11);
  final spans = <TextSpan>[];
  var currentColor = defaultColor;
  var bold = false;

  void appendText(String value) {
    if (value.isEmpty) return;
    spans.add(
      TextSpan(
        text: value,
        style: style.copyWith(
          color: currentColor,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  var index = 0;
  while (index < text.length) {
    final nextSpecial = _findNextSpecialIndex(text, index);

    if (nextSpecial == -1) {
      appendText(text.substring(index));
      break;
    }

    appendText(text.substring(index, nextSpecial));

    if (text[nextSpecial] == '\x1b') {
      final parsed = _parseEscapeSequence(text, nextSpecial);
      if (parsed == null) {
        appendText(text[nextSpecial]);
        index = nextSpecial + 1;
        continue;
      }

      if (!parsed.isControl) {
        final resolved = _resolveSgrStyle(parsed.params, defaultColor);
        currentColor = resolved.color;
        bold = resolved.bold;
      }
      index = parsed.end;
      continue;
    }

    final parsed = _parseOrphanCsi(text, nextSpecial);
    if (parsed == null) {
      appendText(text[nextSpecial]);
      index = nextSpecial + 1;
      continue;
    }

    if (!parsed.isControl) {
      final resolved = _resolveSgrStyle(parsed.params, defaultColor);
      currentColor = resolved.color;
      bold = resolved.bold;
    }
    index = parsed.end;
  }

  if (spans.isEmpty) {
    return [TextSpan(text: text, style: style.copyWith(color: defaultColor))];
  }

  return spans;
}

String _stripAnsiAndControls(String text) {
  var result = text;

  result = result.replaceAll(_escapeCsiPattern, '');
  result = result.replaceAll(_bracketedControlPattern, '');
  result = result.replaceAll(_orphanSgrPattern, '');
  result = result.replaceAll(_orphanControlPattern, '');
  result = result.replaceAll('\x1b', '');

  return result;
}

final _escapeCsiPattern = RegExp(r'\x1B\[[\d;?]*[ -/]*[@-~]');
final _orphanSgrPattern = RegExp(r'\[(?:\d{1,3}(?:;\d{1,3})*)m');
final _orphanControlPattern = RegExp(r'\[[\d;?]*[A-KST]');
final _bracketedControlPattern = RegExp(r'\[[A-Z]\]');

int _findNextSpecialIndex(String text, int start) {
  for (var i = start; i < text.length; i++) {
    if (text[i] == '\x1b') return i;
    if (text[i] == '[' && _findOrphanCsiIndex(text, i) != -1) return i;
  }
  return -1;
}

int _findOrphanCsiIndex(String text, int start) {
  for (final pattern in [
    _orphanSgrPattern,
    _orphanControlPattern,
    _bracketedControlPattern,
  ]) {
    if (pattern.matchAsPrefix(text, start) != null) return start;
  }
  return -1;
}

class _ParsedCsi {
  const _ParsedCsi({
    required this.end,
    required this.params,
    required this.finalByte,
  });

  final int end;
  final List<int> params;
  final String finalByte;

  bool get isControl => finalByte != 'm';
}

_ParsedCsi? _parseEscapeSequence(String text, int start) {
  if (start >= text.length || text[start] != '\x1b') return null;
  if (start + 1 >= text.length || text[start + 1] != '[') return null;
  return _parseCsiBody(text, start + 2, start);
}

_ParsedCsi? _parseOrphanCsi(String text, int start) {
  if (start >= text.length || text[start] != '[') return null;

  final bracketed = _bracketedControlPattern.matchAsPrefix(text, start);
  if (bracketed != null) {
    return _ParsedCsi(
      end: bracketed.end,
      params: const [0],
      finalByte: text[start + 1],
    );
  }

  final sgr = _orphanSgrPattern.matchAsPrefix(text, start);
  if (sgr != null) {
    return _parseCsiBody(text, start + 1, start);
  }

  final control = _orphanControlPattern.matchAsPrefix(text, start);
  if (control != null) {
    return _parseCsiBody(text, start + 1, start);
  }

  return null;
}

_ParsedCsi? _parseCsiBody(String text, int paramStart, int sequenceStart) {
  var index = paramStart;
  final params = <int>[];
  var current = '';

  while (index < text.length) {
    final char = text[index];
    if (_isCsiFinalByte(char)) {
      if (current.isNotEmpty) {
        params.add(int.tryParse(current) ?? 0);
      } else if (params.isEmpty) {
        params.add(0);
      }
      return _ParsedCsi(
        end: index + 1,
        params: params,
        finalByte: char,
      );
    }

    if (char == ';') {
      params.add(int.tryParse(current) ?? 0);
      current = '';
      index++;
      continue;
    }

    if (!RegExp(r'[\d?]').hasMatch(char)) {
      return null;
    }

    current += char;
    index++;
  }

  return null;
}

bool _isCsiFinalByte(String char) {
  if (char.length != 1) return false;
  final code = char.codeUnitAt(0);
  return code >= 0x40 && code <= 0x7E;
}

class _ResolvedSgrStyle {
  const _ResolvedSgrStyle({required this.color, required this.bold});

  final Color color;
  final bool bold;
}

_ResolvedSgrStyle _resolveSgrStyle(List<int> params, Color defaultColor) {
  var color = defaultColor;
  var bold = false;

  for (var i = 0; i < params.length; i++) {
    final code = params[i];
    switch (code) {
      case 0:
        color = defaultColor;
        bold = false;
      case 1:
        bold = true;
      case 30:
        color = const Color(0xFF52525B);
      case 31:
        color = PatrolColors.red400;
      case 32:
        color = PatrolColors.green400;
      case 33:
        color = PatrolColors.orange400;
      case 34:
        color = const Color(0xFF60A5FA);
      case 35:
        color = const Color(0xFFC084FC);
      case 36:
        color = const Color(0xFF22D3EE);
      case 37:
        color = defaultColor;
      case 90:
        color = PatrolColors.steel;
      case 94:
        color = const Color(0xFF38BDF8);
      case 38:
        if (i + 2 < params.length && params[i + 1] == 5) {
          color = _ansi256Color(params[i + 2]);
          i += 2;
        }
    }
  }

  return _ResolvedSgrStyle(color: color, bold: bold);
}

Color _ansi256Color(int code) {
  if (code < 16) {
    const palette = [
      Color(0xFF202020),
      Color(0xFFEF4444),
      Color(0xFF22C55E),
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
      Color(0xFFA855F7),
      Color(0xFF06B6D4),
      Color(0xFFE4E4E7),
      Color(0xFF71717A),
      Color(0xFFF87171),
      Color(0xFF4ADE80),
      Color(0xFFFBBF24),
      Color(0xFF60A5FA),
      Color(0xFFC084FC),
      Color(0xFF22D3EE),
      Color(0xFF202020),
    ];
    return palette[code.clamp(0, 15)];
  }

  if (code < 232) {
    final index = code - 16;
    final r = (index ~/ 36) * 51;
    final g = ((index ~/ 6) % 6) * 51;
    final b = (index % 6) * 51;
    return Color.fromARGB(255, r, g, b);
  }

  final gray = ((code - 232) * 10 + 8).clamp(0, 255);
  return Color.fromARGB(255, gray, gray, gray);
}