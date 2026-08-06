enum TargetEnvironment {
  dev,
  stg,
  prod;

  String toJson() => name;

  static TargetEnvironment fromJson(String value) =>
      TargetEnvironment.values.firstWhere(
        (e) => e.name == value.toLowerCase(),
        orElse: () => TargetEnvironment.stg,
      );

  String get label => name.toUpperCase();
}

enum UserMode {
  mock,
  live;

  String toJson() => name;

  static UserMode fromJson(String value) =>
      UserMode.values.firstWhere(
        (e) => e.name == value.toLowerCase(),
        orElse: () => UserMode.live,
      );

  String get label => name[0].toUpperCase() + name.substring(1);
}

class TestUserCredential {
  const TestUserCredential({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    this.env = TargetEnvironment.stg,
    this.userMode = UserMode.live,
  });

  final String id;
  final String name;
  final String username;
  final String password;
  final TargetEnvironment env;
  final UserMode userMode;

  TestUserCredential copyWith({
    String? id,
    String? name,
    String? username,
    String? password,
    TargetEnvironment? env,
    UserMode? userMode,
  }) {
    return TestUserCredential(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      env: env ?? this.env,
      userMode: userMode ?? this.userMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'password': password,
        'env': env.toJson(),
        'userMode': userMode.toJson(),
      };

  factory TestUserCredential.fromJson(Map<String, dynamic> json) =>
      TestUserCredential(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        env: TargetEnvironment.fromJson(json['env'] as String? ?? 'stg'),
        userMode: UserMode.fromJson(json['userMode'] as String? ?? 'live'),
      );

  /// Converts credential object to TOON formatted string
  /// Format:
  /// [User: <name>]
  /// id: <id>
  /// username: <username>
  /// password: <password>
  /// env: <env>
  /// mode: <userMode>
  String toToon() {
    return '[User: $name]\n'
        'id: $id\n'
        'username: $username\n'
        'password: $password\n'
        'env: ${env.name}\n'
        'mode: ${userMode.name}\n';
  }

  /// Parses list of TestUserCredentials from TOON formatted document
  static List<TestUserCredential> parseToonList(String toonContent) {
    final results = <TestUserCredential>[];
    final lines = toonContent.split('\n');
    
    String? currentName;
    String? currentId;
    String? currentUsername;
    String? currentPassword;
    TargetEnvironment currentEnv = TargetEnvironment.stg;
    UserMode currentMode = UserMode.live;

    void flushCurrent() {
      if (currentName != null && currentUsername != null) {
        results.add(
          TestUserCredential(
            id: currentId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: currentName!,
            username: currentUsername!,
            password: currentPassword ?? '',
            env: currentEnv,
            userMode: currentMode,
          ),
        );
      }
      currentName = null;
      currentId = null;
      currentUsername = null;
      currentPassword = null;
      currentEnv = TargetEnvironment.stg;
      currentMode = UserMode.live;
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (trimmed.startsWith('[User:') && trimmed.endsWith(']')) {
        flushCurrent();
        currentName = trimmed.substring(6, trimmed.length - 1).trim();
      } else if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        final key = parts[0].trim().toLowerCase();
        final value = parts.sublist(1).join(':').trim();

        switch (key) {
          case 'id':
            currentId = value;
            break;
          case 'name':
            if (currentName == null) currentName = value;
            break;
          case 'username':
            currentUsername = value;
            break;
          case 'password':
            currentPassword = value;
            break;
          case 'env':
            currentEnv = TargetEnvironment.fromJson(value);
            break;
          case 'mode':
          case 'usermode':
            currentMode = UserMode.fromJson(value);
            break;
        }
      }
    }
    flushCurrent();
    return results;
  }

  /// Encodes list of credentials to a TOON string document
  static String encodeToonList(List<TestUserCredential> credentials) {
    final buffer = StringBuffer('# Patroller Test User Credentials (TOON format)\n\n');
    for (final cred in credentials) {
      buffer.writeln(cred.toToon());
    }
    return buffer.toString();
  }
}
