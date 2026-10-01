import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/note.dart';
import 'services/auth_service.dart';
import 'services/notes_repository.dart';

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

final Provider<FirebaseAuth> firebaseAuthProvider =
    Provider<FirebaseAuth>((Ref ref) => FirebaseAuth.instance);

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (Ref ref) => AuthService(ref.watch(firebaseAuthProvider)),
);

final StreamProvider<User?> authStateProvider = StreamProvider<User?>(
  (Ref ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// Riverpod 3 removed `.valueOrNull`, and `.value` now returns null during both
/// loading and error. Reading `.value` here — never `.requireValue`, never a
/// rethrow — keeps every FirebaseException out of the downstream graph, so
/// nothing below ever has to unwrap a ProviderException.
final Provider<User?> currentUserProvider =
    Provider<User?>((Ref ref) => ref.watch(authStateProvider).value);

final Provider<String?> currentUidProvider =
    Provider<String?>((Ref ref) => ref.watch(currentUserProvider)?.uid);

/// Tracks consecutive cancellations so the sign-in screen can hint at the one
/// configuration problem that is otherwise invisible.
class SignInState {
  const SignInState({this.consecutiveCancels = 0});

  final int consecutiveCancels;

  /// An unregistered SHA-1 makes Credential Manager return a cancellation that
  /// the plugin cannot tell apart from a real one.
  ///
  /// In release, two in a row is the tell — one cancel is usually genuine. In
  /// debug the hint shows immediately, because during development a silent
  /// cancel is far more often a misconfiguration than a real change of mind,
  /// and the alternative is a screen that does nothing with no explanation.
  bool get suspectMisconfiguration =>
      consecutiveCancels >= (kDebugMode ? 1 : 2);
}

class SignInController extends AsyncNotifier<SignInState> {
  /// A synchronous `build()` is a legal override of `FutureOr<StateT> build()`,
  /// and means the first frame is already AsyncData rather than AsyncLoading.
  @override
  SignInState build() => const SignInState();

  Future<void> signIn() async {
    final SignInState previous = state.value ?? const SignInState();
    state = const AsyncValue<SignInState>.loading();
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      state = const AsyncValue<SignInState>.data(SignInState());
      // No navigation here — the auth gate reacts to authStateChanges().
    } on SignInCanceled {
      state = AsyncValue<SignInState>.data(
        SignInState(consecutiveCancels: previous.consecutiveCancels + 1),
      );
    } catch (error, stackTrace) {
      state = AsyncValue<SignInState>.error(error, stackTrace);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue<SignInState>.loading();
    final AsyncValue<void> result = await AsyncValue.guard<void>(
      () => ref.read(authServiceProvider).signOut(),
    );
    state = result.hasError
        ? AsyncValue<SignInState>.error(result.error!, result.stackTrace!)
        : const AsyncValue<SignInState>.data(SignInState());
  }
}

final AsyncNotifierProvider<SignInController, SignInState>
    signInControllerProvider =
    AsyncNotifierProvider<SignInController, SignInState>(SignInController.new);

// ---------------------------------------------------------------------------
// Notes
// ---------------------------------------------------------------------------

final Provider<FirebaseFirestore> firestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) => FirebaseFirestore.instance);

final Provider<NotesRepository> notesRepositoryProvider =
    Provider<NotesRepository>(
  (Ref ref) => NotesRepository(ref.watch(firestoreProvider)),
);

final StreamProvider<List<Note>> notesStreamProvider =
    StreamProvider<List<Note>>(
  (Ref ref) {
    final String? uid = ref.watch(currentUidProvider);
    if (uid == null) return Stream<List<Note>>.value(const <Note>[]);
    return ref.watch(notesRepositoryProvider).watchNotes(uid);
  },
  // Riverpod 3 turned automatic retry on by default, and defaultRetry only
  // declines to retry ProviderException and Error. A
  // FirebaseException('permission-denied') is neither, so without this override
  // sign-out would spin through 10 attempts with exponential backoff — about
  // 30 seconds of dead spinner. Fail fast on auth errors, still retry transient ones.
  retry: (int retryCount, Object error) {
    if (error is FirebaseException &&
        (error.code == 'permission-denied' || error.code == 'unauthenticated')) {
      return null;
    }
    return ProviderContainer.defaultRetry(retryCount, error);
  },
);

/// Save / delete / restore. `AsyncValue<void>` drives button spinners and error
/// text; note *data* always comes from [notesStreamProvider], never from here.
class NoteActions extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> _run(Future<void> Function(String uid) action) async {
    final String? uid = ref.read(currentUidProvider);
    if (uid == null) {
      state = AsyncValue<void>.error(
        StateError('You are signed out.'),
        StackTrace.current,
      );
      return false;
    }
    state = const AsyncValue<void>.loading();
    final AsyncValue<void> result =
        await AsyncValue.guard<void>(() => action(uid));
    state = result;
    return !result.hasError;
  }

  Future<bool> save({
    String? id,
    required String title,
    required String body,
  }) {
    final NotesRepository repo = ref.read(notesRepositoryProvider);
    return _run((String uid) async {
      if (id == null) {
        await repo.create(uid, title: title, body: body);
      } else {
        await repo.update(uid, id, title: title, body: body);
      }
    });
  }

  Future<bool> delete(String id) {
    final NotesRepository repo = ref.read(notesRepositoryProvider);
    return _run((String uid) => repo.delete(uid, id));
  }

  Future<bool> restore(Note note) {
    final NotesRepository repo = ref.read(notesRepositoryProvider);
    return _run((String uid) => repo.restore(uid, note));
  }
}

final AsyncNotifierProvider<NoteActions, void> noteActionsProvider =
    AsyncNotifierProvider<NoteActions, void>(NoteActions.new);
