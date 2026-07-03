import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Synchronous user data path resolution for settings/bootstrap.
Directory patrolStudioUserDataDirSync() {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(p.join(home, 'Library', 'Application Support', 'Patrol Studio'));
    }
  } else if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return Directory(p.join(appData, 'Patrol Studio'));
    }
  }

  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
  return Directory(p.join(home, 'Patrol Studio'));
}

/// Resolves Patrol Studio user data directory.
/// macOS: ~/Library/Application Support/Patrol Studio/
/// Windows: %APPDATA%/Patrol Studio/
Future<Directory> patrolStudioUserDataDir() async {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(p.join(home, 'Library', 'Application Support', 'Patrol Studio'));
    }
  } else if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return Directory(p.join(appData, 'Patrol Studio'));
    }
  }

  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'Patrol Studio'));
}