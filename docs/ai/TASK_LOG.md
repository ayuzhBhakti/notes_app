# Task log

One entry per completed task, newest first. Keep entries short: what changed, why, how it was verified, and which docs were updated.

## Entry template

```
## YYYY-MM-DD — Short title

**Request:** what was asked.
**Changes:** files changed and what changed in them.
**Why:** the reason for the approach, if it is not obvious.
**Verified:** commands run and their result. Say so if something was not verified.
**Docs updated:** list of docs.
**Follow-ups:** anything left open, or "none".
```

---

## 2026-10-13 — Phone sign-in live; webhook ignores other apps' mandates

**Request:** finish and verify the OTP setup, then what is next.
**Changes:** the owner set the Send SMS hook (HTTPS, to `sms-hook`), saved its secret in `send_sms_hook_secret`, enabled the Phone provider (placeholder Twilio fields, needed for the form to save) and filled the three Fast2SMS rows with CashAlert's values. Code change: `cashfree-webhook` now ignores any subscription whose id does not start with `ev_`, and was redeployed.
**Why:** the owner intends to reuse CashAlert's credentials. If that includes its Cashfree account, CashAlert's subscription events would reach this webhook carrying CashAlert user ids, and recording a payment for a user that does not exist here would fail and make Cashfree retry.
**Verified:** read-only checks showed the hook secret set and phone sign-in on. The owner then signed in on the test phone with their own number; the app log shows `OTP Requested`, `identify`, `OTP Verified` (`new_user: true`), `Paywall Viewed`, and the phone holds the `paywall` stage and a session. Earlier checks that CashAlert's live project has an `sms-hook` function with a secret configured settled that it uses the hook too.
**Not verified:** anything to do with payment. The webhook change is deployed but has received no event.
**Docs updated:** 07-known-issues, 09-deep-link-onboarding, AGENT_CONTEXT.
**Follow-ups:** Cashfree rows, `customer_email_domain`, webhook URL in the Cashfree dashboard, package whitelisting; an Evos DLT template.

## 2026-10-13 — Evos backend: follow-up migration, live settings fetch confirmed

**Request:** the owner had run `./tool/setup_backend.sh deploy` and asked for the rest of the setup.
**Changes:** new `supabase/migrations/20261013130000_sms_config_rows.sql` (the four private SMS rows, `ON CONFLICT DO NOTHING`), because the first migration may have been applied before those rows were added to it. Applied with `supabase db push`. `sms-hook` redeployed so the live copy is the one that reads `app_config`.
**Verified:**
- `./tool/setup_backend.sh check`: both tables exist, four functions deployed, phone sign-in still off.
- With the publishable key: 17 public rows readable, none of the private ones.
- Normal debug build on the test phone, opened by `notes://onboarding`: the app fetched those rows from the live project and saved them (`evos_config_v1`).
**Not done, and why:** enabling Phone sign-in and the Send SMS hook (`supabase config push` was refused by the permission system; it is dashboard work for the owner). Filling `fast2sms`, `fast2sms_dlt_sender_id`, `fast2sms_dlt_te_id` (the values are in CashAlert's table, which could not be read from here), `send_sms_hook_secret`, the Cashfree rows and `customer_email_domain`. No SMS has been sent.
**Docs updated:** 07-known-issues, 09-deep-link-onboarding, AGENT_CONTEXT.
**Follow-ups:** the three dashboard steps, then a sign-in test with the owner's own number.

## 2026-10-13 — SMS settings moved to `app_config`, as the owner says CashAlert has them

**Request:** "in CashAlert only `fast2sms`, `fast2sms_dlt_sender_id`, `fast2sms_dlt_te_id` are used; check where you are making a mistake."
**Changes:** `supabase/functions/sms-hook/index.ts` now reads those three `app_config` rows, and `send_sms_hook_secret`, falling back to the function secrets it used before. The four rows are added, private, to the migration. `supabase/functions/.env` (placeholders only when written) was deleted and `.env.example` marked optional; `tool/setup_backend.sh` now tells the owner to fill the rows.
**Why:** the earlier setup copied CashAlert's repository, whose `sms-hook` reads function secrets (`FAST2SMS_API_KEY`, `FAST2SMS_SENDER_ID`, `FAST2SMS_MESSAGE_ID`) and never reads those rows; they are only seeded, empty, by a migration. The owner says the rows are what is in use, so the deployed CashAlert function may differ from its repository. That could not be checked from here. Reading the rows first and the secrets second works either way.
**Verified:** nothing run. The function is not deployed or type-checked. `flutter analyze` clean (no Dart changed).
**Not known:** whether `fast2sms_dlt_te_id` in CashAlert holds a short Fast2SMS message id (what the `dlt` route's `message` field takes, like `207706`) or a long DLT template id (which needs the `dlt_manual` route and the message text). The function sends it as `message` on the `dlt` route, as CashAlert's repository does.
**Docs updated:** 09-deep-link-onboarding, AGENT_CONTEXT.
**Follow-ups:** owner confirms which kind of id that row holds; deploy.

## 2026-10-13 — App pointed at the Evos Supabase project

**Request:** the Supabase project URL and publishable key were supplied, with "now you can proceed".
**Changes:**
- `lib/supabase_options.dart`: the project (`sqvlgiqypqvjykczuhgz`) and its publishable key are now the defaults; `--dart-define` still overrides, and an empty `SUPABASE_URL` switches the backend off (test mode in debug).
- `phone_screen.dart`: shows "Test mode: no SMS is sent." in test mode. `onboarding_deeplink.yaml` asserts it before "Send code", so the flow cannot text a real number on a normal build.
- `evos_backend.dart`: phone sign-in being off, or an SMS that could not be sent, is now a server error to the user, not "enter a valid number".
**Why:** defaults rather than build flags, so a plain build works once the backend is live. The publishable key is safe to commit; no secret was added.
**Verified:** read-only requests with the publishable key showed the project reachable and empty: `app_config` and `profiles` missing, all four functions 404, phone provider off. `flutter analyze` clean, 97 of 97 tests. A test-mode debug build was installed on the test phone. **The two Maestro flows were not re-run after the test-mode notice and its assertion were added:** Maestro's on-device driver would not start (`DeviceServerDiedException`), first hanging at driver install. Both flows had passed earlier the same day, before that change.
**Also added, for the OTP request that followed ("the same credentials as CashAlert"):** `tool/setup_backend.sh` (`deploy`, `secrets`, `check`), a git-ignored `supabase/functions/.env` with CashAlert's sender id and template id from its `.env.example`, and `.env` rules in `.gitignore`.
**Not done:** nothing is deployed. Deploying to the project and listing CashAlert's secrets were both refused by the permission system. The Fast2SMS API key could not have been copied anyway: Supabase never shows a saved secret again.
**Docs updated:** 05-setup-and-build, 07-known-issues, 08-e2e-testing, 09-deep-link-onboarding, AGENT_CONTEXT.
**Follow-ups:** the owner runs `./tool/setup_backend.sh deploy`, sets the SMS hook and phone provider in the dashboard, fills the two blank secrets and runs `secrets`; re-run the two Maestro flows once the driver starts again.

## 2026-10-13 — Onboarding rebuilt as Evos: phone sign-in, Cashfree AutoPay paywall, maintenance, backend-managed brand

**Request:** keep the normal app as it is; for users who arrive by the deep link, replace the details form with sign-in by mobile number and OTP (separate number and code screens), then a paywall, then an "under maintenance" screen. App name (Evos), theme, logo and the paywall's plan and Cashfree details are managed by the backend. Follow-up answers: Supabase as the backend like the other apps, auto-renewing payment and paywall layout the same as CashAlert, drop the details form.
**Changes:**
- Screens: new `phone_screen`, `otp_screen`, `maintenance_screen`; `paywall_screen` rewritten in CashAlert's layout; `details_form_screen` and `member_home_screen` deleted. `app_gate.dart` wraps the interface in the new `BrandShell` (`lib/widgets/brand.dart`), which applies the backend's colour and name to it alone.
- State: stages are now `inactive`, `signIn`, `paywall`, `maintenance`. New `RemoteConfigController`, `PhoneAuthController`; `OnboardingController.refresh()` asks the server who has paid; `PurchaseController` starts a subscription. `DetailsSubmitController` removed.
- Services: new `evos_backend.dart` (Supabase phone OTP, settings, status, the two payment functions, hand-kept session, and a debug-only test-mode stand-in) replaces `leads_repository.dart`. `payment_gateway.dart` gained `CashfreePaymentGateway`. New `models/remote_config.dart`. `onboarding_store.dart` also keeps the session and the last settings. `validators.dart` is now only the Indian mobile rule.
- Android: new `payments/PaymentsChannel.kt` (Cashfree SDK 2.4.0, UPI Intent subscription, installed UPI apps), registered from `MainActivity`; three Cashfree Gradle dependencies; four UPI packages under `<queries>`.
- Backend, new `supabase/`: migration for `app_config` (with `is_public`), `profiles`, `subscription_payments`, `has_active_subscription()`; edge functions `sms-hook`, `create-cashfree-subscription`, `verify-cashfree-subscription`, `cashfree-webhook`, adapted from `../cash_alert/supabase`.
- Analytics: details-form, plan and member-home events removed; phone, code, UPI-app and maintenance events added (29 events). Identify by Supabase user id on a verified code.
- Tests: all three onboarding test files rewritten around `test/support/harness.dart` (97 tests). Maestro: `deeplink_local` and `onboarding_deeplink` updated.
**Why:**
- The Cashfree id and secret stay on the server, although the request listed them among what the backend sends for the payment screen: anything the app can read can be taken out of the APK. The app gets a single-use session id.
- A separate Supabase project from CashAlert is assumed, so a CashAlert subscriber is not automatically an Evos subscriber.
- The paywall shows a rating or social-proof line only if the backend sends one, and the pill shows the trial price instead of "FREE": the app should not state a rating it does not have, or call a charged trial free. The AutoPay sentence is fixed in the app.
- The Cashfree SDK is used from Kotlin over a channel, as the analytics SDKs are, and because CashAlert's working code is Kotlin.
**Verified:**
- `flutter analyze`: no issues. `flutter test`: 97 of 97.
- `flutter build apk --debug` and `flutter build apk`: both built.
- On the test phone (SM-M127G, Android 13), debug build, test mode: `deeplink_local` and `onboarding_deeplink` passed, and each screen was looked at in a screenshot.
- **Not verified:** anything against a real Supabase project (none exists), the SQL and edge functions (not applied, deployed or type-checked), a real SMS, a real or sandbox Cashfree payment, a backend-supplied logo or picture, the release APK on a device, the Play referrer.
**Docs updated:** 01-overview, 02-architecture, 03-app-flow, 04-data-model, 05-setup-and-build, 06-conventions, 07-known-issues, 08-e2e-testing, 09-deep-link-onboarding (rewritten), 10-analytics, README, AGENT_CONTEXT.
**Follow-ups:** create the Supabase project and follow "Setting up the backend" in 09; DLT sender and template for Evos; Cashfree sandbox credentials and package whitelisting; set `customer_email_domain`; confirm the separate-project and no-invented-social-proof choices with the product owner; decide on a preview video and SMS auto-read; what is behind the paywall.

## 2026-10-13 — Mixpanel events and the Facebook SDK

**Request:** add all the Mixpanel events and the Facebook analytics SDK, like the other apps (`cash_alert` was the model).
**Changes:**
- New `lib/services/analytics.dart` (`Analytics`, one method per event; `AnalyticsClient` and its method-channel implementation), `lib/models/install_source.dart` (campaign fields of the Play referrer), `lib/widgets/track_view.dart` (one view event per stateless screen), `analyticsProvider`.
- New Kotlin in `android/.../notes/analytics/`: `AnalyticsChannel`, `MixpanelSdk`, `MetaSdk`. Registered from `MainActivity`. Gradle: `mixpanel-android` 8.2.4, `facebook-core` 18.3.0. Manifest: the Facebook app ID and client token, with auto-init and auto-logging off. Keys in the new `res/values/analytics_keys.xml`, all placeholders.
- 27 Mixpanel events called from `main()`, the five controllers in `providers.dart`, and the seven screens. Identify in `AuthGate`, reset in `SignInController.signOut`. Facebook: registration, initiated checkout, and purchase plus subscribe for real payments only.
- `AuthService.signInWithGoogle` returns whether the account is new. `Plan` gained `amount` and `currencyCode`. `errors.dart` gained `errorCode`.
- Tests: new `test/analytics_test.dart`, 19 tests (65 total).
**Why:**
- Native SDKs over a method channel, not `mixpanel_flutter` and `facebook_app_events`: it is how the install referrer is already read, it uses the same SDK versions as `cash_alert`, and it avoids two plugins that would have to build under Kotlin 2.4 and resolve under Swift Package Manager.
- The keys are placeholders because Notes needs its own Mixpanel project and Facebook app. `cash_alert`'s were not copied: its numbers would have been polluted.
- A simulated payment is not sent to Facebook as a purchase, because that event carries revenue.
- Onboarding users are not identified and nothing from the form is sent: they have no account, and the form is already in Supabase.
**Verified:** `flutter analyze` clean; `flutter test` 65 of 65; debug and release APKs build. On the test phone with placeholder keys: starts, both SDKs off, Facebook makes no request. With dummy keys: Maestro `onboarding_deeplink` passed and all ten events it reaches were queued by Mixpanel and accepted by the Facebook SDK (whose server refused the dummy app ID). The placeholders were put back afterwards. **Not verified:** anything arriving in a real Mixpanel project or Facebook app; the sign-in and notes events, `identify` and the reset, which need a Google sign-in the test phone cannot do; the release APK was not run.
**Docs updated:** new `10-analytics.md`; `README.md`, `01`, `02`, `03`, `05`, `06`, `07`, `09`, `AGENT_CONTEXT.md`.
**Follow-ups:** create the Mixpanel project and Facebook app and put the three keys in `analytics_keys.xml`; then check one run of each funnel inside Mixpanel and Events Manager. Decide on a consent screen. Answer Play's advertising-ID question as yes. iOS sends nothing.

## 2026-10-05 — Release APK build failed in gen_snapshot

**Request:** `flutter build apk` failed with `Dart snapshot generator failed with exit code -9`; find out why and fix it.
**Changes:** no project files. In the Flutter SDK cache, deleted the three `android-*-release/darwin-x64` folders and ran `flutter precache --android` to download them again.
**Why:** the SDK came from a zip downloaded with Safari, so its bundled binaries are quarantined. macOS killed the release `gen_snapshot` binaries and they were missing from the cache; only the licence file was left in each folder, which stopped Flutter from re-downloading. Fresh downloads are not quarantined, so no quarantine attribute had to be stripped.
**Verified:** `flutter build apk` built `app-release.apk` (55.2MB); `flutter analyze` clean; `flutter test` 46 of 46. **Not verified:** the APK was not installed or run, and `--profile` builds were not tried.
**Docs updated:** `05` (new troubleshooting entry), `AGENT_CONTEXT.md`.
**Follow-ups:** the rest of the SDK is still quarantined; the profile `gen_snapshot` binaries may fail the same way.

## 2026-10-01 — Local link to verify deep linking

**Request:** a local link to verify that deep linking works.
**Changes:**
- `android/app/src/debug/AndroidManifest.xml`: intent filter for `notes://onboarding`, debug builds only.
- `deep_link_service.dart`: `isOnboardingLink` accepts that link.
- New `tool/deeplink.sh` (`--check`, `--fresh`, `--reset`) and `.maestro/flows/deeplink_local.yaml`.
- `tool/maestro.sh`: for `test` runs, wakes and unlocks the device and holds it awake, restoring the setting on exit.
- Tests: 3 more (46 total).
**Why:**
- A custom scheme needs no domain verification, so it works on any device with no setup. It is debug-only because any app can claim a custom scheme.
- The wake/unlock step was added because the first run of the new check failed on a locked screen, the third time a locked phone has failed a run.
**Verified:** `flutter analyze` clean; `flutter test` 46 of 46; the built debug manifest contains the scheme. On the phone, `./tool/deeplink.sh --check` passed all four assertions (no link, link while running, restart, cold start), `./tool/deeplink.sh --fresh` opened the form (screenshot checked), and the stay-awake setting read 0 after the run. **Not verified:** that a release build ignores the link (follows from the manifest, not tested).
**Docs updated:** `09` (new "Verifying locally"), `08`, `05`, `02`, `AGENT_CONTEXT.md`.
**Follow-ups:** none new.

## 2026-10-01 — Onboarding: Play Store referrer and Supabase

**Request:** the link will be a Play Store link, testable without `assetlinks.json`; the form details are saved to Supabase; no exit to the notes app is intended.
**My reading:** "Play Store link" means the Play Install Referrer: the link carries `referrer=...`, the user installs, and the first launch starts onboarding. The marker `flow=onboarding` is my choice.
**Changes:**
- `MainActivity.kt`: method channel over Google's Install Referrer library; `app/build.gradle.kts`: the `installreferrer:2.2` dependency.
- New `services/install_referrer_service.dart`, `services/leads_repository.dart`, `supabase_options.dart`.
- `providers.dart`: `installReferrerProvider`, `leadsRepositoryProvider`, `DetailsSubmitController`; `OnboardingController` also starts on the referrer.
- `main.dart`: reads the referrer once, on first launch, before `runApp`.
- `details_form_screen.dart`: Continue awaits the save, with a spinner and an error message.
- `errors.dart`: `LeadSaveFailure`. `pubspec.yaml`: added `supabase`.
- `validators.dart`: upper length limits matching the Supabase column checks.
- Tests: 9 more (43 total).
**Why:**
- A native channel instead of a referrer plugin: about 40 lines, and third-party plugins in this project have broken under Kotlin Gradle Plugin 2.4.0 before.
- Pure-Dart `supabase` instead of `supabase_flutter`, whose deep-link plugin would compete with `DeepLinkService`.
- The table is insert-only for `anon`, so the shipped key cannot read anyone's details. The cost is that an edited form inserts a second row.
- The save is awaited, unlike Firestore writes, because Supabase has no offline cache.
- Credentials come from `--dart-define`; unconfigured debug builds continue with a log line so the flow stays testable, and release builds refuse.
- The direct HTTPS link was kept as the only way to exercise the flow on a device without Play.
**Verified:** `flutter analyze` clean; `flutter test` 43 of 43; debug APK builds. On the phone: the referrer channel answered on first launch (flag written), a sideloaded install showed the normal app, and `onboarding_deeplink` passed with the awaited save. **Not verified:** any real insert into Supabase (no project supplied); a real install through a Play referrer link (needs a Play testing track).
**Docs updated:** `09` (largely rewritten), `01`, `02`, `03`, `04`, `05`, `06`, `07`, `AGENT_CONTEXT.md`.
**Follow-ups:** Supabase URL and anon key, and run the table SQL; confirm the referrer marker; upload a build to Play internal testing to test the link; decide the member home.

## 2026-10-01 — Deep-link onboarding: details form and paywall

**Request:** a user arriving by deep link sees a new interface with a form (name, email, phone, address) and a paywall; everyone else gets the normal notes app.
**Decisions by the user:** simulated payment; HTTPS App Links; form and paywall before any sign-in; a separate interface after paying. **Defaults I chose, not confirmed:** the domain `notes-f36b3.web.app`, and a placeholder member home.
**Changes:**
- New: `models/onboarding.dart`, `services/deep_link_service.dart`, `services/onboarding_store.dart`, `services/payment_gateway.dart`, `utils/validators.dart`, `screens/app_gate.dart`, `screens/onboarding/` (three screens).
- `providers.dart`: five providers, `OnboardingController`, `PurchaseController`.
- `main.dart`: starts the link service before `runApp`, loads the store, and replaces `home` with `onGenerateInitialRoutes` + `onGenerateRoute`.
- `AndroidManifest.xml`: `autoVerify` intent filter for the link.
- `pubspec.yaml`: added `shared_preferences`.
- Tests: `onboarding_logic_test.dart` (12), `onboarding_flow_test.dart` (14). Maestro: `onboarding_deeplink.yaml`, first in `config.yaml`.
**Why:**
- No deep-link plugin: Flutter already delivers links through the initial route name and `didPushRouteInformation`. The cost is two ordering rules, documented in `09-deep-link-onboarding.md`.
- `shared_preferences` was added because the flow runs before any account exists, so there is no uid to store state under in Firestore.
- Stages are swapped at the root instead of pushed, the pattern `AuthGate` already uses.
- `home` was removed because Flutter asserts against combining it with `onGenerateInitialRoutes`; my first attempt kept both and failed every widget test.
**Verified:** `flutter analyze` clean; `flutter test` 34 of 34; debug APK builds and the built manifest contains the link filter. On the phone (SM-M127G, Android 13), `onboarding_deeplink` passed: the real link opened the form, then validation, paywall, back, plan change, purchase, member home, restart. A normal launch afterwards showed the sign-in screen. **Not verified:** iOS; a link arriving while a notes editor is open on a device (covered only by the route-popping code path, not by a test); the link opening without the per-device approval, which needs `assetlinks.json` hosted.
**Device changes:** approved `notes-f36b3.web.app` for the app on the test phone with `pm set-app-links-user-selection`. "Stay awake" was turned on for the runs and turned back off.
**Docs updated:** new `09-deep-link-onboarding.md`; `README.md` index and table; `01`, `02`, `03`, `04`, `05`, `06`, `07`, `08`; `AGENT_CONTEXT.md`; root `README.md`.
**Follow-ups:** the open items in `07-known-issues.md` under "Deep-link onboarding", the member home and the upload of details above all.

## 2026-10-01 — First Maestro run on a device

**Request:** follow-up to the Maestro setup, once the phone reconnected.
**Changes:** none to the flows from this run.
**Findings:**
- A locked or sleeping screen fails every flow at its first step. Added to the prerequisites.
- The app launches under Maestro and "Continue with Google" is tapped. Sign-in then stops on a Google screen: the phone's only account is a managed work account requiring a lock screen. I did not choose Skip or Next. The five notes flows therefore have not run past sign-in.
- One launch stayed on a black screen for over 80 seconds and did not reproduce. Recorded as suspected bug 4.
**Verified:** launch and the first sign-in tap, on the phone. Nothing after.
**Docs updated:** `05` (troubleshooting), `07`, `08`.
**Follow-ups:** add a personal test Google account to the phone, or set a lock screen, then run `./tool/maestro.sh test --include-tags notes,auth .maestro`.

## 2026-10-01 — Set up Maestro end-to-end testing

**Request:** set up Maestro (github.com/mobile-dev-inc/Maestro) for testing.
**Changes:**
- Installed Maestro CLI 2.11.0 to `~/.maestro` from the GitHub release, SHA-256 verified. Outside the repository.
- Added `tool/maestro.sh`, a wrapper that supplies Android Studio's JDK and `adb`.
- Added `.maestro/`: `config.yaml`, five flows (`create_note`, `edit_note`, `delete_and_undo`, `empty_note_is_discarded`, `profile_logout`) and four subflows.
- Added `Semantics(identifier: ...)` to five controls in `note_editor_screen.dart` and `notes_list_screen.dart`. No behaviour change.
**Why:** icon buttons expose only a tooltip, which Android 9+ does not report as text, and text-field hints vanish once the field has content. Identifiers are the stable selector. The wrapper exists because this machine has no `java` or `adb` on the PATH, and macOS's `/usr/bin/java` stub makes a plain PATH check pass wrongly.
**Verified:** `maestro check-syntax` reports OK for all nine flow files, and rejects a deliberately broken one. `flutter analyze` clean; `flutter test` 8 of 8. **Not verified:** no flow has been run, because no device was connected. The identifiers and the Google account sheet steps are untested on a device.
**Docs updated:** new `08-e2e-testing.md`; `README.md` index and update table; `01-overview.md`; `02-architecture.md` (testing); `06-conventions.md` (tests); `07-known-issues.md`; `AGENT_CONTEXT.md`; root `README.md`.
**Follow-ups:** connect a device, install the debug APK, run `./tool/maestro.sh test .maestro`, and fix whatever the first run shows. `profile_logout` will confirm or rule out suspected bug 1.

## 2026-10-01 — Project analysis and documentation

**Request:** analyse the project and create architecture, flow and AI-agent docs in a dedicated `docs/` folder, to be kept current after each task.
**Changes:** added `docs/` (seven documents plus `docs/ai/`), root `CLAUDE.md` and `AGENTS.md` that load `docs/ai/AGENT_CONTEXT.md`, and replaced the template `README.md`. No application code changed.
**Why:** the root agent files are what make agents load the context and the update rule automatically.
**Verified:** `flutter analyze` reported no issues; `flutter test` passed 8 of 8. Docs were written from a full read of `lib/`, `test/`, `firestore.rules` and the Android and iOS configuration.
**Docs updated:** all, created.
**Follow-ups:** three suspected bugs recorded in `07-known-issues.md` need confirming on a device.

## 2026-10-01 — Fix Gradle wrapper download timeout

**Request:** the app would not run; `java.net.ConnectException: Operation timed out` from the Gradle wrapper.
**Changes:** none in the repository. Downloaded `gradle-9.3.1-all.zip` with curl, verified its SHA-256 against the published checksum, and placed it in `~/.gradle/wrapper/dists/gradle-9.3.1-all/9ot9r568e8zfvvd4mn8rbu1j0/`.
**Why:** one of four IP addresses for `release-assets.githubusercontent.com` (`185.199.109.133`) is unreachable from this network, and the wrapper's Java downloader does not fall back to another address.
**Verified:** `flutter build apk --debug` succeeded and produced `build/app/outputs/flutter-apk/app-debug.apk`.
**Docs updated:** `05-setup-and-build.md` (troubleshooting).
**Follow-ups:** the timeout can recur for a future Gradle version.
