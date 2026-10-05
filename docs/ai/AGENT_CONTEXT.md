# Agent context

Condensed, current facts about this project for AI coding agents. The full docs are in [docs/](../README.md); read the relevant one before a non-trivial change.

Last verified against the code: 2026-10-05.

## What this is

A Flutter notes app. Google sign-in through Firebase Auth, notes stored per user in Cloud Firestore, state in Riverpod 3. Android and iOS are configured; web and desktop are not.

The app has two interfaces, chosen by the root widget `AppGate`:

- **Normal:** `AuthGate` → sign-in or the notes list. This is what every user gets by default.
- **Onboarding:** details form → paywall → member home. Shown when the app was installed from a Play Store link whose referrer contains `flow=onboarding`, or when a link is opened: `notes://onboarding` (debug builds only, the one to test with) or `https://notes-f36b3.web.app/onboarding`. Remembered across restarts, with no way back to notes by decision. No sign-in, no Firebase. The form is saved to Supabase; payment is simulated. Details: [09-deep-link-onboarding.md](../09-deep-link-onboarding.md).

## Commands

```sh
flutter pub get
flutter analyze            # must report no issues
flutter test               # 46 tests, all must pass
flutter build apk --debug  # verified working 2026-10-01
flutter build apk          # release, verified working 2026-10-05
flutter run
./tool/maestro.sh test .maestro                 # end-to-end flows; needs a device with the app installed
./tool/maestro.sh check-syntax <flow.yaml>      # no device needed
./tool/deeplink.sh --check                      # proves the deep link works on the connected phone
./tool/deeplink.sh --fresh | --reset            # open the local link from a clean state | back to the normal app
```

Always run Maestro through `tool/maestro.sh`. A bare `maestro` or `java` fails on this machine.

## Where things are

| Need | File |
|------|------|
| Startup, theme | `lib/main.dart` |
| All providers and controllers | `lib/providers.dart` |
| Note model | `lib/models/note.dart` |
| Google sign-in, sign-out | `lib/services/auth_service.dart` |
| Firestore reads and writes | `lib/services/notes_repository.dart` |
| Root widget, interface switch | `lib/screens/app_gate.dart` |
| Notes screens | `lib/screens/` (`auth_gate`, `sign_in_screen`, `notes_list_screen`, `note_editor_screen`, `profile_screen`) |
| Onboarding screens | `lib/screens/onboarding/` (`details_form_screen`, `paywall_screen`, `member_home_screen`) |
| Play install referrer | `lib/services/install_referrer_service.dart`, `android/app/src/main/kotlin/com/spacewire/notes/MainActivity.kt` |
| Supabase save of the form | `lib/services/leads_repository.dart`, `lib/supabase_options.dart` |
| Deep link receiving, link host and path | `lib/services/deep_link_service.dart` |
| Onboarding state model and device storage | `lib/models/onboarding.dart`, `lib/services/onboarding_store.dart` |
| Payment interface and simulated gateway | `lib/services/payment_gateway.dart` |
| Form validators | `lib/utils/validators.dart` |
| Error-to-message mapping | `lib/utils/errors.dart` |
| Relative time formatting | `lib/utils/format.dart` |
| Security rules | `firestore.rules` |
| End-to-end flows | `.maestro/flows/`, shared steps in `.maestro/subflows/`, order in `.maestro/config.yaml` |
| Firebase options | `lib/firebase_options.dart` (hand-written) |

## Rules that will break things if ignored

1. **Firestore timestamps must be `FieldValue.serverTimestamp()`.** The security rules reject client clocks with `permission-denied`.
2. **A note document has exactly four fields:** `title`, `body`, `createdAt`, `updatedAt`. Adding a field means changing `firestore.rules` (`hasOnly` and `hasAll`), `Note`, and `NotesRepository` together, and the rules must then be published by hand in the Firebase console. Tell the user when rules need publishing; you cannot do it.
3. **Do not await Firestore writes before popping a screen.** The future completes only on server acknowledgement, so it hangs offline. Follow the `unawaited(...).then(...)` pattern in `note_editor_screen.dart`.
4. **Do not navigate on sign-in or sign-out.** `AuthGate` reacts to `authStateProvider`.
5. **`GoogleSignIn.instance.initialize` runs once, in `main()`.** Never call it again.
6. **`google_sign_in` is 7.x.** `account.authentication` is a synchronous getter, `authenticate()` throws on cancel instead of returning null, and there is no `signIn()`.
7. **Riverpod is 3.x.** No `.valueOrNull`; `.value` is null on loading and error; providers retry on failure unless `retry:` is overridden; errors crossing providers arrive wrapped in `ProviderException`.
8. **FlutterFire versions are pinned exactly and move together** (`firebase_core`, `firebase_auth`, `cloud_firestore`). Do not change one alone or switch them to caret ranges.
9. **Do not add the `google-services` Gradle plugin or run `flutterfire configure`.** Configuration is in Dart on purpose.
10. **Screens do not call Firebase SDKs directly.** Go through providers.
11. **Maestro flows select on visible text and on `Semantics(identifier: ...)`.** Renaming a label, a button text or an identifier breaks flows. Search `.maestro/` first and update the flows in the same change. The identifiers are listed in [08-e2e-testing.md](../08-e2e-testing.md#how-the-flows-are-written).

12. **`DeepLinkService.start()` runs before `runApp`, and `MaterialApp` has no `home`.** Either change makes Flutter push incoming link URLs as named routes. Keep `onGenerateInitialRoutes` and `onGenerateRoute` in `main.dart`.
13. **The link host appears in two places that must match:** `kDeepLinkHost` in `deep_link_service.dart` and `android:host` in `AndroidManifest.xml`.
14. **`deepLinkServiceProvider` and `onboardingStoreProvider` throw unless overridden.** `main()` overrides them; any test that pumps `NotesApp` must too. Copy `_launch` in `test/onboarding_flow_test.dart`.
15. **Never navigate on an onboarding stage change.** `AppGate` renders from `onboardingControllerProvider`.
16. **Payment is simulated.** Do not describe it as real, and do not remove the "Test mode" notice while `isSimulated` is true. A real provider implements `PaymentGateway` and replaces `paymentGatewayProvider`.
17. **Supabase: pure-Dart `supabase` only, never `supabase_flutter`,** and only `leads_repository.dart` imports it. The table is insert-only for `anon`; do not add `.select()` to the insert or it fails. Await the save; do not copy the un-awaited Firestore pattern.
18. **The channel name `com.spacewire.notes/install_referrer` appears in both `MainActivity.kt` and `install_referrer_service.dart`** and must match.

## Code style

Explicit types on everything, `const` where possible, relative imports in `lib/`, comments that explain why. Providers are declared by hand, no code generation. User-facing errors go through `describeError`. Details: [06-conventions.md](../06-conventions.md).

## Current state

- `flutter analyze` clean, 46 of 46 tests passing, debug and release APKs build (2026-10-05). The release APK has not been installed or run.
- **Supabase is not configured.** No URL, key or table exists yet, so no form has ever really been saved. A debug build logs `[leads] Supabase is not configured` and continues; a release build blocks at the form. Do not report saving as working.
- **The Play Store referrer path has never run through Play.** It needs a build on a Play testing track. Do not report it as verified.
- Maestro 2.11.0 is installed in `~/.maestro`. `deeplink_local` and `onboarding_deeplink` pass on the test phone. The five notes flows are **blocked at Google sign-in** (the phone's only account is a managed one demanding a lock screen) and nothing after sign-in has run. Do not report them as passing.
- The onboarding member home is still a placeholder and iOS has no way in. Open items are in [07-known-issues.md](../07-known-issues.md#deep-link-onboarding). Ask before guessing.
- The test phone has the link domain approved for the app (a device setting). A device without that opens the link in a browser.
- iOS has never been built on this machine. CocoaPods is not installed; the project uses Swift Package Manager.
- Four suspected bugs are open and unconfirmed, the first being that log out leaves the Profile screen on a spinner. See [07-known-issues.md](../07-known-issues.md) before working on the editor, the list, or sign-out.
- Git: one commit on `main`. Commit only when asked, and branch first.

## Environment traps

- The Gradle wrapper download can time out on this network. The fix is in [05-setup-and-build.md](../05-setup-and-build.md#troubleshooting).
- There is no `java` on the PATH. The JDK is Android Studio's bundled one at `/Applications/Android Studio.app/Contents/jbr/Contents/Home`; Flutter finds it without help.
- The Flutter SDK at `~/flutter` is quarantined by macOS (unpacked from a Safari download). A release build failing with `gen_snapshot` exit code -9 or a missing `gen_snapshot` is this; the fix is in [05-setup-and-build.md](../05-setup-and-build.md#troubleshooting).
- Google sign-in on Android needs the machine's debug SHA-1 registered in Firebase. Without it, sign-in looks like a silent cancel.

## After every task

This is required, not optional.

1. Run `flutter analyze` and `flutter test`. If the change touches a screen, run `check-syntax` on the affected flows, and run them when a device is connected.
2. Add an entry at the top of [TASK_LOG.md](TASK_LOG.md).
3. Update the docs the change affects, using the table in [docs/README.md](../README.md#keeping-these-docs-current).
4. Correct this file if any statement in it stopped being true, and update the "Last verified" date.
5. Tell the user which docs you updated.
