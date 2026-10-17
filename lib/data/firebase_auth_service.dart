import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_config.dart';

/// Google sign-in, backed by Firebase Auth.
class GoogleAuth {
  GoogleAuth._();
  static final instance = GoogleAuth._();

  final _auth = FirebaseAuth.instance;
  bool _ready = false;

  User? get user => _auth.currentUser;
  Stream<User?> changes() => _auth.authStateChanges();

  Future<void> _init() async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize(serverClientId: googleServerClientId);
    _ready = true;
  }

  Future<User?> signIn() async {
    await _init();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    final cred = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    return cred.user;
  }

  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
