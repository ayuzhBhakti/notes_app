import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/note.dart';
import 'models/onboarding.dart';
import 'services/auth_service.dart';
import 'services/deep_link_service.dart';
import 'services/install_referrer_service.dart';
import 'services/leads_repository.dart';
import 'services/notes_repository.dart';
import 'services/onboarding_store.dart';
import 'services/payment_gateway.dart';
import 'supabase_options.dart';

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

// ---------------------------------------------------------------------------
// Onboarding (deep link -> details form -> paywall -> member home)
// ---------------------------------------------------------------------------

/// Both are created in `main()` and supplied through ProviderScope overrides:
/// the store needs an awaited load, and the link service has to be observing
/// before `runApp`.
final Provider<OnboardingStore> onboardingStoreProvider =
    Provider<OnboardingStore>(
  (Ref ref) => throw UnimplementedError('Overridden in main().'),
);

final Provider<DeepLinkService> deepLinkServiceProvider =
    Provider<DeepLinkService>(
  (Ref ref) => throw UnimplementedError('Overridden in main().'),
);

/// The referrer of the Play Store link that led to this install. `main()`
/// overrides it on the first launch only; on every later launch it is null and
/// the saved onboarding state decides.
final Provider<String?> installReferrerProvider =
    Provider<String?>((Ref ref) => null);

/// The one line to change when a real payment provider is chosen.
final Provider<PaymentGateway> paymentGatewayProvider =
    Provider<PaymentGateway>((Ref ref) => const SimulatedPaymentGateway());

final Provider<LeadsRepository> leadsRepositoryProvider =
    Provider<LeadsRepository>((Ref ref) {
  if (!isSupabaseConfigured) return const UnconfiguredLeadsRepository();
  final SupabaseLeadsRepository repository =
      SupabaseLeadsRepository(kSupabaseUrl, kSupabaseAnonKey);
  ref.onDispose(repository.dispose);
  return repository;
});

/// Decides which interface the app shows. `AppGate` renders from this state,
/// so nothing here ever navigates.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final DeepLinkService deepLinks = ref.watch(deepLinkServiceProvider);
    final StreamSubscription<Uri> subscription =
        deepLinks.links.listen(_onLink);
    ref.onDispose(subscription.cancel);

    final OnboardingState stored = ref.watch(onboardingStoreProvider).load();
    final Uri? initial = deepLinks.initialLink;
    // Two ways in: installed from a Play Store link carrying the onboarding
    // referrer, or opened directly by the onboarding link.
    final bool arrivedByLink =
        isOnboardingReferrer(ref.watch(installReferrerProvider)) ||
            (initial != null && isOnboardingLink(initial));
    if (!stored.isActive && arrivedByLink) {
      const OnboardingState started =
          OnboardingState(stage: OnboardingStage.details);
      unawaited(ref.read(onboardingStoreProvider).save(started));
      return started;
    }
    return stored;
  }

  void _onLink(Uri uri) {
    // Opening the link again must not throw away progress already made.
    if (state.isActive || !isOnboardingLink(uri)) return;
    _set(const OnboardingState(stage: OnboardingStage.details));
  }

  void _set(OnboardingState next) {
    state = next;
    // Not awaited: SharedPreferences updates its in-memory copy synchronously,
    // and the disk write must not hold up the screen change.
    unawaited(ref.read(onboardingStoreProvider).save(next));
  }

  /// Called by [DetailsSubmitController] once the details are on the server.
  void submitDetails(LeadDetails details) {
    _set(OnboardingState(stage: OnboardingStage.paywall, details: details));
  }

  /// Back from the paywall. The details are kept so the form is pre-filled.
  void editDetails() {
    _set(OnboardingState(stage: OnboardingStage.details, details: state.details));
  }

  void completePurchase(String planId) {
    _set(
      OnboardingState(
        stage: OnboardingStage.member,
        details: state.details,
        planId: planId,
      ),
    );
  }

  /// Returns the device to the normal notes app. Only reachable from a
  /// debug-build button; a real user has no way to leave the flow.
  void reset() {
    state = const OnboardingState();
    unawaited(ref.read(onboardingStoreProvider).clear());
  }
}

final NotifierProvider<OnboardingController, OnboardingState>
    onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);

/// Saves the details form to the server, then advances to the paywall.
/// `AsyncValue<void>` drives the form's spinner and error text.
class DetailsSubmitController extends AsyncNotifier<void> {
  @override
  void build() {}

  /// Awaited by the form, unlike a note save. A note is in Firestore's
  /// offline cache the moment it is written; this insert has no local copy,
  /// so the user must not move on until the server has it.
  Future<bool> submit(LeadDetails details) async {
    state = const AsyncValue<void>.loading();
    final AsyncValue<void> result = await AsyncValue.guard<void>(
      () => ref.read(leadsRepositoryProvider).save(details),
    );
    state = result;
    if (result.hasError) return false;
    ref.read(onboardingControllerProvider.notifier).submitDetails(details);
    return true;
  }
}

final AsyncNotifierProvider<DetailsSubmitController, void>
    detailsSubmitControllerProvider =
    AsyncNotifierProvider<DetailsSubmitController, void>(
  DetailsSubmitController.new,
);

/// Runs a purchase. `AsyncValue<void>` drives the paywall's spinner and error
/// banner; the outcome itself is recorded by [OnboardingController].
class PurchaseController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> purchase(Plan plan) async {
    state = const AsyncValue<void>.loading();
    try {
      await ref.read(paymentGatewayProvider).purchase(plan);
    } on PaymentCanceled {
      // A cancel is not an error, the same as a cancelled sign-in.
      state = const AsyncValue<void>.data(null);
      return false;
    } catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return false;
    }
    state = const AsyncValue<void>.data(null);
    ref.read(onboardingControllerProvider.notifier).completePurchase(plan.id);
    return true;
  }
}

final AsyncNotifierProvider<PurchaseController, void>
    purchaseControllerProvider =
    AsyncNotifierProvider<PurchaseController, void>(PurchaseController.new);
