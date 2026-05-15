// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class StoredUser {
  const StoredUser({
    required this.email,
    required this.password,
    required this.mustResetPassword,
  });

  final String email;
  final String password;
  final bool mustResetPassword;
}

class BrowserDatabase {
  static const _adminEmail = 'juliancamilo1995@gmail.com';

  Future<StoredUser> loadAdmin() async {
    final storage = html.window.localStorage;
    storage.putIfAbsent('admin_email', () => _adminEmail);
    storage.putIfAbsent('admin_password', () => 'admin123');
    storage.putIfAbsent('admin_must_reset', () => 'true');

    return StoredUser(
      email: storage['admin_email'] ?? _adminEmail,
      password: storage['admin_password'] ?? 'admin123',
      mustResetPassword: storage['admin_must_reset'] != 'false',
    );
  }

  Future<void> saveAdminPassword(String password) async {
    final storage = html.window.localStorage;
    storage['admin_email'] = _adminEmail;
    storage['admin_password'] = password;
    storage['admin_must_reset'] = 'false';
  }

  Future<void> saveSession(String email) async {
    html.window.localStorage['session_email'] = email;
  }

  Future<String?> loadSession() async {
    return html.window.localStorage['session_email'];
  }

  Future<void> clearSession() async {
    html.window.localStorage.remove('session_email');
  }
}
