class ProjectMetadata {
  const ProjectMetadata({
    required this.projectPath,
    required this.projectName,
    required this.hasPubspecYaml,
    required this.hasPatrol,
    required this.patrolTestDir,
    required this.lastOpened,
  });

  final String projectPath;
  final String projectName;
  final bool hasPubspecYaml;
  final bool hasPatrol;
  final String patrolTestDir;
  final String lastOpened;

  Map<String, dynamic> toJson() => {
        'projectPath': projectPath,
        'projectName': projectName,
        'hasPubspecYaml': hasPubspecYaml,
        'hasPatrol': hasPatrol,
        'patrolTestDir': patrolTestDir,
        'lastOpened': lastOpened,
      };

  factory ProjectMetadata.fromJson(Map<String, dynamic> json) => ProjectMetadata(
        projectPath: json['projectPath'] as String? ?? '',
        projectName: json['projectName'] as String? ?? 'project',
        hasPubspecYaml: json['hasPubspecYaml'] as bool? ?? false,
        hasPatrol: json['hasPatrol'] as bool? ?? false,
        patrolTestDir: json['patrolTestDir'] as String? ?? 'patrol_test',
        lastOpened: json['lastOpened'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      );
}

class RecentProject {
  const RecentProject({
    required this.path,
    required this.name,
    required this.lastOpened,
    required this.exists,
  });

  final String path;
  final String name;
  final String lastOpened;
  final bool exists;

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastOpened': lastOpened,
        'exists': exists,
      };

  factory RecentProject.fromJson(Map<String, dynamic> json) => RecentProject(
        path: json['path'] as String? ?? '',
        name: json['name'] as String? ?? '',
        lastOpened: json['lastOpened'] as String? ?? '',
        exists: json['exists'] as bool? ?? false,
      );
}