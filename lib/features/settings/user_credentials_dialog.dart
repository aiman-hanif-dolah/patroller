import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/test_user_credential.dart';
import '../../services/user_credentials_store.dart';

class UserCredentialsDialog extends ConsumerStatefulWidget {
  const UserCredentialsDialog({super.key});

  @override
  ConsumerState<UserCredentialsDialog> createState() =>
      _UserCredentialsDialogState();
}

class _UserCredentialsDialogState
    extends ConsumerState<UserCredentialsDialog> {
  TestUserCredential? _editingCredential;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  TargetEnvironment _env = TargetEnvironment.stg;
  UserMode _userMode = UserMode.live;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCreate() {
    setState(() {
      _editingCredential = null;
      _nameController.text = '';
      _usernameController.text = '';
      _passwordController.text = '';
      _env = TargetEnvironment.stg;
      _userMode = UserMode.live;
    });
  }

  void _startEdit(TestUserCredential cred) {
    setState(() {
      _editingCredential = cred;
      _nameController.text = cred.name;
      _usernameController.text = cred.username;
      _passwordController.text = cred.password;
      _env = cred.env;
      _userMode = cred.userMode;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(userCredentialsProvider.notifier);
    if (_editingCredential != null) {
      final updated = _editingCredential!.copyWith(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        env: _env,
        userMode: _userMode,
      );
      await notifier.updateCredential(updated);
    } else {
      final newCred = TestUserCredential(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        env: _env,
        userMode: _userMode,
      );
      await notifier.addCredential(newCred);
    }

    setState(() {
      _editingCredential = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final credentials = ref.watch(userCredentialsProvider);

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 680,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.key_rounded, size: 22, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  'Manage Test Credentials',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: Row(
                children: [
                  // Credentials List
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Saved Profiles',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: p.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              tooltip: 'Add New Credential',
                              onPressed: _startCreate,
                            ),
                          ],
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: credentials.length,
                            itemBuilder: (context, index) {
                              final item = credentials[index];
                              final isSelected =
                                  _editingCredential?.id == item.id;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? p.surfaceMuted
                                      : p.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? p.borderStrong
                                        : p.border,
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: p.text,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item.env.label} · ${item.userMode.label} · ${item.username}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: p.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _startEdit(item),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16, color: Colors.redAccent),
                                    onPressed: () {
                                      ref
                                          .read(userCredentialsProvider.notifier)
                                          .deleteCredential(item.id);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 24),
                  // Form Editor
                  Expanded(
                    flex: 5,
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _editingCredential == null
                                  ? 'New Profile'
                                  : 'Edit Profile',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Profile Label (e.g. User 1 / Primary User)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Name is required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username / Email',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Username is required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<TargetEnvironment>(
                                    value: _env,
                                    decoration: const InputDecoration(
                                      labelText: 'Environment',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: TargetEnvironment.values
                                        .map((e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e.label),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _env = val);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<UserMode>(
                                    value: _userMode,
                                    decoration: const InputDecoration(
                                      labelText: 'User Mode',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: UserMode.values
                                        .map((e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(e.label),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _userMode = val);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.save_rounded, size: 16),
                              label: const Text('Save Credential Profile'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                              ),
                              onPressed: _save,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
