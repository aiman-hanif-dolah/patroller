import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'app_paths.dart';

const int maxRecentProjects = 20;

class RecentProjectsStore {
  RecentProjectsStore._();

  static final RecentProjectsStore instance = RecentProjectsStore._();

  List<_RecentEntry> _entries = [];
  String? _filePath;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final dir = await patrolStudioUserDataDir();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _filePath = p.join(dir.path, 'recentProjects.json');
    _entries = _loadFromDisk(_filePath!);
    _loaded = true;
  }

  List<_RecentEntry> _loadFromDisk(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return [];
      final parsed = jsonDecode(file.readAsStringSync());
      if (parsed is! List) return [];
      return parsed
          .whereType<Map>()
          .map((e) => _RecentEntry.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.path.isNotEmpty)
          .take(maxRecentProjects)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    await _ensureLoaded();
    if (_filePath == null) return;
    try {
      final json = jsonEncode(_entries.map((e) => e.toJson()).toList());
      await File(_filePath!).writeAsString(json);
    } catch (_) {}
  }

  Future<List<RecentProject>> getAll() async {
    await _ensureLoaded();
    return _entries
        .map(
          (entry) => RecentProject(
            path: entry.path,
            name: entry.name,
            lastOpened: entry.lastOpened,
            exists: Directory(entry.path).existsSync(),
          ),
        )
        .toList();
  }

  Future<void> add(String projectPath, String projectName) async {
    await _ensureLoaded();
    _entries.removeWhere((e) => e.path == projectPath);
    _entries.insert(
      0,
      _RecentEntry(
        path: projectPath,
        name: projectName,
        lastOpened: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    if (_entries.length > maxRecentProjects) {
      _entries = _entries.sublist(0, maxRecentProjects);
    }
    await _save();
  }

  Future<void> addFromMetadata(ProjectMetadata project) =>
      add(project.projectPath, project.projectName);

  Future<void> remove(String projectPath) async {
    await _ensureLoaded();
    final before = _entries.length;
    _entries.removeWhere((e) => e.path == projectPath);
    if (_entries.length != before) {
      await _save();
    }
  }
}

class _RecentEntry {
  _RecentEntry({
    required this.path,
    required this.name,
    required this.lastOpened,
  });

  final String path;
  final String name;
  final String lastOpened;

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastOpened': lastOpened,
      };

  factory _RecentEntry.fromJson(Map<String, dynamic> json) => _RecentEntry(
        path: json['path'] as String? ?? '',
        name: json['name'] as String? ?? '',
        lastOpened: json['lastOpened'] as String? ?? '',
      );
}