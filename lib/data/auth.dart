import 'package:shared_preferences/shared_preferences.dart';

/// Who is signed in. The local version remembers a chosen member; the
/// Firebase version will sign in with Google and match the member by email.
abstract class AuthService {
  String? get uid;
  Future<void> signInAs(String uid);
  Future<void> signOut();
}

class LocalAuth implements AuthService {
  LocalAuth(this._prefs);

  static const _key = 'auth.uid';
  final SharedPreferences _prefs;

  @override
  String? get uid => _prefs.getString(_key);

  @override
  Future<void> signInAs(String uid) => _prefs.setString(_key, uid);

  @override
  Future<void> signOut() => _prefs.remove(_key);
}
