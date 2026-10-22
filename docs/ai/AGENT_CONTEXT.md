# Agent context

Condensed, current facts about this project for AI coding agents. The full docs are in [docs/](../README.md); read the relevant one before a non-trivial change.

Last verified against the code: 2026-10-22.

## What this is

A Flutter notes app. Google sign-in through Firebase Auth, notes stored per user in Cloud Firestore, state in Riverpod 3. Android and iOS are configured; web and desktop are not.

The app has two interfaces, chosen by the root widget `AppGate`:

- **Normal:** `AuthGate` → sign-in or the notes list. This is what every user gets by default.
- **Onboarding (called Evos in the app):** mobile number → SMS code → paywall → "under maintenance". Shown when the app was installed from a Play Store link whose referrer contains `flow=onboarding`, or when a link is opened: `notes://onboarding` (debug builds only, the one to test with) or `https://notes-f36b3.web.app/onboarding`. Remembered across restarts, with no way back to notes by decision. No Firebase: phone sign-in, settings and the subscription are on Supabase, payment is Cashfree UPI AutoPay, and the name, logo, colour, paywall text and prices come from the backend's `app_config` table. Modelled on the sibling project `../cash_alert`. Details: [09-deep-link-onboarding.md](../09-deep-link-onboarding.md).

Both interfaces report to Mixpanel and the Facebook SDK, on Android only. Every event is listed in [10-analytics.md](../10-analytics.md).

## Commands

```sh
flutter pub get
flutter analyze            # must report no issues
flutter test               # 129 tests, all must pass
flutter build apk --debug  # verified working 2026-10-13
flutter build apk          # release, signed with the upload key, verified 2026-10-21
flutter build appbundle    # for Play; writes a signed .aab but exits with an error until cmdline-tools are installed
flutter run                              # talks to the real Evos Supabase project
flutter run --dart-define=SUPABASE_URL=  # test mode: no SMS, code 123456, simulated payment
./tool/maestro.sh test .maestro                 # end-to-end flows; needs a device with the app installed
./tool/maestro.sh check-syntax <flow.yaml>      # no device needed
./tool/setup_backend.sh check                   # read-only: what the Evos Supabase project has
./tool/deeplink.sh --check                      # proves the deep link works on the connected phone
./tool/deeplink.sh --fresh | --reset            # open the local link from a clean state | back to the normal app
```

Always run Maestro through `tool/maestro.sh`. A bare `maestro` or `java` fails on this machine.

## Where things are

| Need | File |
|------|------|
| Startup | `lib/main.dart` |
| Notes theme, brand colours, font (Poppins, bundled) | `lib/theme.dart`, `assets/fonts/` |
| Drawn logo, user avatar, note card | `lib/widgets/evos_mark.dart`, `user_avatar.dart`, `note_tile.dart` |
| All providers and controllers | `lib/providers.dart` |
| Note model | `lib/models/note.dart` |
| Google sign-in, sign-out | `lib/services/auth_service.dart` |
| Firestore reads and writes | `lib/services/notes_repository.dart` |
| Root widget, interface switch | `lib/screens/app_gate.dart` |
| Notes screens | `lib/screens/` (`auth_gate`, `sign_in_screen`, `notes_list_screen`, `note_editor_screen`, `profile_screen`) |
| Onboarding screens | `lib/screens/onboarding/` (`phone_screen`, `otp_screen`, `paywall_screen`, `maintenance_screen`) |
| Backend name, colour and logo on those screens | `lib/widgets/brand.dart`, `lib/models/remote_config.dart`, provider `remoteConfigProvider` (`remoteConfigSettledProvider`: whether it holds the backend's answer yet) |
| Paywall settings (every text, icon, the video card's shape) and the icon names | `RemoteConfig`, `kPaywallIcons` in `paywall_screen.dart`; the keys are in [09-deep-link-onboarding.md](../09-deep-link-onboarding.md#settings-the-app_config-table) |
| Play install referrer | `lib/services/install_referrer_service.dart`, `android/app/src/main/kotlin/com/spacewire/evos/MainActivity.kt` |
| Supabase: phone sign-in, settings, subscription status | `lib/services/evos_backend.dart`, `lib/supabase_options.dart` |
| Backend schema and edge functions (not deployed) | `supabase/migrations/`, `supabase/functions/` |
| Deep link receiving, link host and path | `lib/services/deep_link_service.dart` |
| Onboarding stage model and device storage (stage, session, settings) | `lib/models/onboarding.dart`, `lib/services/onboarding_store.dart` |
| Payment interface, Cashfree and simulated gateways | `lib/services/payment_gateway.dart`, `android/app/src/main/kotlin/com/spacewire/evos/payments/PaymentsChannel.kt` |
| Analytics events (all of them) | `lib/services/analytics.dart`, provider `analyticsProvider` |
| Mixpanel and Facebook SDK calls | `android/app/src/main/kotlin/com/spacewire/evos/analytics/` |
| Analytics keys | `android/app/src/main/res/values/analytics_keys.xml` |
| Install source for analytics | `lib/models/install_source.dart` |
| Screen-view helper | `lib/widgets/track_view.dart` |
| Mobile-number rule | `lib/utils/validators.dart` |
| Error-to-message mapping, error codes for analytics | `lib/utils/errors.dart` |
| Relative time formatting | `lib/utils/format.dart` |
| Security rules | `firestore.rules` |
| Test fakes for Supabase and Cashfree, and the app launch helper | `test/support/harness.dart` |
| Website for the link domain (assetlinks.json, fallback page), Firebase Hosting, not deployed | `web_links/`, `firebase.json`, `.firebaserc` |
| App icon (SVG source, PNG script, Android adaptive icon) | `tool/app_icon/`, `android/app/src/main/res/drawable/ic_launcher_*.xml`, `res/mipmap-anydpi-v26/` |
| End-to-end flows | `.maestro/flows/`, shared steps in `.maestro/subflows/`, order in `.maestro/config.yaml` |
| Firebase options | `lib/firebase_options.dart` (hand-written) |
| Public website: home, privacy, terms, delete data, contact, 404 (plain HTML, not uploaded), `.htaccess` | `website/` |

## Rules that will break things if ignored

1. **Firestore timestamps must be `FieldValue.serverTimestamp()`.** The security rules reject client clocks with `permission-denied`.
2. **A note document has exactly four fields:** `title`, `body`, `createdAt`, `updatedAt`. Adding a field means changing `firestore.rules` (`hasOnly` and `hasAll`), `Note`, and `NotesRepository` together, and the rules must then be published by hand in the Firebase console. Tell the user when rules need publishing; you cannot do it.
3. **Do not await Firestore writes before popping a screen.** The future completes only on server acknowledgement, so it hangs offline. Follow the `unawaited(...).then(...)` pattern in `note_editor_screen.dart`.
4. **Do not navigate on sign-in or sign-out.** `AuthGate` reacts to `authStateProvider`.
5. **`GoogleSignIn.instance.initialize` runs once, in `main()`.** Never call it again.
6. **`google_sign_in` is 7.x.** `account.authentication` is a synchronous getter, `authenticate()` throws on cancel instead of returning null, and there is no `signIn()`.
7. **Riverpod is 3.x.** No `.valueOrNull`; `.value` is null on loading and error; providers retry on failure unless `retry:` is overridden; errors crossing providers arrive wrapped in `ProviderException`.
8. **FlutterFire versions are pinned exactly and move together** (`firebase_core`, `firebase_auth`, `cloud_firestore`). Do not change one alone or switch them to caret ranges.
8a. **Never commit, print, move or regenerate `android/key.properties` or `android/app/upload-keystore.jks`.** They are the Play upload key (see [05-setup-and-build.md](../05-setup-and-build.md#release-signing)); a new key cannot update the published app.
9. **Do not add the `google-services` Gradle plugin or run `flutterfire configure`.** Configuration is in Dart on purpose.
10. **Screens do not call Firebase SDKs directly.** Go through providers.
11. **Maestro flows select on visible text and on `Semantics(identifier: ...)`.** Renaming a label, a button text or an identifier breaks flows. Search `.maestro/` first and update the flows in the same change. The identifiers are listed in [08-e2e-testing.md](../08-e2e-testing.md#how-the-flows-are-written). A tappable card merges its texts into one node: keep the note card's `Semantics(container: true)` wrappers.

12. **`DeepLinkService.start()` runs before `runApp`, and `MaterialApp` has no `home`.** Either change makes Flutter push incoming link URLs as named routes. Keep `onGenerateInitialRoutes` and `onGenerateRoute` in `main.dart`.
13. **The link host appears in two places that must match:** `kDeepLinkHost` in `deep_link_service.dart` and `android:host` in `AndroidManifest.xml`.
14. **`deepLinkServiceProvider` and `onboardingStoreProvider` throw unless overridden.** `main()` overrides them; any test that pumps `NotesApp` must too, and must override `evosBackendProvider` and `paymentGatewayProvider` with fakes. Use `launch` in `test/support/harness.dart`.
15. **Never navigate on an onboarding stage change.** `AppGate` renders from `onboardingControllerProvider`.
16. **Payment is Cashfree when Supabase is configured, simulated otherwise.** Do not remove either "Test mode" notice (paywall, code screen). Never remove the AutoPay sentence on the paywall: it is the statement that money is taken every month. The backend may word it (`paywall_autopay_text`, owner's decision 2026-10-19), but a blank must keep falling back to the app's own and the prices must stay `{trial}`/`{recurring}` placeholders filled from the amount rows. The server, not the device, decides who has paid: never set the maintenance stage from anything but `signedIn`, `subscribed` or `refresh`.
17. **Supabase: pure-Dart `supabase` only, never `supabase_flutter`,** and only `evos_backend.dart` imports it. The session is saved by hand in `OnboardingStore`; keep the `onAuthStateChange` listener that does it. Await Supabase calls; do not copy the un-awaited Firestore pattern.
17a. **The Cashfree id and secret never reach the app.** They are private `app_config` rows read by edge functions. Never mark them `is_public`, never add them to `RemoteConfig`, and never add a write policy for `anon` or `authenticated` on any table.
17d. **SMS settings are `app_config` rows** (`fast2sms`, `fast2sms_dlt_sender_id`, `fast2sms_dlt_te_id`, `send_sms_hook_secret`), all private, with function secrets only as a fallback. The owner keeps CashAlert's the same way; `../cash_alert`'s repository shows secrets instead and may be behind what is deployed.
17b. **Do not deploy edge functions, push migrations, or edit `app_config` without the user's explicit go-ahead.** They act on a live project that takes payments.
17c. **`cashfree_environment` must be the exact word `production` to take real money,** in both `app_config.ts` and `PaymentsChannel.kt`. Keep that default-to-sandbox rule.
18. **The channel name `com.spacewire.evos/install_referrer` appears in both `MainActivity.kt` and `install_referrer_service.dart`** and must match. The same holds for `com.spacewire.evos/analytics` in `AnalyticsChannel.kt` and `analytics.dart`, and for `com.spacewire.evos/payments` in `PaymentsChannel.kt` and `payment_gateway.dart`. The UPI packages in `PaymentsChannel.kt` must each be listed under `<queries>` in `AndroidManifest.xml`.
19. **Every analytics event is a method on `Analytics`,** and adding, renaming or removing one means updating [10-analytics.md](../10-analytics.md) in the same change. Never send note content, a phone number or a sign-in code; send `errorCode(error)`, never an error message. Never await analytics or call it from `build`.
20. **Never send a simulated payment to Facebook as a purchase.** `Analytics.subscriptionSucceeded` skips `metaSubscribe` when `simulated` is true; keep that.
21. **Do not put another app's Mixpanel token or Facebook keys in `analytics_keys.xml`,** and do not remove the two `false` Facebook entries in `AndroidManifest.xml`: they keep an unconfigured build from contacting Facebook.
22. **Mixpanel, the Facebook SDK and the Cashfree SDK are Gradle dependencies used from Kotlin.** Do not add `mixpanel_flutter`, `facebook_app_events` or `flutter_cashfree_pg_sdk`.
23. **Do not run `dart format` on existing files.** They are not formatter-clean, and it rewrites hundreds of unrelated lines.
24. **The paywall shows no rating, subscriber count or social-proof line unless the backend sends one.** Do not hard-code any.
25. **The public website (`website/`) shows the notes app only.** Never name, link or describe the onboarding interface, its link or its referrer there, and never add `flow` to the Play button's referrer. The legal pages are the exception that must stay complete: the privacy policy lists every kind of data collected and every processor (including mobile number, SMS, Supabase and Cashfree), because Play and the law require it. Update it when data collection changes.
26. **After changing a CSS or JS file in `website/`, change the `?v=` value on its links in every page** (one date, `YYYYMMDD`, for the whole site). Hostinger's CDN otherwise keeps serving the old copy. Never rename the files instead. Details: [05-setup-and-build.md](../05-setup-and-build.md#website-upload-hostinger).

## Code style

Explicit types on everything, `const` where possible, relative imports in `lib/`, comments that explain why. Providers are declared by hand, no code generation. User-facing errors go through `describeError`. Details: [06-conventions.md](../06-conventions.md).

## Current state

- 129 of 129 tests passing (2026-10-22). Version `1.0.1+2` built as a signed `.aab` on 2026-10-22 for Play, not yet uploaded. `flutter analyze` reports no issues. Debug and release APKs build as `com.spacewire.evos` (2026-10-19). The release APK was installed and run on the test phone on 2026-10-14: it opened from the HTTPS link, kept its phone sign-in across a force-stop, and showed the paywall.
- **Onboarding sign-in works against the live backend; payment does not yet.** Supabase project `sqvlgiqypqvjykczuhgz` is the default in `lib/supabase_options.dart`. On 2026-10-13 a real SMS code was sent and verified from the test phone and the paywall shown. The Cashfree rows of `app_config` and `customer_email_domain` are empty and no Cashfree function has handled a request, so do not report payment as working. `supabase db push` and `functions deploy` were allowed by the permission system; `config push` (auth settings) was refused. The Supabase CLI is at `~/.local/bin/supabase` (not on the PATH); listing another project's secrets was refused too. Never edit an applied migration: add a new timestamped file. Deno is not installed. Do not report sign-in, settings, or payment as working against a server.
- **Only test mode has run end to end.** A debug build made with `--dart-define=SUPABASE_URL=` (empty) accepts any number with the code `123456` and simulates the payment. A normal build talks to the real project and sends a real SMS. The Cashfree sheet has never been opened from this app.
- **Never run `onboarding_deeplink` or type a made-up number into a normal build:** it would text a real stranger. Use a test-mode build, or a number the user owns.
- **Analytics has real keys since 2026-10-21** (Facebook app "evos", `2015134735846694`). On a test-mode debug build, Mixpanel and Facebook accepted every onboarding event, `identify`, the reset, the install and app open (logcat: `status: 1` and `success: true`). Nobody has looked inside the Mixpanel or Events Manager dashboards yet. Not run: the sign-in and notes events (Google sign-in is broken), `metaCompleteRegistration` (needs a new user), and a real purchase. Debug builds report to the same project and app as release.
- **The Play Store referrer link does not work on the live build (tested 2026-10-22).** Four fresh Play installs through `...&referrer=flow%3Donboarding` on the test phone all opened the notes app. The app read a referrer successfully and fast, and the Play build contains the code, so Play is not handing over `flow=onboarding`. Mixpanel showed Play's answer was empty. The phone's only Google account is a Workspace (managed) account, which one report blames. Version 1.0.1+2 retries an empty referrer on up to 5 launches and reports Play's raw answer in `Install Attributed`. Cause not found yet; see the 2026-10-22 entries in [TASK_LOG.md](TASK_LOG.md). Do not report it as working.
- Maestro 2.11.0 is installed in `~/.maestro`. `onboarding_deeplink` passed on the test phone on 2026-10-19 (test-mode build). `deeplink_local` passed on 2026-10-19 too. Maestro's on-device driver, which had stopped starting (`DeviceServerDiedException`), worked again on 2026-10-14. **Google sign-in is broken since the app id became `com.spacewire.evos` (2026-10-19)** until the owner registers that package with the debug SHA-1 in Firebase and the new Android `appId` goes into `firebase_options.dart` (the old one, `...:android:54dd28f91a2c80dce700e4`, belongs to `com.spacewire.notes`). Under the old id the notes flows `create_note`, `edit_note`, `delete_and_undo` and `empty_note_is_discarded` passed on 2026-10-14; `profile_logout` has never run. Do not report the notes flows as passing on the new id.
- **The test phone remembers the onboarding stage.** After any onboarding test, a plain launch opens "Welcome to Evos". Run `./tool/deeplink.sh --reset` before the notes flows.
- What is behind the paywall is not built (subscribers see the maintenance screen), and iOS has no way in. Open items are in [07-known-issues.md](../07-known-issues.md#deep-link-onboarding). Ask before guessing.
- The test phone has the link domain approved for the app (a device setting). A device without that opens the link in a browser.
- iOS has never been built on this machine. CocoaPods is not installed; the project uses Swift Package Manager.
- **The app id is `com.spacewire.evos`** (Android `applicationId` and Kotlin package, iOS/macOS bundle ids, Linux id, the three channel names, Maestro `appId`, `tool/deeplink.sh`, `assetlinks.json`, the website's Play links) and the Dart package is `evos`, since 2026-10-19. `android/app/google-services.json` still describes the old Firebase registration; replace it with the file Firebase gives for the new package. The iOS bundle id is not registered in Firebase either. The old `com.spacewire.notes` build was uninstalled from the test phone.
- **The paywall card no longer grows when the video loads, and every paywall text and icon is a backend setting** (2026-10-19). Migration `20261019120000_paywall_controls.sql` adding those rows was pushed on 2026-10-19 (owner's go-ahead); the rows hold the app's defaults, so nothing changed on screen.
- To show the paywall with real settings on a test-mode build, which fetches none, seed `flutter.evos_config_v1` in the app's `FlutterSharedPreferences.xml` with `run-as`: a failed fetch keeps what is saved.
- **The notes interface was restyled on 2026-10-14** (violet theme, Poppins, cards, drawn logo). Behaviour, texts and identifiers were kept.
- Four suspected bugs are open and unconfirmed, the first being that log out leaves the Profile screen on a spinner. See [07-known-issues.md](../07-known-issues.md) before working on the editor, the list, or sign-out.
- **The website in `website/` is written but not uploaded.** Every page uses `contact@spacewiretech.com` for support, privacy and deletion requests (since 2026-10-21). It has no domain yet. See [07-known-issues.md](../07-known-issues.md#website).
- Git: four commits; work is on the branch `deeplink_feature`. Commit only when asked, and branch first.

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
