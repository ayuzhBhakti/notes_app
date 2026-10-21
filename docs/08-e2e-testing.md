# End-to-end testing with Maestro

[Maestro](https://github.com/mobile-dev-inc/Maestro) drives the real app on a device or emulator through YAML flows. It covers what the unit tests cannot: sign-in, Firestore writes, navigation and snackbars.

**Status (2026-10-13; notes rows 2026-10-14), on a Samsung SM-M127G, Android 13:**

| Flow | Result |
|------|--------|
| `deeplink_local` | Passes (2026-10-19) |
| `onboarding_deeplink` | Passes on a test-mode build (`--dart-define=SUPABASE_URL=`), last run 2026-10-19. On a normal build it stops, by design, before "Send code" |
| `create_note`, `edit_note`, `delete_and_undo`, `empty_note_is_discarded` | Passed 2026-10-14 under the old id `com.spacewire.notes`. Blocked at Google sign-in on `com.spacewire.evos` until Firebase knows the new package ([07-known-issues.md](07-known-issues.md#app-id-change)) |
| `profile_logout` | Not run. It signs the phone out |

Expect to adjust selectors in the five notes flows the first time they get past sign-in.

## Install

Maestro lives in `~/.maestro`, outside the repository. To install it on another machine:

```sh
curl -fsSL "https://get.maestro.mobile.dev" | bash
```

It needs Java 17 or later. [tool/maestro.sh](../tool/maestro.sh) uses Android Studio's bundled JDK when no other Java is installed, and adds `adb` to the PATH. Always run Maestro through it:

```sh
./tool/maestro.sh --version
```

The script turns Maestro's usage analytics off. Set `MAESTRO_CLI_NO_ANALYTICS=0` to turn them on.

## Before running

1. **Connect a device.** A phone with USB debugging on, or a running emulator. Check with `flutter devices`. Maestro cannot see the app behind a lock screen, so for a `test` run [tool/maestro.sh](../tool/maestro.sh) wakes the device, dismisses the lock screen, and holds the screen on, then puts the device's stay-awake setting back. A lock screen with a PIN or pattern must be unlocked by hand first.
2. **Install the app.** Maestro launches the installed build; it does not build one.
   ```sh
   flutter build apk --debug
   ~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```
3. **Have a personal Google account on the device**, and the machine's debug SHA-1 registered in Firebase ([05-setup-and-build.md](05-setup-and-build.md#android-signing-certificate)). Use a test account: the flows create and delete notes in it. A managed work account may refuse to sign in. Not needed for `onboarding_deeplink`.
4. **Be online.** The notes flows assert on synced state.
5. **Approve the link domain, once per device**, for `onboarding_deeplink`. `deeplink_local` does not need this. Until the domain hosts `assetlinks.json`, Android opens the link in a browser:
   ```sh
   ~/Library/Android/sdk/platform-tools/adb shell pm set-app-links-user-selection \
     --user cur --package com.spacewire.evos true notes-f36b3.web.app
   ```

## Run

```sh
./tool/maestro.sh test .maestro                              # all flows, in order
./tool/maestro.sh test .maestro/flows/create_note.yaml       # one flow
./tool/maestro.sh test --include-tags notes .maestro         # notes flows only
./tool/maestro.sh test --include-tags onboarding .maestro    # needs no Google account
./tool/maestro.sh test -e GOOGLE_ACCOUNT_EMAIL=you@gmail.com .maestro
./tool/maestro.sh test --format junit --output build/maestro-report.xml .maestro
```

Useful while writing flows:

```sh
./tool/maestro.sh studio        # browser UI to inspect the screen and try commands
./tool/maestro.sh hierarchy     # print what Maestro can see on the current screen
./tool/maestro.sh check-syntax .maestro/flows/create_note.yaml
```

Screenshots and logs from failed runs are written to `~/.maestro/tests/`.

## Layout

```
.maestro/
├── config.yaml              Which files are tests, and their order
├── flows/                   One file per test
└── subflows/                Shared steps, not run on their own
```

| Flow | Tag | Checks |
|------|-----|--------|
| [deeplink_local](../.maestro/flows/deeplink_local.yaml) | onboarding, deeplink | The local link `notes://onboarding`: no link shows the normal app; link while running, after restart, and from cold start all show the mobile-number screen. Also run by `./tool/deeplink.sh --check`. |
| [onboarding_deeplink](../.maestro/flows/onboarding_deeplink.yaml) | onboarding | The link opens the mobile-number screen; code screen, back and forward; the code signs in; paywall and its AutoPay sentence; simulated payment; maintenance survives a restart; log out. Only valid in test mode: against a real backend it would text a real number and stop at the code. |
| [create_note](../.maestro/flows/create_note.yaml) | notes | A new note appears in the list with its title and body preview |
| [edit_note](../.maestro/flows/edit_note.yaml) | notes | The editor opens pre-filled, and a saved edit shows in the list |
| [delete_and_undo](../.maestro/flows/delete_and_undo.yaml) | notes | Swipe-to-delete removes the row; Undo brings the note back |
| [empty_note_is_discarded](../.maestro/flows/empty_note_is_discarded.yaml) | notes | Saving a blank note writes nothing |
| [profile_logout](../.maestro/flows/profile_logout.yaml) | auth | Profile shows the user; Cancel keeps the session; Log out reaches the sign-in screen |

| Subflow | Does |
|---------|------|
| [ensure_signed_in](../.maestro/subflows/ensure_signed_in.yaml) | Launches the app and signs in only if the sign-in screen is showing |
| [sign_in](../.maestro/subflows/sign_in.yaml) | Taps through Google sign-in |
| [create_note](../.maestro/subflows/create_note.yaml) | Creates a note from `TITLE` and `BODY` |
| [delete_note](../.maestro/subflows/delete_note.yaml) | Deletes the note titled `TITLE` |

`deeplink_local` and `onboarding_deeplink` run first because they clear the app's data at their start and end, which signs the notes app out. `profile_logout` runs last, so the notes flows share one session.

## How the flows are written

- **Every notes flow starts with `ensure_signed_in`.** Each flow can then run alone and in any state.
- **A tappable card or `ListTile` is one accessibility node.** Its texts are joined with newlines, so a flow cannot match one of them alone. The note card wraps its title and preview in `Semantics(container: true)` to keep them separate; on 2026-10-14 that is what made `create_note` find its title. Do the same for any new text a flow selects on.
- **Every flow cleans up.** Notes get a unique title from `Date.now()` and are deleted at the end, so runs do not interfere and the test account stays empty.
- **Text is the default selector.** Maestro matches visible text as a whole-string regular expression, so `"Log out"` does not match the dialog title `"Log out?"`.
- **Controls without visible text use a semantics identifier.** Flutter's `Semantics(identifier: ...)` becomes the Android resource ID and the iOS accessibility identifier, selected in a flow with `id:`.

| Identifier | Control | File |
|------------|---------|------|
| `notes_profile_button` | Profile icon in the list app bar | [notes_list_screen.dart](../lib/screens/notes_list_screen.dart) |
| `note_title_field` | Title field | [note_editor_screen.dart](../lib/screens/note_editor_screen.dart) |
| `note_body_field` | Body field | [note_editor_screen.dart](../lib/screens/note_editor_screen.dart) |
| `note_save_button` | Save icon | [note_editor_screen.dart](../lib/screens/note_editor_screen.dart) |
| `note_delete_button` | Delete icon | [note_editor_screen.dart](../lib/screens/note_editor_screen.dart) |
| `phone_field`, `send_code_button`, `country_picker`, `login_carousel` | Mobile-number screen (`login_carousel` only when the backend sends slides) | [phone_screen.dart](../lib/screens/onboarding/phone_screen.dart) |
| `otp_field`, `otp_verify_button`, `otp_resend_button` | Code screen. `otp_field` is the one invisible field under the six boxes | [otp_screen.dart](../lib/screens/onboarding/otp_screen.dart) |
| `paywall_upi_selector`, `paywall_try_now_button` | Paywall bottom bar | [paywall_screen.dart](../lib/screens/onboarding/paywall_screen.dart) |
| `upi_app_<package>` | A row in the UPI app sheet | [paywall_screen.dart](../lib/screens/onboarding/paywall_screen.dart) |
| `maintenance_check_again_button`, `maintenance_logout_button` | Maintenance screen | [maintenance_screen.dart](../lib/screens/onboarding/maintenance_screen.dart) |

Of the onboarding identifiers, `phone_field`, `otp_field` and `maintenance_logout_button` are used by a flow and confirmed on a device; the rest are not selected by any flow yet. The five notes identifiers are not confirmed.

Tooltips are not used as selectors because Android 9 and later do not expose them as text. Hint text is not used because it disappears once the field has content.

## Adding a flow

1. Add `flows/<name>.yaml` with `appId: com.spacewire.evos`, a `name:` and a tag.
2. Start with `- runFlow: ../subflows/ensure_signed_in.yaml`.
3. If a control has no visible text, wrap it in `Semantics(identifier: 'snake_case_name')` and add it to the table above.
4. Add the name to `flowsOrder` in [config.yaml](../.maestro/config.yaml), before `profile_logout`.
5. Run `check-syntax`, then run the flow on a device.

Renaming user-visible text or an identifier breaks any flow that selects on it. Search `.maestro/` before changing either.

## Known limits

- **`delete_and_undo` flicks rather than drags.** Maestro's swipe from an element stops at the element's edge, which fell short of `Dismissible`'s 40% threshold. `duration: 100` makes it a fling, which dismisses regardless of distance. A real finger swipe was checked with `adb shell input swipe` and works.
- **Google sign-in is system UI.** The account sheet differs between Android versions and between one and several accounts. [sign_in.yaml](../.maestro/subflows/sign_in.yaml) treats its steps as optional and may need adjusting per device.
- **`sign_in` picks the first account by default.** Pass `-e GOOGLE_ACCOUNT_EMAIL=...` when the device has more than one, or the wrong one.
- **Maestro's `autoVerify` did not open the unverified link in the app** on the test phone. The device command in "Before running" is what made it work.
- **`profile_logout` may fail on its last step.** If it stops on a spinner after logging out, that is suspected bug 1 in [07-known-issues.md](07-known-issues.md), which this flow is the first real check of.
- **iOS is untested.** The flows use nothing Android-specific, but the iOS app has never been built on this machine.
- **No offline flows.** Offline saving and "Saving…" are not covered.
- **No CI.** Flows are run by hand.
