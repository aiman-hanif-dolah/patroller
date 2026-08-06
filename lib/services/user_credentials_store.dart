import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/test_user_credential.dart';
import 'app_paths.dart';

class UserCredentialsStore {
  UserCredentialsStore([String? customPath]) : _customPath = customPath;

  final String? _customPath;

  Future<File> _getFile() async {
    if (_customPath != null) {
      final file = File(_customPath);
      await file.parent.create(recursive: true);
      return file;
    }
    final dir = await patrolStudioUserDataDir();
    final file = File(p.join(dir.path, 'test_credentials.toon'));
    await file.parent.create(recursive: true);
    return file;
  }

  Future<List<TestUserCredential>> loadCredentials() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        final defaults = _defaultCredentials();
        await saveCredentials(defaults);
        return defaults;
      }
      final content = await file.readAsString();
      final list = TestUserCredential.parseToonList(content);
      if (list.isEmpty) {
        final defaults = _defaultCredentials();
        await saveCredentials(defaults);
        return defaults;
      }
      return list;
    } catch (_) {
      return _defaultCredentials();
    }
  }

  Future<void> saveCredentials(List<TestUserCredential> credentials) async {
    final file = await _getFile();
    final toonString = TestUserCredential.encodeToonList(credentials);
    await file.writeAsString(toonString);
  }

  List<TestUserCredential> _defaultCredentials() {
    return const [
      TestUserCredential(
        id: 'user_1',
        name: 'Primary User',
        username: 'user1@example.com',
        password: 'Password123',
        env: TargetEnvironment.stg,
        userMode: UserMode.live,
      ),
      TestUserCredential(
        id: 'user_2',
        name: 'Mock User Default',
        username: 'mock-user@example.com',
        password: 'MockPassword123',
        env: TargetEnvironment.stg,
        userMode: UserMode.mock,
      ),
    ];
  }
}

class UserCredentialsNotifier extends StateNotifier<List<TestUserCredential>> {
  UserCredentialsNotifier(this._store) : super([]) {
    _init();
  }

  final UserCredentialsStore _store;
  TestUserCredential? _selectedCredential;

  TestUserCredential? get selectedCredential => _selectedCredential;

  Future<void> _init() async {
    state = await _store.loadCredentials();
    if (state.isNotEmpty) {
      _selectedCredential = state.first;
    }
  }

  void selectCredential(TestUserCredential? cred) {
    _selectedCredential = cred;
    // Trigger state refresh
    state = [...state];
  }

  Future<void> addCredential(TestUserCredential credential) async {
    final updated = [...state, credential];
    state = updated;
    await _store.saveCredentials(updated);
    if (_selectedCredential == null) {
      _selectedCredential = credential;
    }
  }

  Future<void> updateCredential(TestUserCredential credential) async {
    final updated = [
      for (final item in state)
        if (item.id == credential.id) credential else item
    ];
    state = updated;
    await _store.saveCredentials(updated);
    if (_selectedCredential?.id == credential.id) {
      _selectedCredential = credential;
    }
  }

  Future<void> deleteCredential(String id) async {
    final updated = state.where((item) => item.id != id).toList();
    state = updated;
    await _store.saveCredentials(updated);
    if (_selectedCredential?.id == id) {
      _selectedCredential = updated.isNotEmpty ? updated.first : null;
    }
  }
}

final userCredentialsStoreProvider = Provider<UserCredentialsStore>((ref) {
  return UserCredentialsStore();
});

final userCredentialsProvider =
    StateNotifierProvider<UserCredentialsNotifier, List<TestUserCredential>>((ref) {
  final store = ref.watch(userCredentialsStoreProvider);
  return UserCredentialsNotifier(store);
});
