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
