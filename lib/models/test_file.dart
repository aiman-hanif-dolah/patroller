import 'enums.dart';

class TestCase {
  const TestCase({
    required this.testType,
    required this.testName,
    this.groupName,
    required this.lineNumber,
    required this.columnNumber,
    required this.rawLine,
    required this.parentFile,
    required this.status,
    this.lastDuration,
  });

  final TestCaseType testType;
  final String testName;
  final String? groupName;
  final int lineNumber;
  final int columnNumber;
  final String rawLine;
  final String parentFile;
  final TestStatus status;
  final int? lastDuration;

  Map<String, dynamic> toJson() => {
        'testType': testType.toJson(),
        'testName': testName,
        'groupName': groupName,
        'lineNumber': lineNumber,
        'columnNumber': columnNumber,
        'rawLine': rawLine,
        'parentFile': parentFile,
        'status': status.toJson(),
        'lastDuration': lastDuration,
      };

  factory TestCase.fromJson(Map<String, dynamic> json) => TestCase(
        testType: TestCaseType.fromJson(json['testType'] as String? ?? 'test'),
        testName: json['testName'] as String? ?? '',
        groupName: json['groupName'] as String?,
        lineNumber: json['lineNumber'] as int? ?? 0,
        columnNumber: json['columnNumber'] as int? ?? 0,
        rawLine: json['rawLine'] as String? ?? '',
        parentFile: json['parentFile'] as String? ?? '',
        status: TestStatus.fromJson(json['status'] as String? ?? 'idle'),
        lastDuration: json['lastDuration'] as int?,
      );
}

class TestGroup {
  const TestGroup({
    required this.name,
    required this.lineNumber,
    required this.tests,
  });

  final String name;
  final int lineNumber;
  final List<TestCase> tests;

  Map<String, dynamic> toJson() => {
        'name': name,
        'lineNumber': lineNumber,
        'tests': tests.map((t) => t.toJson()).toList(),
      };

  factory TestGroup.fromJson(Map<String, dynamic> json) => TestGroup(
        name: json['name'] as String? ?? '',
        lineNumber: json['lineNumber'] as int? ?? 0,
        tests: (json['tests'] as List<dynamic>? ?? [])
            .map((e) => TestCase.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TestFile {
  const TestFile({
    required this.absolutePath,
    required this.relativePath,
    required this.fileName,
    required this.folderPath,
    required this.fileSize,
    required this.lastModified,
    required this.detectedTestCount,
    required this.detectedGroups,
    required this.detectedTests,
    required this.lastRunStatus,
    this.lastRunDuration,
    this.lastRunTime,
    this.content,
  });

  final String absolutePath;
  final String relativePath;
  final String fileName;
  final String folderPath;
  final int fileSize;
  final String lastModified;
  final int detectedTestCount;
  final List<TestGroup> detectedGroups;
  final List<TestCase> detectedTests;
  final TestStatus lastRunStatus;
  final int? lastRunDuration;
  final String? lastRunTime;
  final String? content;

  Map<String, dynamic> toJson() => {
        'absolutePath': absolutePath,
        'relativePath': relativePath,
        'fileName': fileName,
        'folderPath': folderPath,
        'fileSize': fileSize,
        'lastModified': lastModified,
        'detectedTestCount': detectedTestCount,
        'detectedGroups': detectedGroups.map((g) => g.toJson()).toList(),
        'detectedTests': detectedTests.map((t) => t.toJson()).toList(),
        'lastRunStatus': lastRunStatus.toJson(),
        'lastRunDuration': lastRunDuration,
        'lastRunTime': lastRunTime,
        if (content != null) 'content': content,
      };

  factory TestFile.fromJson(Map<String, dynamic> json) => TestFile(
        absolutePath: json['absolutePath'] as String? ?? '',
        relativePath: json['relativePath'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        folderPath: json['folderPath'] as String? ?? '',
        fileSize: json['fileSize'] as int? ?? 0,
        lastModified: json['lastModified'] as String? ?? '',
        detectedTestCount: json['detectedTestCount'] as int? ?? 0,
        detectedGroups: (json['detectedGroups'] as List<dynamic>? ?? [])
            .map((e) => TestGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        detectedTests: (json['detectedTests'] as List<dynamic>? ?? [])
            .map((e) => TestCase.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastRunStatus: TestStatus.fromJson(json['lastRunStatus'] as String? ?? 'idle'),
        lastRunDuration: json['lastRunDuration'] as int?,
        lastRunTime: json['lastRunTime'] as String?,
        content: json['content'] as String?,
      );
}