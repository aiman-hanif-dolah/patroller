import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

final _closeGroupPattern = RegExp(r'^\s*\}\)?\s*;?\s*$');

List<RegExp> _quoteNamePatterns(String prefix) => [
      RegExp("$prefix\\s*\\(\\s*'([^']*)'"),
      RegExp('$prefix\\s*\\(\\s*"([^"]*)"'),
      RegExp('$prefix\\s*\\(\\s*`([^`]*)`'),
    ];

final _groupPatterns = _quoteNamePatterns('group');

final _testPatterns = <({TestCaseType type, RegExp regex})>[
  for (final prefix in [
    (TestCaseType.patrolTest, 'patrolTest'),
    (TestCaseType.testWidgets, 'testWidgets'),
    (TestCaseType.test, 'test'),
  ])
    for (final regex in _quoteNamePatterns(prefix.$2))
      (type: prefix.$1, regex: regex),
];

bool _lineMightContainTestDecl(String line) =>
    line.contains('patrolTest') ||
    line.contains('testWidgets') ||
    line.contains('group(') ||
    line.contains(' test(') ||
    line.contains('\ttest(');

List<TestCase> parseTestContent(String content, {String parentFile = ''}) {
  final tests = <TestCase>[];
  final groupStack = <String>[];

  final lines = const LineSplitter().convert(content);
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineNumber = i + 1;

    if (line.contains('group(')) {
      for (final pattern in _groupPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null && match.groupCount >= 1) {
          final name = match.group(1);
          if (name != null && name.isNotEmpty) {
            groupStack.add(name);
          }
          break;
        }
      }
    }

    if (_lineMightContainTestDecl(line)) {
      for (final pattern in _testPatterns) {
        final match = pattern.regex.firstMatch(line);
        if (match != null && match.groupCount >= 1) {
          final testName = match.group(1);
          if (testName != null && testName.isNotEmpty) {
            tests.add(
              TestCase(
                testType: pattern.type,
                testName: testName,
                groupName: groupStack.isEmpty ? null : groupStack.last,
                lineNumber: lineNumber,
                columnNumber: 0,
                rawLine: line.trim(),
                parentFile: parentFile,
                status: TestStatus.idle,
              ),
            );
            break;
          }
        }
      }
    }

    if (line.contains('}') &&
        _closeGroupPattern.hasMatch(line) &&
        groupStack.isNotEmpty) {
      groupStack.removeLast();
    }
  }

  return tests;
}

List<TestCase> parseTestFile(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) return [];
  final content = file.readAsStringSync();
  return parseTestContent(content, parentFile: filePath);
}