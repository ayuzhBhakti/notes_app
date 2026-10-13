# Known issues

Found during the code analysis on 2026-10-01. Everything in "Suspected bugs" comes from reading the code and has **not** been reproduced on a device. Confirm each one before fixing it.

When an item is fixed, delete it here and record the fix in [ai/TASK_LOG.md](ai/TASK_LOG.md).

## Suspected bugs

### 1. Logging out leaves the Profile screen showing a spinner

`ProfileScreen` is pushed on top of `AuthGate`. On sign-out, `AuthGate` rebuilds as `SignInScreen` underneath, but nothing pops the Profile route. `ProfileScreen` then sees a null user and builds a full-screen spinner with no app bar. The user would have to press the system back button to reach the sign-in screen, and on iOS there is no such button.

The comments in [auth_gate.dart](../lib/screens/auth_gate.dart) and [profile_screen.dart](../lib/screens/profile_screen.dart) say the gate unwinds pushed routes, but no code does so. (`AppGate` does pop pushed routes when an onboarding link arrives; the same approach would work here.)

Likely fix: pop to the first route when the auth state becomes signed out.

The Maestro flow `profile_logout` asserts the correct behaviour, so running it will confirm or rule out this bug.

### 2. Failure snackbars may never appear after a screen has popped

In [note_editor_screen.dart](../lib/screens/note_editor_screen.dart), the `.then` callback after `save` and `delete` calls `ref.read(noteActionsProvider)` after the editor has popped and its state is disposed. If Riverpod rejects `ref` use after disposal, the callback throws and the "Save failed" snackbar is never shown. The same pattern is in `_deleteWithUndo` in [notes_list_screen.dart](../lib/screens/notes_list_screen.dart), where it matters less because the list stays mounted.

Likely fix: have `NoteActions` methods return the error, or capture the `ProviderContainer` before the async gap.

### 3. A body longer than 20,000 characters fails with a misleading message

The rules cap `body` at 20,000 characters, but the body field in the editor has no limit. A longer note appears in the list, then disappears when the server rejects it, and the snackbar says "You do not have permission to do that."

### 4. One launch showed a black screen for over a minute

On 2026-10-01, the first launch after a fresh install, with the phone's lock screen just dismissed, stayed black for at least 80 seconds. The Dart VM had started but Firebase initialisation never logged. Six later launches on the same device were normal, so it has not been reproduced and the cause is unknown.

## Deep-link onboarding

Open decisions and unfinished parts of [09-deep-link-onboarding.md](09-deep-link-onboarding.md).

| Item | Detail |
|------|--------|
| Payment is not set up | Sign-in works against project `sqvlgiqypqvjykczuhgz`. Still empty: `cashfree_app_id`, `cashfree_secret_key`, `customer_email_domain`; and the Cashfree dashboard has no webhook for this project. Until then "Try Now" fails on a normal build. |
| Sign-in SMS says CashAlert | The Fast2SMS template is CashAlert's. Evos needs its own DLT template. |
| Sharing CashAlert's Cashfree account | Cashfree sends every app's subscription events to every webhook URL on the account. This backend ignores mandates whose id does not start with `ev_`; CashAlert's webhook is expected to ignore Evos mandates as "user not found", which has not been checked. |
| Nothing real has run | No SMS has been sent, no code verified by Supabase, no settings fetched, and the Cashfree sheet has never been opened from this app. The list is in [09-deep-link-onboarding.md](09-deep-link-onboarding.md#what-is-not-verified). |
| What is behind the paywall is not built | A subscriber sees the maintenance screen. |
| A second tap on "Try Now" while a payment is pending opens a second mandate | The server refuses a new subscription only once the first is confirmed. Inherited from CashAlert. |
| No preview video on the paywall | CashAlert plays one; this paywall shows a picture from the backend. |
| The SMS code is not read automatically | The field only carries the one-time-code autofill hint. CashAlert uses the SMS User Consent API. |
| SMS sender and template | Fast2SMS needs a DLT-registered sender id and template for Evos. CashAlert's template names CashAlert. |
| `customer_email_domain` is unset | Cashfree needs an email per customer; the server makes one on a domain the business owns, and refuses to create a subscription until the row is filled. |
| Launcher name and icon are fixed | The backend changes the name and logo inside the interface only. On the home screen the app is "notes". |
| Left out of the CashAlert backend | Push notifications, server-side Mixpanel events, the failed-debit retry job and the daily report. A failed renewal ends access silently. |
| Play Store referrer never tested end to end | It needs a build on a Play testing track. Only the channel itself is confirmed on a device. The marker `flow=onboarding` is unconfirmed with whoever writes the links. |
| Existing installs cannot enter by Play link | The referrer belongs to the install. A user who already has the app and taps the Play link just opens the normal app. |
| Direct link is a development aid | Its domain, `notes-f36b3.web.app`, hosts nothing and is unverified, so Android opens it in a browser unless the domain is approved on the device. Remove the intent filter before release if it is not wanted. |
| iOS has no way in | No install referrer exists on iOS, Universal Links are not set up, and the payment code is Android-only. |
| Anyone with the link can trigger it | The link carries no token, so anyone who has it switches their device into onboarding. Fine for a public offer; not for invitations. |

Decided, not an issue: a deep-link user has no way back to the notes app.

## Analytics

Unfinished parts of [10-analytics.md](10-analytics.md); its "Known gaps" section has the rest.

| Item | Detail |
|------|--------|
| No keys | The Mixpanel token and the Facebook app ID and client token are placeholders, so nothing is sent. No event has been seen in Mixpanel or in Facebook Events Manager. |
| Sign-in and notes events never run | The six sign-in events, the eight notes events, `identify` and the reset on log out have a call site each but have never executed: sign-in is blocked on the test phone and those screens have no widget tests. |
| iOS sends nothing | The SDKs are wired on Android only. |
| No consent screen | The Facebook SDK collects the advertising ID once configured. Play's advertising-ID declaration must now say yes. |
| Debug and release share a project | Test runs will be mixed in with real users once keys are added. |

## Gaps

| Gap | Detail |
|-----|--------|
| No unsaved-changes guard | Leaving the editor with the back button discards edits silently. |
| No pagination | `watchNotes` loads every note. Fine for personal use, slow for thousands of notes. |
| Shared action state | `NoteActions` has one `AsyncValue` for all saves and deletes. Two writes in flight overwrite each other's status, and an error stays in state until the next action. |
| Undo re-stamps `createdAt` | Accepted on purpose; nothing displays `createdAt`. It matters if a "created" date is ever shown. |
| No account deletion or data export | Only log out exists. App stores require account deletion for apps with sign-in. |
| Release signing | Release builds use the debug key. A real keystore and its SHA-1 in Firebase are needed before publishing. |
| Rules are published by hand | The repository file can drift from the live rules. No emulator tests cover the rules. |
| Test coverage | The signed-in notes screens (list, editor, profile) have no widget or provider tests. Onboarding is covered. |
| Notes Maestro flows never run past sign-in | The five notes flows launch the app and tap through to Google's account sheet, then stop: the test phone's only Google account is a managed one that demands a lock screen. Everything after sign-in, including their semantics identifiers, is unconfirmed on a device. |
| No CI | Nothing runs `flutter analyze`, `flutter test` or the Maestro flows automatically. |
| Unconfigured platforms | Web, macOS, Windows and Linux folders exist but the app cannot start on them. |
| iOS build unverified | Never built on this machine. |

## Documentation and naming mismatches

- [auth_service.dart](../lib/services/auth_service.dart) and [notes_repository.dart](../lib/services/notes_repository.dart) each claim to be "the only file" importing their Firebase package. Other files import them too; see [02-architecture.md](02-architecture.md#import-rules).
- The Android app label is `notes` (lower case) in [AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml); the iOS display name is `Notes`.
- `pubspec.yaml` still has the template description "A new Flutter project."
- [android/app/build.gradle.kts](../android/app/build.gradle.kts) still has the template `TODO` comments for the application ID and signing.

## Upcoming breakage

- A future Flutter release will fail the Android build while `firebase_auth` and `firebase_core` apply the Kotlin Gradle Plugin. Watch for plugin versions that support Built-in Kotlin.
