# End-to-end testing with Maestro

[Maestro](https://github.com/mobile-dev-inc/Maestro) drives the real app on a device or emulator through YAML flows. It covers what the widget tests cannot: the real WebView, the keyboard, a restart, and the native payment and analytics code.

**Status (2026-10-22), on a Samsung SM-M127G, Android 13:**

| Flow | Result |
|------|--------|
| `onboarding` | Not run since it was rewritten on 2026-10-22 (from `onboarding_deeplink`, which passed on 2026-10-19). Test-mode build only (`--dart-define=SUPABASE_URL=`); on a normal build it stops, by design, before "Send code" |
| `review_account` | Not run yet (written 2026-10-22, updated the same day to land on the local notes screen). Safe on any build: the review number sends no SMS |

Neither has run because the test phone has the Play-signed build installed, which a debug build cannot replace without uninstalling it.

The old notes flows, `deeplink_local` and the Google sign-in subflows were moved to `.maestro/retired/` on 2026-10-22: they need Google sign-in, which is gone. The review number does reach notes now, but through a local store, so `review_account.yaml` covers that instead. That folder is not run and, like all of `.maestro/`, is not in git.

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
   For `onboarding`, build in test mode: `flutter build apk --debug --dart-define=SUPABASE_URL=`. A Play or release build already on the phone has another signature: uninstall it first, which deletes its data.

## Run

```sh
./tool/maestro.sh test .maestro                              # all flows, in order
./tool/maestro.sh test .maestro/flows/review_account.yaml    # one flow
./tool/maestro.sh test --format junit --output build/maestro-report.xml .maestro
```

Useful while writing flows:

```sh
./tool/maestro.sh studio        # browser UI to inspect the screen and try commands
./tool/maestro.sh hierarchy     # print what Maestro can see on the current screen
./tool/maestro.sh check-syntax .maestro/flows/onboarding.yaml
```

Screenshots and logs from failed runs are written to `~/.maestro/tests/`.

## Layout

```
.maestro/
├── config.yaml              Which files are tests, and their order
├── flows/                   One file per test
└── retired/                 Old notes and deep-link flows, not run
```

| Flow | Tag | Checks |
|------|-----|--------|
| [review_account](../.maestro/flows/review_account.yaml) | onboarding | 9931133385 and 123456 skip the SMS and the paywall onto the notes screen; a note is created and kept across a restart; Log out (on the Profile screen) returns to the mobile number. |
| [onboarding](../.maestro/flows/onboarding.yaml) | onboarding | A plain launch shows the mobile-number screen and no Google button; code screen, back and forward; the code signs in; paywall and its AutoPay sentence; simulated payment (a full-screen processing screen shows while it runs); the web page screen survives a restart; Log out. Test mode only: against a real backend it would text a real number and stop at the code. Also run by `./tool/deeplink.sh --check`. |

Both clear the app's data at their start and end.

## How the flows are written

- **Every flow starts with `clearState`.** Each can then run alone and in any order.
- **A tappable card or `ListTile` is one accessibility node.** Its texts are joined with newlines, so a flow cannot match one of them alone. The note card wraps its title and preview in `Semantics(container: true)` to keep them separate; on 2026-10-14 that is what made `create_note` find its title. Do the same for any new text a flow selects on.
- **Text is the default selector.** Maestro matches visible text as a whole-string regular expression, so `"Log out"` does not match the dialog title `"Log out?"`.
- **Controls without visible text use a semantics identifier.** Flutter's `Semantics(identifier: ...)` becomes the Android resource ID and the iOS accessibility identifier, selected in a flow with `id:`.

| Identifier | Control | File |
|------------|---------|------|
| `phone_field`, `send_code_button`, `country_picker`, `login_carousel` | Mobile-number screen (`login_carousel` only when the backend sends slides) | [phone_screen.dart](../lib/screens/onboarding/phone_screen.dart) |
| `otp_field`, `otp_verify_button`, `otp_resend_button` | Code screen. `otp_field` is the one invisible field under the six boxes | [otp_screen.dart](../lib/screens/onboarding/otp_screen.dart) |
| `paywall_upi_selector`, `paywall_try_now_button` | Paywall bottom bar | [paywall_screen.dart](../lib/screens/onboarding/paywall_screen.dart) |
| `upi_app_<package>` | A row in the UPI app sheet | [paywall_screen.dart](../lib/screens/onboarding/paywall_screen.dart) |
| `web_screen`, `web_menu_button`, `web_logout_button`, `web_check_again_button` | Web page screen: the whole screen, the ⋮ menu, Log out inside it, and "Check again" (only while there is no `webview_url`) | [web_screen.dart](../lib/screens/onboarding/web_screen.dart) |
| `notes_profile_button`, `note_title_field`, `note_body_field`, `note_save_button`, `note_delete_button` | The review account's notes screens | [notes_list_screen.dart](../lib/screens/notes_list_screen.dart), [note_editor_screen.dart](../lib/screens/note_editor_screen.dart) |

`phone_field` and `otp_field` are confirmed on a device. The `web_*` and `note*` identifiers are used by the flows but not yet confirmed on a device since the 2026-10-22 rewrite.

Tooltips are not used as selectors because Android 9 and later do not expose them as text. Hint text is not used because it disappears once the field has content.

## Adding a flow

1. Add `flows/<name>.yaml` with `appId: com.spacewire.evos`, a `name:` and a tag.
2. Start with `- clearState` and `- launchApp`.
3. If a control has no visible text, wrap it in `Semantics(identifier: 'snake_case_name')` and add it to the table above.
4. Add the name to `flowsOrder` in [config.yaml](../.maestro/config.yaml).
5. Run `check-syntax`, then run the flow on a device.

Renaming user-visible text or an identifier breaks any flow that selects on it. Search `.maestro/` before changing either.

## Known limits

- **The page inside the WebView is not checked.** Test mode fetches no settings, so the flows see "You're all set" in place of a page.
- **iOS is untested.** The flows use nothing Android-specific, but the iOS app has never been built on this machine.
- **No CI.** Flows are run by hand.
