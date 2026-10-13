import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode;
import 'package:google_sign_in/google_sign_in.dart';

/// OAuth clients for Firebase project `notes-f36b3`.
///
/// Passing these explicitly is what lets the app work without the
/// `google-services` Gradle plugin on Android (which would otherwise generate a
/// `default_web_client_id` string resource) and without a bundled
/// `GoogleService-Info.plist` on iOS.
const String kWebClientId =
    '686456708333-bhfa4bsdnsrivcdmkkugvj4n0n927tql.apps.googleusercontent.com';
const String kIosClientId =
    '686456708333-f3jcg4edjglfpocpv69uvggappupp0h8.apps.googleusercontent.com';

/// The user backed out of the Google account sheet. Never shown as an error.
class SignInCanceled implements Exception {
  const SignInCanceled();

  @override
  String toString() => 'SignInCanceled';
}

/// The only file in the app that imports `google_sign_in`.
class AuthService {
  const AuthService(this._auth);

  final FirebaseAuth _auth;

  /// Must be called exactly once, and awaited, before any other
  /// `GoogleSignIn.instance` method. Calling it twice is undefined behaviour.
  static Future<void> initializeGoogleSignIn() {
    final bool isIos = defaultTargetPlatform == TargetPlatform.iOS;
    return GoogleSignIn.instance.initialize(
      // Ignored on Android, where the app is identified by package name plus
      // the SHA-1 of its signing key.
      clientId: isIos ? kIosClientId : null,
      // Required on Android; unused on iOS. This names the *audience* of the
      // returned ID token, which is why it is the web client, not the Android one.
      serverClientId: isIos ? null : kWebClientId,
    );
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Returns true when this sign-in created the account.
  Future<bool> signInWithGoogle() async {
    final GoogleSignIn google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw StateError(
        'Interactive Google sign-in is not available on this platform.',
      );
    }

    final GoogleSignInAccount account = await _authenticate(google);

    // google_sign_in 7.x: `authentication` is a SYNCHRONOUS getter.
    // `await account.authentication` was the 6.x API and will not compile here.
    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google sign-in returned no ID token.',
      );
    }

    // accessToken is intentionally omitted: GoogleAuthProvider.credential
    // asserts only that one of idToken/accessToken is non-null, and obtaining an
    // access token in 7.x means a second consent prompt through
    // account.authorizationClient — for no benefit to Firebase.
    final UserCredential credential = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    return credential.additionalUserInfo?.isNewUser ?? false;
  }

  Future<GoogleSignInAccount> _authenticate(GoogleSignIn google) async {
    try {
      // Returns non-nullable in 7.x, and throws on cancel rather than
      // returning null the way 6.x's signIn() did.
      return await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        if (kDebugMode) {
          // Credential Manager reports configuration errors as a cancellation
          // that is indistinguishable from the user backing out, so this path
          // is otherwise completely silent — the single hardest thing to debug
          // in this flow. Say so out loud in debug builds.
          debugPrint(
            '[auth] Google sign-in reported CANCELED.\n'
            '       If you did NOT dismiss the sheet yourself, this is almost\n'
            '       certainly an unregistered signing certificate. Add this\n'
            "       app's SHA-1 to the Android app in the Firebase console:\n"
            '         Project settings -> Your apps -> Add fingerprint\n'
            '       Get the fingerprint with:\n'
            '         keytool -list -v -alias androiddebugkey \\\n'
            '           -keystore ~/.android/debug.keystore \\\n'
            '           -storepass android -keypass android | grep SHA1\n'
            '       Details: ${e.description ?? "(none)"}',
          );
        }
        throw const SignInCanceled();
      }
      if (kDebugMode) {
        debugPrint(
          '[auth] GoogleSignInException(${e.code}): '
          '${e.description ?? "(no description)"} | details: ${e.details}',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    // signOut(), never disconnect(): google_sign_in_android does not implement
    // disconnect — it simply calls signOut — so a "revoke access" button would
    // be a lie on Android. The app does not offer one.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Best effort; Firebase sign-out below must happen regardless.
    }
    await _auth.signOut();
  }
}
