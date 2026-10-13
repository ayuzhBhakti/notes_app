# Architecture

The app has three layers. Widgets read state from Riverpod providers, providers call services, and services are the only code that talks to Firebase.

```mermaid
flowchart TD
    subgraph UI["UI — lib/screens, lib/widgets"]
        AppGate
        AuthGate
        SignInScreen
        NotesListScreen
        NoteEditorScreen
        ProfileScreen
    end
    subgraph State["State — lib/providers.dart"]
        authStateProvider
        signInControllerProvider
        notesStreamProvider
        noteActionsProvider
    end
    subgraph Data["Services — lib/services"]
        AuthService
        NotesRepository
    end
    subgraph Firebase
        FirebaseAuth
        GoogleSignIn
        Firestore
    end

    UI --> State
    State --> Data
    AuthService --> FirebaseAuth
    AuthService --> GoogleSignIn
    NotesRepository --> Firestore
```

Analytics sits beside this: controllers and screens call `Analytics`, which sends to Mixpanel and the Facebook SDK over a method channel. It is described in [10-analytics.md](10-analytics.md).

`AppGate` is the root widget. It shows `AuthGate` (the notes app) unless the device has opened an onboarding deep link, in which case it shows the onboarding screens instead. That second interface (Evos) has its own sign-in, backend and theme, none of which touch Firebase, and is described in [09-deep-link-onboarding.md](09-deep-link-onboarding.md).

## Folder layout

| Path | Contents |
|------|----------|
| [lib/main.dart](../lib/main.dart) | Entry point: deep-link observer, the `App Opened` and `Install Attributed` events, Firebase and Google Sign-In initialisation, onboarding store load, `NotesApp`, the bootstrap error screen |
| [lib/firebase_options.dart](../lib/firebase_options.dart) | Hand-written Firebase options for Android and iOS |
| [lib/providers.dart](../lib/providers.dart) | Every Riverpod provider and all six controllers |
| [lib/models/note.dart](../lib/models/note.dart) | The `Note` model and its Firestore mapping |
| [lib/services/auth_service.dart](../lib/services/auth_service.dart) | Google sign-in and sign-out |
| [lib/services/notes_repository.dart](../lib/services/notes_repository.dart) | Firestore reads and writes for notes |
| [lib/models/onboarding.dart](../lib/models/onboarding.dart) | `OnboardingState`, `OnboardingStage` |
| [lib/models/remote_config.dart](../lib/models/remote_config.dart) | `RemoteConfig`: the backend's name, logo, colour, paywall text, prices and maintenance message, with defaults and parsing |
| [lib/models/install_source.dart](../lib/models/install_source.dart) | `InstallSource`: the campaign fields of the Play install referrer, for analytics |
| [lib/services/analytics.dart](../lib/services/analytics.dart) | `Analytics`, one method per event, and the method-channel client behind it |
| [lib/supabase_options.dart](../lib/supabase_options.dart) | Supabase URL and anon key, from `--dart-define` |
| [lib/services/install_referrer_service.dart](../lib/services/install_referrer_service.dart) | Reads the Play Store install referrer; referrer marker constants |
| [lib/services/evos_backend.dart](../lib/services/evos_backend.dart) | `EvosBackend`: phone sign-in, settings, subscription status and the payment functions on Supabase, plus the test-mode stand-in |
| [lib/services/deep_link_service.dart](../lib/services/deep_link_service.dart) | Receives deep links; link host and path constants |
| [lib/services/onboarding_store.dart](../lib/services/onboarding_store.dart) | The onboarding stage, phone session and last settings, on the device |
| [lib/services/payment_gateway.dart](../lib/services/payment_gateway.dart) | `PaymentGateway` interface, the Cashfree UPI AutoPay implementation and the simulated one |
| [lib/screens/](../lib/screens/) | `AppGate`, `AuthGate`, sign-in, notes list, editor, profile |
| [lib/screens/onboarding/](../lib/screens/onboarding/) | Mobile number, code, paywall, maintenance |
| [lib/widgets/brand.dart](../lib/widgets/brand.dart) | `BrandShell`, `BrandLogo`, `BrandHeader`: the backend's name, colour and logo, applied to the onboarding interface only |
| [lib/widgets/note_tile.dart](../lib/widgets/note_tile.dart) | One row of the notes list |
| [lib/widgets/track_view.dart](../lib/widgets/track_view.dart) | `TrackView`: reports a screen view once, for screens that are stateless |
| [lib/utils/errors.dart](../lib/utils/errors.dart) | `describeError`: maps any thrown object to a user-facing `AppFailure`. `errorCode`: a short name for the same error, for analytics |
| [android/.../notes/analytics/](../android/app/src/main/kotlin/com/spacewire/notes/analytics/) | Kotlin: `AnalyticsChannel`, `MixpanelSdk`, `MetaSdk` |
| [android/.../notes/payments/](../android/app/src/main/kotlin/com/spacewire/notes/payments/) | Kotlin: `PaymentsChannel`, the Cashfree SDK and the list of installed UPI apps |
| [supabase/](../supabase/) | The onboarding backend: one migration and four edge functions. Not deployed |
| [lib/utils/format.dart](../lib/utils/format.dart) | `formatNoteTime`: relative time for list rows |
| [lib/utils/validators.dart](../lib/utils/validators.dart) | The Indian mobile-number rule for the sign-in screen |

## Providers

All providers are declared by hand in [providers.dart](../lib/providers.dart). There is no code generation.

```mermaid
flowchart LR
    firebaseAuthProvider --> authServiceProvider --> authStateProvider --> currentUserProvider --> currentUidProvider
    firestoreProvider --> notesRepositoryProvider
    currentUidProvider --> notesStreamProvider
    notesRepositoryProvider --> notesStreamProvider
    authServiceProvider -.read.-> signInControllerProvider
    currentUidProvider -.read.-> noteActionsProvider
    notesRepositoryProvider -.read.-> noteActionsProvider
```

| Provider | Type | Role |
|----------|------|------|
| `analyticsProvider` | `Provider<Analytics>` | Mixpanel and the Facebook SDK. Read by the controllers and by screens for view events. Override point for tests. |
| `firebaseAuthProvider` | `Provider<FirebaseAuth>` | The `FirebaseAuth` instance. Override point for tests. |
| `authServiceProvider` | `Provider<AuthService>` | Auth operations |
| `authStateProvider` | `StreamProvider<User?>` | Firebase's auth state stream. Drives `AuthGate`. |
| `currentUserProvider` | `Provider<User?>` | The signed-in user, or null while loading, on error, or signed out |
| `currentUidProvider` | `Provider<String?>` | The user's ID, or null |
| `signInControllerProvider` | `AsyncNotifierProvider<SignInController, SignInState>` | Runs sign-in and sign-out; drives button spinners and error banners |
| `firestoreProvider` | `Provider<FirebaseFirestore>` | The Firestore instance. Override point for tests. |
| `notesRepositoryProvider` | `Provider<NotesRepository>` | Notes data access |
| `notesStreamProvider` | `StreamProvider<List<Note>>` | The live notes list for the current user; an empty list when signed out |
| `noteActionsProvider` | `AsyncNotifierProvider<NoteActions, void>` | Save, delete and restore; holds only loading/error status |
| `deepLinkServiceProvider` | `Provider<DeepLinkService>` | Overridden in `main()` with the instance already observing |
| `onboardingStoreProvider` | `Provider<OnboardingStore>` | Overridden in `main()` with the store loaded before `runApp` |
| `installReferrerProvider` | `Provider<String?>` | The Play install referrer. Null except on the first launch, when `main()` overrides it. |
| `evosBackendProvider` | `Provider<EvosBackend>` | Supabase when configured; otherwise a stand-in that only works in debug builds (test mode). Override point for tests. |
| `remoteConfigProvider` | `NotifierProvider<RemoteConfigController, RemoteConfig>` | The backend's settings. Starts from the copy saved on the device; `refresh()` replaces it. |
| `phoneAuthControllerProvider` | `NotifierProvider<PhoneAuthController, PhoneAuthState>` | Sends and checks the sign-in code. Its `phone` being set is what shows the code screen. |
| `paymentGatewayProvider` | `Provider<PaymentGateway>` | Cashfree when Supabase is configured; otherwise simulated |
| `upiAppsProvider` | `FutureProvider<List<UpiApp>>` | The UPI apps installed on the phone |
| `onboardingControllerProvider` | `NotifierProvider<OnboardingController, OnboardingState>` | Which interface and stage to show; persists every change; `refresh()` asks the server who has paid. Drives `AppGate`. |
| `purchaseControllerProvider` | `AsyncNotifierProvider<PurchaseController, void>` | Starts the subscription; holds only loading/error status |

The two providers overridden in `main()` throw `UnimplementedError` if read without the override. Tests must override them.

### Design decisions worth knowing

- **Reads and writes are separate.** Note data always comes from `notesStreamProvider`. `noteActionsProvider` never holds notes; it only reports whether the last write is running or failed.
- **The user ID is passed per call.** `NotesRepository` methods take `uid` as an argument and the repository holds no user state, so it can never be alive in a signed-out state.
- **Navigation follows state.** Controllers never navigate. `AuthGate` watches `authStateProvider` and swaps sign-in for the notes list; `AppGate` watches the onboarding stage and swaps the whole interface. Onboarding stages are swapped at the root, not pushed as routes, so the stage and the screen cannot disagree.
- **`MaterialApp` has no `home`.** It uses `onGenerateInitialRoutes` so that a cold-start deep link is not pushed as a named route. See [09-deep-link-onboarding.md](09-deep-link-onboarding.md#receiving-the-direct-link).
- **A cancelled sign-in is data, not an error.** `SignInController` catches `SignInCanceled` and increments `SignInState.consecutiveCancels`. That count drives the "signing certificate is probably not registered" hint.
- **`notesStreamProvider` overrides Riverpod's retry.** Riverpod 3 retries failed providers by default. The override stops retrying on `permission-denied` and `unauthenticated`, which would otherwise show a spinner for about 30 seconds after sign-out.
- **`currentUserProvider` reads `.value`.** This returns null during loading and error, so no exception from the auth stream reaches the providers below it.
- **Firestore writes are optimistic and not awaited by the UI.** A Firestore write future completes only when the server acknowledges it, which offline means on reconnect. Screens pop first and report failure later through a snackbar. See [03-app-flow.md](03-app-flow.md#saving-a-note).
- **Analytics is never awaited and cannot fail.** `Analytics` methods return nothing, and the channel client swallows every error. Note writes are reported when issued, not when the server confirms them.
- **Identity follows the auth stream; the reset does not.** `AuthGate` identifies the person whenever a user ID appears, which covers a restart with a live session. The reset happens in `SignInController.signOut`, because the stream's value is also null while it is loading or in error.
- **The server decides who has paid.** The stage on the device is only what to show first. `OnboardingController.refresh()` asks Supabase at start, when the paywall returns to the front and on "Check again", and never throws: offline, the stage stays as it was.
- **The onboarding theme is scoped.** `BrandShell` wraps only the onboarding screens in a `Theme` and a `Title`, so the backend's colour and name never reach the notes app.
- **Supabase calls are awaited.** There is no offline cache, so a screen shows a busy state until the server answers.

## Import rules

The intent, stated in the service files, is that Firebase packages stay behind the service layer.

| Package | Intended to be imported only by | Also imported today by |
|---------|--------------------------------|------------------------|
| `google_sign_in` | [auth_service.dart](../lib/services/auth_service.dart) | [errors.dart](../lib/utils/errors.dart), to map `GoogleSignInException` |
| `cloud_firestore` | [notes_repository.dart](../lib/services/notes_repository.dart) | [note.dart](../lib/models/note.dart) for `Timestamp` and `DocumentSnapshot`; [providers.dart](../lib/providers.dart) for the instance and `FirebaseException` |
| `firebase_auth` | services and providers | [auth_gate.dart](../lib/screens/auth_gate.dart), [profile_screen.dart](../lib/screens/profile_screen.dart), [errors.dart](../lib/utils/errors.dart), for the `User` and exception types |
| `shared_preferences` | [onboarding_store.dart](../lib/services/onboarding_store.dart) | Nothing else |
| `supabase` | [evos_backend.dart](../lib/services/evos_backend.dart) | Nothing else |

For new code: screens and widgets must not call `FirebaseAuth`, `FirebaseFirestore` or `GoogleSignIn` directly. They go through providers.

## Error handling

Every error shown to a user passes through `describeError` in [errors.dart](../lib/utils/errors.dart). It unwraps Riverpod's `ProviderException`, then maps `SignInCanceled`, `BackendFailure`, `PaymentFailure`, `GoogleSignInException`, `FirebaseAuthException`, `FirebaseException` and `StateError` to an `AppFailure` with a message and an optional hint. Anything else becomes "Something went wrong."

A failure during startup is shown by `_BootstrapErrorApp` in [main.dart](../lib/main.dart) instead of a blank screen.

## Testing

There are two kinds of test.

- **Unit tests.** [widget_test.dart](../test/widget_test.dart) has 8 tests on `Note.displayTitle`, `Note.sortKey` and `formatNoteTime`. [onboarding_logic_test.dart](../test/onboarding_logic_test.dart) has 22 on link and referrer matching, stage encoding, the mobile-number rule and `RemoteConfig` parsing. [analytics_test.dart](../test/analytics_test.dart) has 13 on `InstallSource.parse` and on which calls `Analytics` makes.
- **Widget tests.** [onboarding_flow_test.dart](../test/onboarding_flow_test.dart) has 42 tests that pump the real `NotesApp`. Firebase is never initialised: `authStateProvider` is overridden with a signed-out stream, which is the only Firebase-backed provider the signed-out path reads. Supabase and Cashfree are replaced by the fakes in [support/harness.dart](../test/support/harness.dart). [analytics_test.dart](../test/analytics_test.dart) has 12 more that pump it with a recording `AnalyticsClient` and check the events sent. The signed-in notes screens have no widget tests.
- **End-to-end flows.** Seven Maestro flows in `.maestro/` drive the installed app. See [08-e2e-testing.md](08-e2e-testing.md).

Controls with no visible text carry a `Semantics(identifier: ...)` so the flows can select them. The identifiers are listed in [08-e2e-testing.md](08-e2e-testing.md#how-the-flows-are-written).
