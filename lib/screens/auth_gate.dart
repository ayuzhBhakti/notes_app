import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../utils/errors.dart';
import 'notes_list_screen.dart';
import 'sign_in_screen.dart';

/// Chooses between the sign-in screen and the app, and — because it is the
/// `home` of the MaterialApp — unwinds any pushed routes on sign-out, so a
/// signed-out user can never be left looking at an editor.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Covers both a fresh sign-in and an app start with a live session.
    ref.listen<String?>(currentUidProvider, (String? _, String? uid) {
      final User? user = ref.read(currentUserProvider);
      if (uid == null || user == null) return;
      ref.read(analyticsProvider).identify(
            uid,
            name: user.displayName,
            email: user.email,
          );
    });

    final AsyncValue<User?> authState = ref.watch(authStateProvider);

    return authState.when(
      // Without this the whole app flashes a spinner every time the auth stream
      // re-emits, for example immediately after signing in.
      skipLoadingOnReload: true,
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) {
        final AppFailure failure = describeError(error);
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 12),
                  Text(failure.message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      },
      data: (User? user) =>
          user == null ? const SignInScreen() : const NotesListScreen(),
    );
  }
}
