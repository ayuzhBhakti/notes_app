import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Auth for the notes interface.
///
/// Google sign-in was removed on 2026-10-22, when phone sign-in on Supabase
/// became the only way in. Nothing signs in to Firebase any more; this is
/// kept for the notes screens, which are no longer reachable from `AppGate`.
class AuthService {
  const AuthService(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signOut() => _auth.signOut();
}
