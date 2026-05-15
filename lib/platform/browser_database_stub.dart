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
  static final Map<String, String> _memory = <String, String>{};

  Future<StoredUser> loadAdmin() async {
    final email = _memory['admin_email'] ?? 'juliancamilo1995@gmail.com';
    final password = _memory['admin_password'] ?? 'admin123';
    final mustReset = _memory['admin_must_reset'] != 'false';
    return StoredUser(
      email: email,
      password: password,
      mustResetPassword: mustReset,
    );
  }

  Future<void> saveAdminPassword(String password) async {
    _memory['admin_email'] = 'juliancamilo1995@gmail.com';
    _memory['admin_password'] = password;
    _memory['admin_must_reset'] = 'false';
  }

  Future<void> saveSession(String email) async {
    _memory['session_email'] = email;
  }

  Future<String?> loadSession() async {
    return _memory['session_email'];
  }

  Future<void> clearSession() async {
    _memory.remove('session_email');
  }
}
