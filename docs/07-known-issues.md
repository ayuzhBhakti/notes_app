# Known issues

Found during the code analysis on 2026-10-01. Everything in "Suspected bugs" comes from reading the code and has **not** been reproduced on a device. Confirm each one before fixing it.

When an item is fixed, delete it here and record the fix in [ai/TASK_LOG.md](ai/TASK_LOG.md).

## Suspected bugs

Bugs 2 and 3 are in the notes screens, which only the review number 9931133385 reaches ([below](#notes-screens-unreachable)). Bug 3 (the 20,000-character cap) was a Firestore-rule limit and does not apply to the local store, which has no length cap.

### 2. Failure snackbars may never appear after a screen has popped

In [note_editor_screen.dart](../lib/screens/note_editor_screen.dart), the `.then` callback after `save` and `delete` calls `ref.read(noteActionsProvider)` after the editor has popped and its state is disposed. If Riverpod rejects `ref` use after disposal, the callback throws and the "Save failed" snackbar is never shown. The same pattern is in `_deleteWithUndo` in [notes_list_screen.dart](../lib/screens/notes_list_screen.dart), where it matters less because the list stays mounted.

Likely fix: have `NoteActions` methods return the error, or capture the `ProviderContainer` before the async gap.

### 3. A body longer than 20,000 characters fails with a misleading message

The rules cap `body` at 20,000 characters, but the body field in the editor has no limit. A longer note appears in the list, then disappears when the server rejects it, and the snackbar says "You do not have permission to do that."

### 4. One launch showed a black screen for over a minute

On 2026-10-01, the first launch after a fresh install, with the phone's lock screen just dismissed, stayed black for at least 80 seconds. The Dart VM had started but Firebase initialisation never logged. Six later launches on the same device were normal, so it has not been reproduced and the cause is unknown.

## App id change

| Item | Detail |
|------|--------|
| Firebase Android app | Registered as `com.spacewire.notes` only. Matters only if the notes screens come back with a Firebase sign-in. |
| Firebase iOS app | Registered as `com.spacewire.notes`; the Xcode bundle id is now `com.spacewire.evos`. Matters only once iOS is built. |
| Cashfree app whitelisting | If Cashfree's production UPI intent needs the app's package whitelisted, it must be `com.spacewire.evos`. Unchecked. |

## Phone sign-in, paywall and web page (changed 2026-10-22)

| Item | Detail |
|------|--------|
| `webview_url` is not on the server | Migration `20261022120000_webview_url.sql` adds the row (blank, public). It has not been pushed: that needs the owner's go-ahead. Until it is pushed and filled with an https URL, subscribers and the review account see "You're all set" in place of the page. |
| Store listing and website describe the notes app | Since 2026-10-22 every user signs in by phone, meets the paywall and, once subscribed, gets the web page. The Play listing, the screenshots and `website/` still describe a free notes app. They must describe the subscription and the web page before release, or the listing misrepresents the app. Not done because what the web page offers is not known here. |
| Review account sees a different app — declare it | <a id="notes-screens-unreachable"></a>9931133385 with the code 123456 skips the SMS and the paywall and opens the notes screen; every other number gets the paywall and web page. This is the owner's explicit decision (2026-10-22). **If this number is given to Google Play reviewers, the fact that reviewers see a notes app while buyers get a paywalled web page is what Play's Deceptive Behavior (cloaking) policy can flag** — possible rejection or account action. Declare the number under Play Console → App content → App access. It is checked on the device, works in any build, needs nothing on the server, and anyone who learns it gets the notes app free. |
| Review notes are local-only | The review account's notes use `LocalNotesStore` (`shared_preferences`), not Firestore. They are not synced, not backed up, and are deleted when the app's data is cleared. There is no length cap and no "Saving…" state. |
| Firebase notes path unused | The Firestore-backed notes code (`notesStreamProvider`, `NoteActions`, `NotesRepository`, `AuthService`, `firestore.rules`, the Firebase start-up) is still present but no screen uses it. Open: delete it, or bring the real notes app back for everyone (which needs a sign-in Firestore accepts). |
| Web page: no file upload | A page's `<input type="file">` does nothing. It needs a file picker plugin, which was not added. |
| Web page: no camera, microphone or location | Permission requests from the page are denied (the WebView default). Granting them needs the Android permissions in the manifest and a runtime prompt. |
| Web page: `intent://` links | Only links whose scheme `url_launcher` can open (tel:, mailto:, upi:, whatsapp:, https in another app) leave the WebView. `intent://` links are passed to `url_launcher` too and usually fail silently. |
| Web page never seen on a phone | The WebView screen is covered by widget tests only, where no WebView exists. The test phone has the Play-signed build installed, and a debug build cannot replace it without uninstalling it. |

## Deep-link onboarding

Open decisions and unfinished parts of [09-deep-link-onboarding.md](09-deep-link-onboarding.md).

| Item | Detail |
|------|--------|
| Payment is not set up | Sign-in works against project `sqvlgiqypqvjykczuhgz`. Still empty: `cashfree_app_id`, `cashfree_secret_key`, `customer_email_domain`; and the Cashfree dashboard has no webhook for this project. Until then "Try Now" fails on a normal build. |
| UPI app detection never seen working | On the test phone the paywall found no UPI app: its only one, Paytm, has never been opened and Android resolves nothing for `upi://pay`. Whether PhonePe or Google Pay are found on a phone that has them set up is unchecked. |
| Codes reach Indian numbers only | The country selector offers every country, but Fast2SMS's DLT route is India-only, so `sms-hook` refuses the rest. And UPI AutoPay, the only payment, is India-only too. |
| Sign-in SMS says CashAlert | The Fast2SMS template is CashAlert's. Evos needs its own DLT template. |
| Sharing CashAlert's Cashfree account | Cashfree sends every app's subscription events to every webhook URL on the account. This backend ignores mandates whose id does not start with `ev_`; CashAlert's webhook is expected to ignore Evos mandates as "user not found", which has not been checked. |
| Nothing real has run | No SMS has been sent, no code verified by Supabase, no settings fetched, and the Cashfree sheet has never been opened from this app. The list is in [09-deep-link-onboarding.md](09-deep-link-onboarding.md#what-is-not-verified). |
| A second tap on "Try Now" can still open a second mandate server-side | The device now treats each tap as a new attempt and ignores stale answers (fixed the stuck-loading part 2026-10-22), but the server refuses a *new* subscription only once the first is confirmed. Inherited from CashAlert. |
| The SMS code is not read automatically | The field only carries the one-time-code autofill hint. CashAlert uses the SMS User Consent API. |
| SMS sender and template | Fast2SMS needs a DLT-registered sender id and template for Evos. CashAlert's template names CashAlert. |
| `customer_email_domain` is unset | Cashfree needs an email per customer; the server makes one on a domain the business owns, and refuses to create a subscription until the row is filled. |
| Launcher name and icon are fixed | The backend changes the name and logo inside the onboarding interface only. The home-screen name ("Evos") and icon (the Evos mark) are set at build time. |
| Left out of the CashAlert backend | Push notifications, server-side Mixpanel events, the failed-debit retry job and the daily report. A failed renewal ends access silently. |
| Play referrer is lost on phones with a managed account | Play resets the referrer when any Google account on the device is enterprise-managed (Workspace/work), giving `utm_source=(not%20set)&utm_medium=(not%20set)`. Found 2026-10-22; the link works on a phone with personal accounts only. Users with a work account on their phone get the normal app. |
| Direct link is a development aid | It changes nothing on screen since 2026-10-22; it is reported to analytics. Its domain, `notes-f36b3.web.app`, hosts nothing and is unverified, so Android opens it in a browser unless the domain is approved on the device. Remove the intent filter before release if it is not wanted. |
| iOS has no way in | No install referrer exists on iOS, Universal Links are not set up, and the payment code is Android-only. |

## Analytics

Unfinished parts of [10-analytics.md](10-analytics.md); its "Known gaps" section has the rest.

| Item | Detail |
|------|--------|
| Not yet seen in the dashboards | Keys were added 2026-10-21 and both services accepted the onboarding events from the test phone (logcat). Nobody has yet looked at them inside Mixpanel or Facebook Events Manager. |
| Notes events never run | The eight notes events have call sites in screens no route reaches. The Google sign-in events were removed on 2026-10-22. |
| Web page events never seen | `Web Page Viewed`, `Web Page Failed` and `Review Account Signed In` (2026-10-22) are covered by widget tests only. |
| iOS sends nothing | The SDKs are wired on Android only. |
| No consent screen | The Facebook SDK collects the advertising ID once configured. Play's advertising-ID declaration must now say yes. |
| Debug and release share a project | Test runs are mixed in with real users. The 2026-10-21 check already put test-mode events (person `debug-user`, `simulated: true`) into both. |

## Website

| Item | Detail |
|------|--------|
| No domain, not uploaded | No canonical URLs, Open Graph image or sitemap, because the domain is unknown. Add them once it is chosen. `.htaccess` (www to bare domain, own 404 page) assumes an Apache host such as Hostinger and has not been tried on one. After the upload, run the CDN check in [05-setup-and-build.md](05-setup-and-build.md#website-upload-hostinger). |
| Legal text not reviewed | The privacy policy, terms and deletion page were written from the code on 2026-10-14. The 30-day deletion promise, the "laws of India" clause and the operator name `Spacewire` need the owner's review. |
| Play button | Points at `com.spacewire.evos` with `referrer=utm_source=website&utm_medium=button`, which opens the mobile-number screen like any install. The listing may not be live yet. |

## Gaps

| Gap | Detail |
|-----|--------|
| No unsaved-changes guard | Leaving the editor with the back button discards edits silently. |
| No pagination | `watchNotes` loads every note. Fine for personal use, slow for thousands of notes. |
| Shared action state | `NoteActions` has one `AsyncValue` for all saves and deletes. Two writes in flight overwrite each other's status, and an error stays in state until the next action. |
| Undo re-stamps `createdAt` | Accepted on purpose; nothing displays `createdAt`. It matters if a "created" date is ever shown. |
| No account deletion or data export in the app | Only log out exists. The website's `delete-user-data.html` takes deletion requests by email, which satisfies Play's web-link requirement, but someone has to act on them by hand in Firebase and Supabase. |
| Release signing | Release builds use the debug key. A real keystore and its SHA-1 in Firebase are needed before publishing. |
| Rules are published by hand | The repository file can drift from the live rules. No emulator tests cover the rules. |
| Test coverage | The notes screens (list, editor, profile) have no widget or provider tests. Onboarding is covered; the WebView itself cannot be, as no WebView exists in a widget test. |
| No CI | Nothing runs `flutter analyze`, `flutter test` or the Maestro flows automatically. |
| Unconfigured platforms | Web, macOS, Windows and Linux folders exist but the app cannot start on them. |
| iOS build unverified | Never built on this machine. |

## Documentation and naming mismatches

- [notes_repository.dart](../lib/services/notes_repository.dart) claims to be "the only file" importing `cloud_firestore`. Other files import it too; see [02-architecture.md](02-architecture.md#import-rules).
- `pubspec.yaml` still has the template description "A new Flutter project."
- [android/app/build.gradle.kts](../android/app/build.gradle.kts) still has the template `TODO` comments for the application ID and signing.

## Upcoming breakage

- A future Flutter release will fail the Android build while `firebase_auth` and `firebase_core` apply the Kotlin Gradle Plugin. Watch for plugin versions that support Built-in Kotlin.
