import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/country.dart';
import 'models/note.dart';
import 'models/onboarding.dart';
import 'models/remote_config.dart';
import 'services/analytics.dart';
import 'services/auth_service.dart';
import 'services/deep_link_service.dart';
import 'services/install_referrer_service.dart';
import 'services/evos_backend.dart';
import 'services/notes_repository.dart';
import 'services/onboarding_store.dart';
import 'services/payment_gateway.dart';
import 'supabase_options.dart';
import 'utils/errors.dart';

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

/// Mixpanel and the Facebook SDK. Controllers and screens call this and never
/// wait for it. Override point for tests.
final Provider<Analytics> analyticsProvider = Provider<Analytics>(
  (Ref ref) => const Analytics(MethodChannelAnalyticsClient()),
);

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
    final Analytics analytics = ref.read(analyticsProvider);
    analytics.signInStarted();
    state = const AsyncValue<SignInState>.loading();
    try {
      final bool newUser =
          await ref.read(authServiceProvider).signInWithGoogle();
      analytics.signInSucceeded(newUser: newUser);
      state = const AsyncValue<SignInState>.data(SignInState());
      // No navigation here — the auth gate reacts to authStateChanges().
    } on SignInCanceled {
      analytics.signInCancelled();
      state = AsyncValue<SignInState>.data(
        SignInState(consecutiveCancels: previous.consecutiveCancels + 1),
      );
    } catch (error, stackTrace) {
      analytics.signInFailed(errorCode(error));
      state = AsyncValue<SignInState>.error(error, stackTrace);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue<SignInState>.loading();
    final AsyncValue<void> result = await AsyncValue.guard<void>(
      () => ref.read(authServiceProvider).signOut(),
    );
    // Here rather than on the auth stream going null: that also happens while
    // the stream is loading or in error, and a reset then would cut a
    // signed-in person off from their own earlier events.
    if (!result.hasError) ref.read(analyticsProvider).signedOut();
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

  Future<bool> _run(
    String name,
    void Function(Analytics analytics) track,
    Future<void> Function(String uid) action,
  ) async {
    final String? uid = ref.read(currentUidProvider);
    if (uid == null) {
      state = AsyncValue<void>.error(
        StateError('You are signed out.'),
        StackTrace.current,
      );
      return false;
    }
    // Reported when the write is issued, not when it completes: the future
    // waits for the server, which offline means until reconnect, while the
    // change is already in the list.
    final Analytics analytics = ref.read(analyticsProvider);
    track(analytics);
    state = const AsyncValue<void>.loading();
    final AsyncValue<void> result =
        await AsyncValue.guard<void>(() => action(uid));
    state = result;
    if (result.hasError) {
      analytics.noteActionFailed(name, errorCode(result.error!));
    }
    return !result.hasError;
  }

  Future<bool> save({
    String? id,
    required String title,
    required String body,
  }) {
    final NotesRepository repo = ref.read(notesRepositoryProvider);
    if (id == null) {
      return _run(
        'create',
        (Analytics analytics) => analytics.noteCreated(),
        (String uid) => repo.create(uid, title: title, body: body),
      );
    }
    return _run(
      'update',
      (Analytics analytics) => analytics.noteUpdated(),
      (String uid) => repo.update(uid, id, title: title, body: body),
    );
  }

  Future<bool> delete(String id) {
    final NotesRepository repo = ref.read(notesRepositoryProvider);
    return _run(
      'delete',
      (Analytics analytics) => analytics.noteDeleted(),
      (String uid) => repo.delete(uid, id),
    );
  }

  Future<bool> restore(Note note) {
    final NotesRepository repo = ref.read(notesRepositoryProvider);
    return _run(
      'restore',
      (Analytics analytics) => analytics.noteRestored(),
      (String uid) => repo.restore(uid, note),
    );
  }
}

final AsyncNotifierProvider<NoteActions, void> noteActionsProvider =
    AsyncNotifierProvider<NoteActions, void>(NoteActions.new);


// ---------------------------------------------------------------------------
// Onboarding (deep link -> mobile number -> code -> paywall -> maintenance)
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

/// Sign-in, settings and the subscription, all on Supabase.
final Provider<EvosBackend> evosBackendProvider = Provider<EvosBackend>((
  Ref ref,
) {
  final OnboardingStore store = ref.watch(onboardingStoreProvider);
  if (!isSupabaseConfigured) return UnconfiguredEvosBackend(store);
  final SupabaseEvosBackend backend =
      SupabaseEvosBackend(kSupabaseUrl, kSupabaseAnonKey, store);
  ref.onDispose(backend.dispose);
  return backend;
});

/// Real money whenever there is a backend to create the mandate. Without one
/// there is nothing to pay through, and a debug build simulates.
final Provider<PaymentGateway> paymentGatewayProvider =
    Provider<PaymentGateway>(
  (Ref ref) => isSupabaseConfigured
      ? CashfreePaymentGateway(ref.watch(evosBackendProvider))
      : const SimulatedPaymentGateway(),
);

final FutureProvider<List<UpiApp>> upiAppsProvider =
    FutureProvider<List<UpiApp>>(
  (Ref ref) => ref.watch(paymentGatewayProvider).upiApps(),
);

/// The backend's settings for the interface: name, logo, colour, paywall,
/// maintenance message. Starts from what the last launch saved, so the first
/// frame is already branded, and is replaced when the server answers.
class RemoteConfigController extends Notifier<RemoteConfig> {
  @override
  RemoteConfig build() {
    final Map<String, String>? rows =
        decodeConfigRows(ref.watch(onboardingStoreProvider).loadConfig());
    return rows == null ? const RemoteConfig() : RemoteConfig.fromRows(rows);
  }

  /// Never throws. A failed fetch keeps what is on screen.
  Future<void> refresh() async {
    final Map<String, String> rows;
    try {
      rows = await ref.read(evosBackendProvider).fetchConfig();
    } on BackendFailure {
      _settle();
      return;
    }
    if (!ref.mounted) return;
    // An empty answer is a table that was never filled in, not a request to
    // drop the saved settings.
    if (rows.isNotEmpty) {
      unawaited(
        ref.read(onboardingStoreProvider).saveConfig(encodeConfigRows(rows)),
      );
      state = RemoteConfig.fromRows(rows);
    }
    // After the new settings, so a screen waiting on this sees them.
    _settle();
  }

  void _settle() {
    if (ref.mounted) ref.read(remoteConfigSettledProvider.notifier).settle();
  }
}

final NotifierProvider<RemoteConfigController, RemoteConfig>
    remoteConfigProvider =
    NotifierProvider<RemoteConfigController, RemoteConfig>(
  RemoteConfigController.new,
);

/// Whether [remoteConfigProvider] holds what the backend decided: saved by an
/// earlier launch, or answered (or failed) on this one. Until then a fresh
/// install shows the defaults, which have no login carousel, and the
/// mobile-number screen waits rather than draw a layout the answer would
/// rearrange.
class RemoteConfigSettledController extends Notifier<bool> {
  @override
  bool build() => ref.watch(onboardingStoreProvider).loadConfig() != null;

  void settle() => state = true;
}

final NotifierProvider<RemoteConfigSettledController, bool>
    remoteConfigSettledProvider =
    NotifierProvider<RemoteConfigSettledController, bool>(
  RemoteConfigSettledController.new,
);

/// Decides which interface the app shows. `AppGate` renders from this state,
/// so nothing here ever navigates.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final DeepLinkService deepLinks = ref.watch(deepLinkServiceProvider);
    final StreamSubscription<Uri> subscription =
        deepLinks.links.listen(_onLink);
    ref.onDispose(subscription.cancel);

    final OnboardingStore store = ref.watch(onboardingStoreProvider);
    final OnboardingState stored = store.load();
    final Uri? initial = deepLinks.initialLink;
    // Two ways in: installed from a Play Store link carrying the onboarding
    // referrer, or opened directly by the onboarding link.
    final bool byReferrer =
        isOnboardingReferrer(ref.watch(installReferrerProvider));
    final bool arrivedByLink =
        byReferrer || (initial != null && isOnboardingLink(initial));
    if (arrivedByLink) {
      ref.read(analyticsProvider).deepLinkOpened(
            afterInstall: byReferrer,
            startedOnboarding: !stored.isActive,
          );
    }

    OnboardingState start = stored;
    if (!stored.isActive && arrivedByLink) {
      start = const OnboardingState(stage: OnboardingStage.signIn);
    } else if (stored.isActive &&
        stored.stage != OnboardingStage.signIn &&
        !ref.watch(evosBackendProvider).isSignedIn) {
      // A stage past sign-in with no sign-in on the device: the session was
      // cleared, or the stage was saved by an older build.
      start = const OnboardingState(stage: OnboardingStage.signIn);
    }
    if (start.stage != stored.stage) unawaited(store.save(start));
    // After build: refresh changes state, which build is not allowed to do.
    if (start.isActive) Future<void>.microtask(refresh);
    return start;
  }

  void _onLink(Uri uri) {
    if (!isOnboardingLink(uri)) return;
    ref.read(analyticsProvider).deepLinkOpened(
          afterInstall: false,
          startedOnboarding: !state.isActive,
        );
    // Opening the link again must not throw away progress already made.
    if (state.isActive) return;
    _set(OnboardingStage.signIn);
    unawaited(refresh());
  }

  void _set(OnboardingStage stage) {
    if (stage == state.stage) return;
    final OnboardingState next = OnboardingState(stage: stage);
    state = next;
    // Not awaited: SharedPreferences updates its in-memory copy synchronously,
    // and the disk write must not hold up the screen change.
    unawaited(ref.read(onboardingStoreProvider).save(next));
  }

  /// Brings the settings and the stage up to date with the server. Run at
  /// start, when the app comes back to the front, and by "Check again".
  ///
  /// Never throws. Offline, the device stays where it last knew it was: a
  /// subscriber is not sent back to the paywall for having no signal.
  Future<void> refresh() async {
    await ref.read(remoteConfigProvider.notifier).refresh();
    if (!ref.mounted) return;

    final OnboardingStage before = state.stage;
    if (before != OnboardingStage.paywall &&
        before != OnboardingStage.maintenance) {
      return;
    }
    try {
      final bool active =
          await ref.read(evosBackendProvider).hasActiveSubscription();
      // The stage moved while the server was answering, by a purchase or a
      // sign-out. That is newer than this answer.
      if (!ref.mounted || state.stage != before) return;
      _set(active ? OnboardingStage.maintenance : OnboardingStage.paywall);
    } on BackendFailure catch (failure) {
      if (!ref.mounted || state.stage != before) return;
      if (failure.kind == BackendError.signedOut) _set(OnboardingStage.signIn);
    }
  }

  /// Called by [PhoneAuthController] once the code is verified.
  void signedIn({required bool subscribed}) => _set(
        subscribed ? OnboardingStage.maintenance : OnboardingStage.paywall,
      );

  /// Called by [PurchaseController] once the server has confirmed the mandate.
  void subscribed() => _set(OnboardingStage.maintenance);

  /// The server no longer accepts the sign-in. Not a choice the user made, so
  /// it is not reported as a sign-out.
  void sessionExpired() {
    ref.invalidate(phoneAuthControllerProvider);
    _set(OnboardingStage.signIn);
  }

  /// Back to the mobile-number screen. The device stays in this interface:
  /// signing out is not a way back to the notes app.
  Future<void> signOut() async {
    ref.read(analyticsProvider).signedOut();
    await ref.read(evosBackendProvider).signOut();
    if (!ref.mounted) return;
    ref.invalidate(phoneAuthControllerProvider);
    _set(OnboardingStage.signIn);
  }
}

final NotifierProvider<OnboardingController, OnboardingState>
    onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);

/// Where the user is between typing a number and being signed in.
class PhoneAuthState {
  const PhoneAuthState({
    this.phone,
    this.lastPhone,
    this.country = kIndia,
    this.sends = 0,
    this.busy = false,
    this.error,
  });

  /// The national digits a code was sent to, without the country code. Null
  /// shows the mobile-number screen; anything else shows the code screen.
  final String? phone;

  /// What to put back in the field after "Change number".
  final String? lastPhone;

  /// The country of [phone], or the one last chosen on the number screen.
  final Country country;

  /// Codes sent to [phone] so far. The code screen restarts its resend timer
  /// when this goes up.
  final int sends;

  final bool busy;
  final Object? error;

  /// [phone] as the server takes it, such as `+919876543210`.
  String? get phoneE164 => phone == null ? null : '+${country.dialCode}$phone';
}

/// Sends and checks the sign-in code.
class PhoneAuthController extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  /// [phone] is the national number, already validated for [country]. Used
  /// by the number screen.
  Future<void> requestCode(Country country, String phone) =>
      _send(country, phone, resend: false);

  /// Used by the code screen.
  Future<void> resend() async {
    final String? phone = state.phone;
    if (phone != null) await _send(state.country, phone, resend: true);
  }

  Future<void> _send(
    Country country,
    String phone, {
    required bool resend,
  }) async {
    final PhoneAuthState before = state;
    final Analytics analytics = ref.read(analyticsProvider);
    analytics.otpRequested(resend: resend, country: country.isoCode);
    state = PhoneAuthState(
      phone: before.phone,
      lastPhone: phone,
      country: country,
      sends: before.sends,
      busy: true,
    );
    try {
      await ref
          .read(evosBackendProvider)
          .sendOtp('+${country.dialCode}$phone');
    } catch (error) {
      analytics.otpRequestFailed(errorCode(error));
      if (!ref.mounted) return;
      state = PhoneAuthState(
        phone: before.phone,
        lastPhone: phone,
        country: country,
        sends: before.sends,
        error: error,
      );
      return;
    }
    if (!ref.mounted) return;
    state = PhoneAuthState(
      phone: phone,
      lastPhone: phone,
      country: country,
      sends: before.sends + 1,
    );
  }

  Future<void> verify(String code) async {
    final String? phone = state.phone;
    final String? e164 = state.phoneE164;
    if (phone == null || e164 == null || state.busy) return;
    final Analytics analytics = ref.read(analyticsProvider);
    final EvosBackend backend = ref.read(evosBackendProvider);
    final Country country = state.country;
    state = PhoneAuthState(
      phone: phone,
      lastPhone: phone,
      country: country,
      sends: state.sends,
      busy: true,
    );
    try {
      final SignInResult result = await backend.verifyOtp(e164, code);
      analytics.otpVerified(
        userId: result.userId,
        newUser: result.isNewUser,
      );
      // Someone who already pays, on a new phone or after signing out, goes
      // straight in. If the server cannot be asked they see the paywall,
      // which sends them on as soon as it can.
      bool subscribed = false;
      try {
        subscribed = await backend.hasActiveSubscription();
      } on BackendFailure {
        // Left false.
      }
      if (!ref.mounted) return;
      state = const PhoneAuthState();
      ref
          .read(onboardingControllerProvider.notifier)
          .signedIn(subscribed: subscribed);
    } catch (error) {
      analytics.otpVerifyFailed(errorCode(error));
      if (!ref.mounted) return;
      state = PhoneAuthState(
        phone: phone,
        lastPhone: phone,
        country: country,
        sends: state.sends,
        error: error,
      );
    }
  }

  /// Back from the code screen to the mobile-number screen.
  void changeNumber() => state = PhoneAuthState(
        lastPhone: state.lastPhone,
        country: state.country,
      );
}

final NotifierProvider<PhoneAuthController, PhoneAuthState>
    phoneAuthControllerProvider =
    NotifierProvider<PhoneAuthController, PhoneAuthState>(
  PhoneAuthController.new,
);

/// Starts the subscription. `AsyncValue<void>` drives the paywall's spinner
/// and error text; the outcome itself is recorded by [OnboardingController].
class PurchaseController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> subscribe(UpiApp app) async {
    if (state.isLoading) return;
    final Analytics analytics = ref.read(analyticsProvider);
    final PaymentGateway gateway = ref.read(paymentGatewayProvider);
    final RemoteConfig config = ref.read(remoteConfigProvider);
    final OnboardingController onboarding =
        ref.read(onboardingControllerProvider.notifier);
    final String planId = config.analyticsPlanId;

    analytics.checkoutStarted(
      planId: planId,
      amount: config.trialAmount,
      currency: RemoteConfig.currencyCode,
      upiApp: app.name,
    );
    state = const AsyncValue<void>.loading();
    try {
      await gateway.subscribe(app);
    } on PaymentCanceled {
      // A cancel is not an error, the same as a cancelled sign-in.
      analytics.checkoutCancelled(planId);
      state = const AsyncValue<void>.data(null);
      return;
    } on BackendFailure catch (failure, stackTrace) {
      if (failure.kind == BackendError.alreadySubscribed) {
        // Paid earlier, and the device had not heard. Nothing was bought
        // just now, so no purchase is reported.
        state = const AsyncValue<void>.data(null);
        onboarding.subscribed();
        return;
      }
      analytics.checkoutFailed(planId, errorCode(failure));
      if (failure.kind == BackendError.signedOut) {
        state = const AsyncValue<void>.data(null);
        onboarding.sessionExpired();
        return;
      }
      state = AsyncValue<void>.error(failure, stackTrace);
      return;
    } catch (error, stackTrace) {
      analytics.checkoutFailed(planId, errorCode(error));
      state = AsyncValue<void>.error(error, stackTrace);
      return;
    }
    analytics.subscriptionSucceeded(
      planId: planId,
      amount: config.trialAmount,
      currency: RemoteConfig.currencyCode,
      simulated: gateway.isSimulated,
    );
    state = const AsyncValue<void>.data(null);
    onboarding.subscribed();
  }
}

final AsyncNotifierProvider<PurchaseController, void>
    purchaseControllerProvider =
    AsyncNotifierProvider<PurchaseController, void>(PurchaseController.new);
