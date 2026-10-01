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
| Member home is a placeholder | What deep-link users see after paying has not been specified. |
| Payment is simulated | Every purchase succeeds and nothing is charged. Plan names and prices are invented. |
| Entitlement is a device flag | "Paid" is a value in `shared_preferences`. With a real provider it must be verified on a server. |
| Supabase is not configured | No project URL or anon key has been supplied, and the `onboarding_leads` table has not been created. Until both exist, a debug build saves nothing and a release build cannot get past the form. A real insert has never been tested. |
| Play Store referrer never tested end to end | It needs a build on a Play testing track. Only the channel itself is confirmed on a device. The marker `flow=onboarding` is unconfirmed with whoever writes the links. |
| Resubmitting the form inserts a second row | By design, to keep the table insert-only. Reports must take the newest row per email. |
| The chosen plan is not saved | Only the form goes to Supabase. |
| Existing installs cannot enter by Play link | The referrer belongs to the install. A user who already has the app and taps the Play link just opens the normal app. |
| Direct link is a development aid | Its domain, `notes-f36b3.web.app`, hosts nothing and is unverified, so Android opens it in a browser unless the domain is approved on the device. Remove the intent filter before release if it is not wanted. |
| iOS has no way in | No install referrer exists on iOS, and Universal Links are not set up. |
| Anyone with the link can trigger it | The link carries no token, so anyone who has it switches their device into onboarding. Fine for a public offer; not for invitations. |

Decided, not an issue: a deep-link user has no way back to the notes app.

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
