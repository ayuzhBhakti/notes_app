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

## 2026-10-22 — Play release notes for 1.0.1+2

**Request:** what the release notes for the new release should say.
**Changes:** none in the repo; the text was given in chat.
**Why:** the only change since 1.0.0+1 is the install-referrer retry and its analytics, which users cannot see, so the notes are a generic "stability and reliability" line. They name the notes app only, like the listing and the website.
**Verified:** under Play's 500-character limit. Not checked in Play Console.
**Docs updated:** this log only.
**Follow-ups:** none.

---

## 2026-10-22 — Play referrer: report Play's raw answer, retry an empty one

**Request:** option 1 after the failed Play referrer test: an update that shows what Play sends, and works if Play sends it late.
**Changes:** `MainActivity.kt` returns the referrer with Play's click and install-begin timestamps. `install_referrer_service.dart`: `InstallReferrer`, `isReferrerFinal` (an empty answer is retried, up to `kReferrerMaxAttempts` = 5 launches), and `isOnboardingReferrer` accepts an encoded `flow%3Donboarding`. `OnboardingStore` counts attempts (`install_referrer_attempts`). `main.dart` applies a referrer from a later launch only when no notes user is signed in (`AuthService.isSignedIn`, new). `Analytics.installAttributed` adds `install_referrer_raw`, `referrer_click_recorded`, `referrer_attempt`. `pubspec.yaml` version 1.0.1+2.
**Why:** Mixpanel showed `install_source: unknown`, meaning Play's answer had no `utm_source` and no `flow`, most likely empty. Whether Play fills it in later, and what it sends, cannot be seen without a Play build: Play re-signs the app, so no local build can read a Play install's referrer.
**Verified:** `flutter analyze` clean; 129 tests pass (4 new). Debug build on the test phone: `Install Attributed` carried `install_referrer_raw: utm_source=google-play&utm_medium=organic`, `referrer_click_recorded: false`, `referrer_attempt: 1` (adb install, so organic is expected). `flutter build appbundle` wrote a signed `app-release.aab`. The retry and the late-referrer path are covered by unit tests of `isReferrerFinal` only; they cannot run without Play. Not verified that Play passes the referrer at all.
**Docs updated:** `docs/10-analytics.md`, `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md`.
**Follow-ups:** owner uploads 1.0.1+2. Then test with a phone signed in to a personal @gmail.com account only (the test phone's only account is a Workspace account on `bhaktilok.app`, which one report says makes Play reset the referrer), and read `install_referrer_raw` and `referrer_click_recorded` in Mixpanel.

---

## 2026-10-22 — Tested the Play Store referrer link on the live build: fails

**Request:** the app is live on Play; give the onboarding Play link and test it on the connected phone.
**Changes:** none kept. A temporary log of the referrer value in `main.dart` and `install_referrer_service.dart` was added for a probe build and reverted.
**Verified:** on the test phone (SM-M127G), four fresh Play installs (`installerPackageName=com.android.vending`, no backup restored), each opened first through `https://play.google.com/store/apps/details?id=com.spacewire.evos&referrer=flow%3Donboarding` (from Gmail by the owner, then by `adb shell am start` into Play, and once with `referrer=flow=onboarding` unencoded), all opened the notes sign-in screen. `InstallReferrerClient` verbose log: the service connected and answered within ~200 ms (three callers: the app plus, probably, the Facebook and Mixpanel SDKs), so this is not the 3 s timeout or R8. The Play APK pulled from the phone contains the referrer channel, `flow`, `install_referrer_checked` and the onboarding screens. A release probe build installed by adb read `utm_source=google-play&utm_medium=organic` in 51 ms. Play re-signs the app, so the probe could not be put over a Play install to read Play's actual answer there.
**Docs updated:** `docs/ai/AGENT_CONTEXT.md`, `docs/07-known-issues.md`, `docs/09-deep-link-onboarding.md`.
**Mixpanel:** the owner's "Install Attributed" for the 12:56 IST install shows `install_source: unknown`, `install_medium: organic`: Play handed over a referrer with no `utm_source` and no `flow` (most likely an empty string), not its organic default and not `flow=onboarding`.
**Follow-ups:** owner to choose a next step (diagnostic update to Play, web link route, or an attribution service). Not tried: a different Google account or phone, a link from a web page in Chrome.

---

## 2026-10-21 — Verified the real Mixpanel and Facebook keys

**Request:** the owner put real keys in `analytics_keys.xml`; check that everything works.
**Changes:** `MetaSdk.kt` turns on the Facebook SDK's request and App Events logging in debug builds (Mixpanel's was already on). Docs updated to say the keys are in.
**Why:** without that logging there was no way to see from the phone whether Facebook accepted anything.
**Verified:** Graph API read with the App ID and client token returned the app "evos" (a wrong token is refused). `flutter analyze` clean, 125 tests pass. Test-mode debug build on the test phone, `onboarding_deeplink` up to the maintenance screen: Mixpanel `/track` and `/engage` answered `status: 1` for all 12 events plus the profile, Facebook answered `success: true` for `fb_sdk_initialize`, `MOBILE_APP_INSTALL`, `fb_mobile_activate_app`, `fb_mobile_initiated_checkout`. The "not fully initialized" errors appear only on the first launch after install and are harmless. Not checked inside the dashboards.
**Docs updated:** `docs/10-analytics.md`, `docs/05-setup-and-build.md`, `docs/07-known-issues.md`, `docs/ai/AGENT_CONTEXT.md`.
**Follow-ups:** owner to confirm the events in Mixpanel and Events Manager; sign-in/notes events, `metaCompleteRegistration` and a real purchase still never sent; debug and release share the project.

---

## 2026-10-21 — Facebook Android platform details

**Request:** package name, class name and key hash to register the app in Facebook and get the app id and client token.
**Changes:** none to code. Recorded the values in `docs/10-analytics.md`.
**Why:** `keytool -printcert -jarfile` cannot read these APKs (v2 signatures only), so the hashes came from `apksigner`; reading the certificate from the APK avoids touching `key.properties` or the keystore.
**Verified:** release APK signer is `CN=Spacewire` (upload key), debug is `CN=Android Debug`.
**Docs updated:** `docs/10-analytics.md`.
**Follow-ups:** add the Play app signing key's hash once the app is on Play; put the app id and client token into `analytics_keys.xml`.

---

## 2026-10-21 — Login carousel shows from the first frame on a fresh install

**Request:** on the deep-link sign-up screen the carousel did not show at first; it appeared after a moment and the screen's items moved.
**Changes:** `providers.dart`: new `remoteConfigSettledProvider`, true once settings are saved on the device or the fetch has answered or failed; `RemoteConfigController.refresh` settles it. `phone_screen.dart`: on a first launch the screen shows a spinner until settled and the first slide image is loaded (at most 4 s), then the form; all slide images are precached; slide images are decoded at a height from the screen size (not the card) so the precached copy is the one drawn. `test/support/harness.dart`: `FakeBackend.configDelay`, `launch(settle:)`. Two new tests in `onboarding_flow_test.dart`.
**Why:** a fresh install had no saved settings, so the first frame was the no-slides layout with the field autofocused; the keyboard opened, and when the slides arrived the layout jumped and the carousel stayed hidden behind the keyboard. Images then loaded separately behind a placeholder.
**Verified:** `flutter analyze` no issues; `flutter test` 125/125. `check-syntax` OK on `onboarding_deeplink` and `deeplink_local` (flows not run). Normal debug build on the test phone, `./tool/deeplink.sh --fresh`: spinner, then the carousel with the keyboard closed. Phone reset with `--reset` afterwards.
**Docs updated:** 09-deep-link-onboarding, ai/AGENT_CONTEXT.
**Follow-ups:** images still download on every launch (Flutter keeps no disk cache); a disk cache would need a package such as `cached_network_image`.

---

## 2026-10-21 — Upload key regenerated with the owner's alias and password

**Request:** regenerate the keystore with alias `admin` and the owner's password.
**Changes:** `android/app/upload-keystore.jks` and `android/key.properties` replaced (same settings otherwise). The earlier key, never uploaded anywhere, was moved out of the repo to the session scratchpad. No Gradle change.
**Verified:** `flutter build apk` succeeded and `apksigner` shows SHA-1 `42:4C:...:D7:60`; `flutter build appbundle` wrote an `.aab` signed by the same key and still exits with the cmdline-tools error.
**Docs updated:** 05-setup-and-build (alias, fingerprints).
**Follow-ups:** the earlier entry's SHA-1 (`0B:74:...`) is obsolete; register `42:4C:...` in Firebase instead. Back up both files.

---

## 2026-10-21 — Release signing with an upload key

**Request:** generate the release keystore and set up Gradle.
**Changes:** new `android/app/upload-keystore.jks` (PKCS12, RSA 4096, alias `upload`, 10,000 days, `CN=Spacewire, O=Spacewire, L=India, C=IN`) and `android/key.properties` (random 32-character password), both gitignored, mode 600. `android/app/build.gradle.kts`: loads `key.properties`, adds a `release` signing config, and signs release with it; without the file it falls back to the debug key with a warning. Removed the template TODOs.
**Why:** the debug fallback keeps release builds working on machines without the key; Play rejects debug-signed bundles, so it cannot publish the wrong key.
**Verified:** `flutter build appbundle` wrote `app-release.aab` signed by the new key (`keytool -printcert`, SHA-1 `0B:74:...:0B:A6`) but exited with "failed to strip debug symbols" because the SDK cmdline-tools are missing. `flutter build apk` succeeded; `apksigner` shows the same certificate. `flutter analyze` clean, 123 of 123 tests.
**Docs updated:** 05-setup-and-build (Release signing section, troubleshooting entry, signing-certificate note), ai/AGENT_CONTEXT (commands, rule 8a).
**Follow-ups:** owner backs up both files; installs cmdline-tools; adds the upload SHA-1 and, after the first upload, Play's app-signing SHA-1 to Firebase for Google sign-in.

---

## 2026-10-21 — Website: real contact email

**Request:** use `contact@spacewiretech.com` everywhere on the website for support, privacy and account deletion.
**Changes:** every `support@evos.example` in `website/*.html` (13 in 7 pages: home, contact, privacy policy, terms, delete-my-data, 404) replaced with `contact@spacewiretech.com`, link text and `mailto:` alike, including the deletion button's prefilled subject and body.
**Verified:** `grep` finds no `evos.example` left in `website/` or the app code. No CSS or JS changed, so the `?v=` tag stays. Pages not reopened in a browser.
**Docs updated:** 07-known-issues (placeholder-email row removed), 01-overview, ai/AGENT_CONTEXT.
**Follow-ups:** the Play listing's contact email should be the same address; upload the site.

---

## 2026-10-21 — Play Store listing text

**Request:** write the Play Store short and long description.
**Changes:** none in the repo; the text was given in chat, based on `website/index.html`.
**Why:** the listing matches the website's claims (free notes, Google sign-in, offline, Android only).
**Verified:** short description 80 characters or fewer, long description under 4,000. Not checked against Play Console.
**Docs updated:** this log only.
**Follow-ups:** the listing describes the notes app only. If the published build contains the onboarding subscription path, Play's policies on disclosing paid features and on payments need resolving with the owner before release.

---

## 2026-10-19 — Website: CSS version tag for Hostinger's CDN

**Request:** stop Hostinger's CDN from serving stale CSS/JS after an upload: version-tag local CSS/JS links, check `.htaccess`, document the rule and a post-upload check. No upload, no commit.
**Changes:** every `website/*.html` page: `css/styles.css` -> `css/styles.css?v=20261019` (the only local CSS/JS file; the JS is inline). `website/.htaccess`: added a www-to-bare-domain redirect written without the domain name, no HTTP-to-HTTPS rule; the 404 rule was already there.
**Why:** the CDN caches a copy per compression method and can keep an old Brotli copy; a new query string is a new address to it. Files not renamed so existing links keep working.
**Verified:** a script found every local link and image path pointing to an existing file and every stylesheet link tagged. Served with `python3 -m http.server`; headless Chrome showed `index.html` and `privacy-policy.html` fully styled, and `404.html` served at `/some/deep/missing/page` styled (its `<base href="/">` resolves links from the root). The `.htaccess` rules were not run (no Apache here); the CDN check needs the upload.
**Docs updated:** 05-setup-and-build (new "Website upload (Hostinger)" section), README (table row), 07-known-issues (Website), ai/AGENT_CONTEXT (rule 26, files table).
**Follow-ups:** owner uploads (including the hidden `.htaccess`) and runs the check in 05-setup-and-build.

---

## 2026-10-19 — App id renamed to com.spacewire.evos

**Request:** change the package name from notes to evos. Owner's answers: the app id, to `com.spacewire.evos`; the owner registers it in Firebase; not published on Play.
**Changes:** `android/app/build.gradle.kts` (`namespace`, `applicationId`); Kotlin sources moved to `kotlin/com/spacewire/evos/` with their `package` and imports; channel names `com.spacewire.evos/{install_referrer,analytics,payments}` on both sides (`MainActivity.kt`, `AnalyticsChannel.kt`, `PaymentsChannel.kt`, `install_referrer_service.dart`, `analytics.dart`, `payment_gateway.dart`); iOS and macOS bundle ids, Linux `APPLICATION_ID`, `iosBundleId` in `firebase_options.dart`; Maestro `appId` in every flow; `tool/deeplink.sh`; `web_links/` (`assetlinks.json`, the intent link); the website's Play links. Dart package `Evos` → `evos` in `pubspec.yaml` and the test imports. `google-services.json` left as Firebase's record of the old app.
**Why:** a lowercase Dart name also clears the `package_names` lint. Not on Play, so no listing is tied to the old id. The Firebase Android `appId` cannot change until the owner registers the package.
**Verified:** `flutter analyze` no issues; `flutter test` 123 of 123; debug and release APKs build and `aapt` reports `com.spacewire.evos`. On the test phone (test-mode build): link domain approved for the new package; `onboarding_deeplink` and `deeplink_local` pass; analytics calls reach Kotlin with no missing-plugin errors. `deeplink_local` first failed on Android's chooser because the old build also claimed `notes://`; the old `com.spacewire.notes` (no data) was uninstalled. Google sign-in not tried: expected to fail until Firebase has the package. The payments channel was not exercised (test mode simulates payment).
**Docs updated:** 01-overview, 05-setup-and-build, 07-known-issues (new "App id change" section), 08-e2e-testing, 09-deep-link-onboarding, 10-analytics, ai/AGENT_CONTEXT, and the package name in the other docs and `website/`.
**Follow-ups:** owner adds the Android app `com.spacewire.evos` with the debug SHA-1 in Firebase and sends the new `google-services.json`; then update `firebase_options.dart`, rerun the notes flows. The `notes://` scheme and the `notes-f36b3.web.app` link domain keep their names (not package names).

---

## 2026-10-19 — Paywall settings migration pushed

**Request:** push the paywall settings migration.
**Changes:** `supabase db push` applied `20261019120000_paywall_controls.sql` to project `sqvlgiqypqvjykczuhgz` (dry run first: it was the only pending migration). No repository code changed.
**Verified:** `supabase migration list` shows it on the remote; the ten rows are readable with the anon key and hold the defaults (`1:1`, `true`, the rest blank); `paywall_video_url` untouched. A first attempt that piped `yes` into the push was refused by the permission system; the plain `db push` was allowed.
**Docs updated:** 09-deep-link-onboarding (backend table), ai/AGENT_CONTEXT (state), this log.
**Follow-ups:** none.

---

## 2026-10-19 — Paywall video card size; every paywall text and icon from the backend

**Request:** the paywall's video card started small and grew when the video loaded; show its real size from the start. And control the whole paywall (icons, amounts, heading, description, everything) from the backend. Plan first; owner's decisions: AutoPay sentence fully backend text with the app's own as fallback when blank; icons as image links (names also accepted, as recommended); one row per setting; clearing the phone's data allowed.
**Changes:** `remote_config.dart`: `videoAspectRatio`, `paywallSubtitle`, `featureIcons` (paired by position), `showStrikePrice`, `accentColor`, `autoPayText` with `{trial}`/`{recurring}` and `autoPayStatement`, `socialProofIcon`, `ctaText`, `upiSelectText`, `upiSheetTitle`, parsed from ten new `paywall_*` rows with fallbacks. `paywall_screen.dart`: the video card is sized by `previewCardSize` from the backend shape (default 1:1), the video fitted inside, the picture shown as a poster while loading and in the same box on failure; subtitle; `_ConfigIcon` (https image or a name from `kPaywallIcons`, falling back on error); `_Accent`; strike price switch; the texts. New `supabase/migrations/20261019120000_paywall_controls.sql` (not pushed). 11 new tests.
**Why:** the card was 16:9 until the video reported its shape; the live video is square (1080×1080), so on the test phone the card grew from about 175 to 312 px and pushed the price down. Only settings can give the shape before any byte arrives. Icons are a fixed name list because release builds tree-shake icon fonts.
**Verified:** `flutter analyze` one info (`package_names`); `flutter test` 123 of 123. On the SM-M127G with a test-mode build seeded with the live settings: screen captures every ~0.3 s show the card at the same bounds (y 273–903) and the price at the same place while empty, with the poster, and playing. A normal launch autoplays (Maestro's detach paused it in the captured run). With every new setting seeded: subtitle, red accent, four icons incl. an image link, no strike price, reworded AutoPay sentence with the prices, social-proof icon, "Start Trial", sheet title all shown; a square video in a 4:5 card shows bands, no resize. `onboarding_deeplink` passed (32 steps); `check-syntax` OK. Phone reset to the notes app with no data afterwards (owner allowed).
**Docs updated:** 09-deep-link-onboarding (paywall row, AutoPay sentence, icons, video card, settings table, backend table, tests), 08-e2e-testing (flow status), ai/AGENT_CONTEXT (rule 16, file table, tests, Maestro, state).
**Follow-ups:** migration pushed (next entry). Consider a 720 px, 2–3 MB copy of the video. The "Try Now" button follows `theme_color`, not `paywall_accent_color`.

---

## 2026-10-14 — Notes title on the avatar's row; delete_and_undo fixed

**Request:** put "Notes" in line with the profile avatar and move the content up.
**Changes:** `notes_list_screen.dart`: `SliverAppBar.large` replaced by a pinned `SliverAppBar` (72 high) whose title is "Notes" in `headlineMedium` bold, level with the avatar; the count's padding matches the title. `.maestro/flows/delete_and_undo.yaml`: the swipe has `duration: 100`.
**Why:** the large bar left a tall empty band above the notes. The flow's slow swipe from the title stopped at the element's edge, short of `Dismissible`'s 40% threshold; a fling dismisses regardless of distance. A real swipe (`adb shell input swipe`) deleted a note and showed Undo, so the app was not at fault.
**Verified:** on the SM-M127G: screenshot of the new header; Maestro `create_note`, `edit_note`, `delete_and_undo`, `empty_note_is_discarded` all pass. `check-syntax` OK on the changed flow. `flutter analyze` one info (`package_names`); `flutter test` 112 of 112. Both leftover test notes deleted; the account has only the user's own note.
**Docs updated:** 03-app-flow (list header), 07-known-issues (Maestro row), 08-e2e-testing (status, flick note), ai/AGENT_CONTEXT (flow status), this log.
**Follow-ups:** `profile_logout` not run (signs the phone out).

---

## 2026-10-14 — Notes interface redesign

**Request:** make the notes app's UI more attractive without changing any feature.
**Changes:** new `lib/theme.dart` (`buildNotesTheme`: the launcher icon's violet with the fidelity scheme, amber accent, Poppins, rounded cards, buttons, dialogs and floating snackbars), used by `main.dart`. Poppins Regular/Medium/SemiBold/Bold and `OFL.txt` in `assets/fonts/`, registered in `pubspec.yaml`. New `widgets/evos_mark.dart` (the launcher icon drawn from the SVG's geometry) and `widgets/user_avatar.dart`. `sign_in_screen.dart`: soft violet glow, the mark, three feature lines, a full-width button at the bottom, tinted banners. `notes_list_screen.dart`: `SliverAppBar.large`, the avatar as the profile button, note count, card list, rounded swipe background, new empty and error states. `note_tile.dart`: a card with title, three-line preview and time; title and preview in their own full-width `Semantics(container: true)`. `note_editor_screen.dart`: large title, accent rule, filled round Save button. `profile_screen.dart`: violet gradient header, User ID card, full-width Log out. The onboarding screens are untouched (`BrandShell` builds its own theme).
**Why:** the old theme was a generic indigo that matched neither the icon nor the website. Every text, identifier, tooltip and behaviour is kept, so the flows and tests still apply. The card's texts needed their own semantics nodes: merged, the title could not be found by Maestro (the old `ListTile` merged the same way, which no flow had reached before).
**Verified:** `flutter analyze` one info (`package_names`); `flutter test` 112 of 112. List, editor and profile looked at on the SM-M127G in light and dark (dark mode set with `cmd uimode` and put back); sign-in rendered in a throwaway widget test in both modes, then deleted. Maestro: `create_note`, `edit_note`, `empty_note_is_discarded` pass. `delete_and_undo` failed (the swipe from the title fell short); fixed by making the title full width, but the phone disconnected before a rerun. `profile_logout` not run. Three leftover test notes from failed runs were deleted; one, "Maestro undo 1791976758301", is still in the account.
**Docs updated:** 01-overview (theme), 02-architecture (new files), 03-app-flow (what each screen shows), 06-conventions (new "Look" section), 07-known-issues (Maestro and analytics rows), 08-e2e-testing (status, semantics note), ai/AGENT_CONTEXT (file table, rule 11, state).
**Follow-ups:** see the next entry for `delete_and_undo` and the leftover note. The website's drawn notes list still shows the old look.

---

## 2026-10-14 — End-to-end check of the notes app

**Request:** verify whether the notes app works end to end. Notes features only, not onboarding (the user stopped a run of the whole `.maestro` folder for that reason).
**Changes:** none in the code. Built a test-mode debug APK (`--dart-define=SUPABASE_URL=`) and installed it on the SM-M127G. Cleared the app's data with `./tool/deeplink.sh --reset`, because the phone was still in the onboarding stage from earlier testing.
**Verified:** `flutter analyze` one info (`package_names`); `flutter test` 112 of 112. Maestro's driver starts again. `create_note` failed at Google sign-in: the account sheet opened, the account was tapped, then sign-in came back as a cancel ("Sign-in keeps getting dismissed"). The other four notes flows were not run, since all start with the same sign-in. Nothing after sign-in has run on a device: creating, editing, deleting and undo, the empty-note discard, profile and log out are covered by widget tests only.
**Docs updated:** 08-e2e-testing (status of the notes flows), ai/AGENT_CONTEXT (Maestro and sign-in state, onboarding-stage reset note).
**Follow-ups:** add a personal Google test account to the phone, and confirm the debug SHA-1 `67:1C:D4:1B:BC:14:83:62:08:A8:C4:72:A8:CA:ED:3A:DC:3B:D9:D3` is registered in Firebase. Then run the five notes flows one by one.

---

## 2026-10-14 — Public website (notes app only)

**Request:** a simple HTML website like the owner's other apps, showing only the notes features and not the second (onboarding) part.
**Changes:** new `website/`, modelled on `../cash_alert/website` (plain HTML, one stylesheet, Poppins): `index.html` (hero with the notes list drawn in HTML, six features, three steps, FAQ), `privacy-policy.html`, `terms-of-service.html`, `delete-user-data.html`, `contact.html`, `404.html`, `css/styles.css`, `robots.txt`, `.htaccess`, and `assets/` (favicon and logo sized from `tool/app_icon/`). Operator `Spacewire` (owner's answer). The pages were generated once by a script kept outside the repo; edit the HTML directly.
**Why:** every claim on the home page is a notes behaviour from 03-app-flow. The legal pages describe all data the app collects, including mobile number, SMS, Supabase, Cashfree, Mixpanel, Meta and the advertising ID, in general terms and without saying who sees which interface: a privacy policy that left them out would be false for some users and fails Play's requirements. The Play button's referrer carries only `utm_` keys, so it never starts onboarding.
**Verified:** no broken local links; no page contains "onboarding", "paywall", "maintenance", `notes://` or `flow=`. Home looked at in headless Chrome at 1280 px and at 390 px (in an iframe, because headless Chrome will not size a window below 500 px); privacy at 390 px. One fix from that: the drawn phone's text was centred on narrow screens. `flutter test` 112 of 112; `flutter analyze` one info (`package_names`, from `name: Evos` in `pubspec.yaml`, not from this task). Not uploaded; `.htaccess` untested on a host.
**Docs updated:** 01-overview, 07-known-issues (new Website section; deletion gap; removed the stale app-label line), README (what-to-update row), ai/AGENT_CONTEXT (rule 25, file table, state, test count, git line).
**Follow-ups:** the real support email (replace `support@evos.example` everywhere), a domain (then canonical URLs, Open Graph image, sitemap), owner review of the legal text, upload.

---

## 2026-10-14 — "Something went wrong on our side" when paying: diagnosis

**Request:** find the real cause of the error shown when paying, and plan the fix.
**Found:**
- The message is what the app shows for any `BackendError.server`, so it said nothing about the cause.
- The attempt was not in the test phone's log: the app's data had been cleared since (the log shows a fresh install attribution and the notes sign-in screen).
- Probing `cashfree-webhook` without a signature (it loads the settings before checking the signature) answered 401 "Invalid webhook signature", so `cashfree_app_id` and `cashfree_secret_key` are both non-empty. Their values were not read.
- Remaining causes, from the function's code: `customer_email_domain` empty; `cashfree_environment` still `sandbox` with CashAlert's production keys (Cashfree answers 401); a stray `$0` or space pasted into the id or secret, as happened with three other rows; a plan or request Cashfree refuses.
**Changes:** `create-cashfree-subscription` returns a `code` with every failure (redeployed). `BackendFailure.code`; the app shows "Error code: …" under the message and uses the code as the analytics `reason`. One widget test added.
**Verified:** `flutter analyze lib` clean. The test suite was not run: it cannot load while `pubspec.yaml` has `name: Evos`. Debug and release APKs built; debug installed on the test phone with its log cleared.
**Docs updated:** 09-deep-link-onboarding, 10-analytics.
**Follow-ups:** the owner retries the payment and reports the code.

## 2026-10-14 — Evos logo and app icon

**Request:** create a logo for the app and use it as the app icon.
**Changes:**
- The mark: a white "E" (stem and three rounded arms, the middle one shorter) with an amber spark at the top right, on a violet gradient (#7C3AED to #4C1D95, matching the default `theme_color`). Drawn on the 108-unit adaptive-icon grid.
- `tool/app_icon/evos_square.svg`, `evos_rounded.svg`, `evos_circle.svg`, and `make_icons.sh`, which renders them with Quick Look and resizes with `sips` into all Android legacy mipmaps (`ic_launcher`, `ic_launcher_round`) and the 15 iOS icons (alpha removed, as the App Store requires), plus `evos_logo_1024.png` and `evos_icon_512.png`.
- Android 8+: adaptive icon in `mipmap-anydpi-v26/` from vector `drawable/ic_launcher_foreground.xml` and `ic_launcher_background.xml`, with a `monochrome` layer for themed icons. Manifest gained `android:roundIcon`.
- The link fallback page shows the same mark.
**Why:** no image tool is installed; a Flutter canvas renderer run as a test hung in `toImage`, so it was replaced by the SVG and Quick Look route.
**Verified:** the iOS PNGs have no alpha channel. `aapt2 dump badging` of the new debug APK: label "Evos", icon `res/mipmap-anydpi-v26/ic_launcher.xml`. The APK is installed on the test phone; the home screen was not looked at, to avoid disturbing the owner's use of the phone. `flutter analyze` and `flutter test` were not run: they fail while `pubspec.yaml` has `name: Evos` (see the previous entry), a change awaiting the owner's decision.
**Docs updated:** 01-overview, 07-known-issues, 09-deep-link-onboarding, AGENT_CONTEXT.
**Follow-ups:** look at the icon on the home screen; restore `name: notes` once allowed.

## 2026-10-14 — App renamed Evos

**Request:** change the app name to Evos everywhere instead of notes.
**Changes:** Android `android:label` "Evos"; iOS `CFBundleDisplayName` and `CFBundleName` "Evos"; `MaterialApp.title` "Evos" (recent-apps name in the notes interface); startup error "Evos couldn't start"; the notes sign-in screen heading "Evos".
**Kept, on purpose:** the package id `com.spacewire.notes` (changing it makes a different app: Firebase, the Cashfree whitelist, `assetlinks.json` and installed copies all name it), the Dart package `notes`, the Firebase project, the link domain `notes-f36b3.web.app`, and words that describe notes as a feature ("Notes" over the list, "New note"). The launcher icon is still Flutter's default.
**Verified:** not by tests: `pubspec.yaml` was changed by someone else to `name: Evos`, which breaks every `package:notes/` import, so `flutter analyze` reports 241 errors and the tests do not load. Restoring `name: notes` was proposed to the owner and awaits an answer. The debug APK builds with the new name.
**Docs updated:** 01-overview, 03-app-flow, 07-known-issues, 09-deep-link-onboarding.
**Follow-ups:** an Evos launcher icon.

## 2026-10-14 — "Reset deep-link flow" removed everywhere

**Request:** remove the reset deep-link flow button from everywhere.
**Changes:** the debug-only button is gone from the mobile-number and maintenance screens; `OnboardingController.reset()` and `OnboardingStore.clear()`, used only by it, are deleted. The test of the reset is replaced by one checking no screen offers a way back.
**Consequence:** in every build, the only way back to the notes app is clearing the app's data (`./tool/deeplink.sh --reset`, or Android settings), which also clears `install_referrer_checked`, so a referrer install would re-enter onboarding on the next launch.
**Verified:** `flutter analyze` clean, 111 of 111 tests. Debug APK rebuilt and installed on the test phone.
**Docs updated:** 05-setup-and-build, 09-deep-link-onboarding.
**Follow-ups:** none.

## 2026-10-14 — "Log out" removed from the paywall

**Request:** remove the logout button from the paywall.
**Changes:** `paywall_screen.dart`: the header is the logo and name only; `paywall_logout_button` is gone. Log out remains on the maintenance screen. The flow and analytics tests that logged out from the paywall now do it from maintenance; one new test checks the paywall has none.
**Consequence:** a signed-in user who has not paid cannot change their number from inside the app; clearing the app's data is the only way.
**Verified:** `flutter analyze` clean, 111 of 111 tests.
**Docs updated:** 02-architecture, 08-e2e-testing, 09-deep-link-onboarding, AGENT_CONTEXT.
**Follow-ups:** none.

## 2026-10-14 — Paywall video sized to its own shape

**Request:** the video was cropped; size the card to the video's ratio.
**Changes:** `_PreviewVideo` in `paywall_screen.dart` no longer uses a fixed 180-high card with cover fit. The card is full width at the video's aspect ratio, capped at 45% of the screen height (narrower and centred if capped), 16:9 until the video has loaded.
**Verified:** `flutter analyze` clean, 110 of 110. On the test phone (debug build, opened without any input sent): the backend's video shown whole, about square, under the heading. The backend logo now shows in the header too, after the owner corrected its URL.
**Seen, not explained:** in both screenshots the video showed the play button, not playing, although the player had asked for audio focus, which it does on `play()`. Whether it autoplays when the owner opens the paywall has not been confirmed.
**Docs updated:** 09-deep-link-onboarding.
**Follow-ups:** confirm autoplay on the phone.

## 2026-10-14 — Country selector on the mobile-number screen

**Request:** a country code selector, because users can be from any country.
**Changes:**
- New `lib/models/country.dart` (`Country`, about 190 countries, flags from ISO codes, India default).
- `validators.dart`: `normalizeNationalNumber` / `validateNationalNumber`; India keeps its strict rule, others get 6 digits to the E.164 limit, trunk 0 and pasted code removed.
- `PhoneAuthState` carries the `country`; `requestCode(country, phone)`; E.164 built from it. The code screen shows the chosen code.
- `phone_screen.dart`: flag, code and chevron in the field (`country_picker`), searchable sheet; per-country formatter; a number invalid for the new country is cleared.
- `OTP Requested` gained `country` (ISO code). New `BackendError.countryNotSupported` and its message.
- `sms-hook` refuses non-Indian numbers with `sms_country_not_supported` (HTTP 422) instead of sending them to Fast2SMS; redeployed.
- Tests: 3 widget, 4 unit. 110 total.
**Why:** the selector was asked for, but delivery and payment are India-only (Fast2SMS DLT, UPI AutoPay). A clear refusal beats a code that never arrives.
**Verified:** `flutter analyze` clean, 110 of 110. Debug build installed on the test phone; a screenshot showed the country sheet open, being used by the owner at the time, so no further input was sent to the phone.
**Not verified:** a non-Indian number against the live hook (the refusal path has not run for real), and how Supabase Auth passes the hook's message through: the app recognises it by text.
**Docs updated:** 02-architecture, 07-known-issues, 08-e2e-testing, 09-deep-link-onboarding, 10-analytics, AGENT_CONTEXT.
**Follow-ups:** decide whether other countries should be served (second SMS provider, a non-UPI payment) or the list cut to India.

## 2026-10-14 — Mobile-number screen redesigned around app screenshots

**Request:** the screen "is not looking good"; make it professional. Then: the carousel shows app screenshots of the use cases.
**Changes (`phone_screen.dart`):**
- Header with the small logo and name; one heading ("Welcome to <name>") with a shorter subtitle.
- Carousel as one rounded card taking all spare height: title on top in the brand colour, the screenshot shown whole (`BoxFit.contain`) with phone-like rounded corners and a shadow, pill-shaped dots; on a light tint of the brand colour, because the fidelity scheme's container colour is nearly as dark as the brand. Images are decoded at drawn height (`cacheHeight`); the next page stays built (`allowImplicitScrolling`) instead of precaching full-size files. Phone-shaped placeholder while loading or on error.
- New `_PhoneField`: `+91` and a divider always visible, sample-number hint, no border until focused.
- "Send code" moved directly under the field, with "We'll send a 6-digit code by SMS." under it. Debug reset made small.
- Layout: the form keeps its own height (scrolling only if the keyboard leaves less), and the carousel takes the rest, removing the empty band under the form.
**Verified:** `flutter analyze` clean, 103 of 103 tests. On the test phone (debug build): the card, field and button as intended; with the keyboard open the carousel hides, the field keeps focus and the form fits above the keyboard. The backend's three slide URLs (`https://placehold.co/360x720$0`) return 404 because of the stray `$0`, so only the placeholder has been seen, not a real screenshot.
**Mistake:** a tap sent with adb to open the keyboard landed on "Reset deep-link flow (debug only)", which returned the phone to the notes app and cleared its Evos sign-in. The link was reopened, so the phone is back on the mobile-number screen, signed out.
**Docs updated:** 09-deep-link-onboarding.
**Follow-ups:** fix the slide URLs; look at real screenshots on the phone.

## 2026-10-14 — Carousel on the mobile-number screen, images from the backend

**Request:** the login screen carousel CashAlert has, with the image URLs managed by the backend.
**Changes:**
- `RemoteConfig.loginSlides` (`LoginSlide`: image URL and title), from the public rows `login_slide_images` and `login_slide_titles`, `|`-separated and paired by position; non-https images dropped after pairing.
- `phone_screen.dart`: `_LoginCarousel` (title above, `PageView` of images, dots; advances every 2 s like CashAlert's `AUTO_SLIDE_INTERVAL_MS`, swipeable, timer restarts after each change, images precached). With slides the screen takes CashAlert's layout, centred, and the field no longer autofocuses; the carousel hides while the keyboard is open. The form keeps one position in the tree in both states, so the field keeps focus.
- Migration `20261014130000_login_slides.sql`, applied with `supabase db push`.
- Tests: four widget tests, one parsing test. 103 total.
**Verified:** `flutter analyze` clean, 103 of 103. Release APK (59.1 MB) built and installed on the test phone. Both rows readable with the publishable key.
**Not verified:** the carousel on a phone; both rows are blank.
**Docs updated:** 02-architecture, 08-e2e-testing, 09-deep-link-onboarding, AGENT_CONTEXT.
**Follow-ups:** fill the two rows and look at the screen on the phone.

## 2026-10-14 — A link testers can open without the Play Store

**Request:** a deep link to share with the team, with the APK, that opens the Evos flow.
**Changes:** new Firebase Hosting site for `notes-f36b3.web.app`: `firebase.json` (`appAssociation: NONE`), `.firebaserc`, `web_links/.well-known/assetlinks.json` (package and the debug-key SHA-256, which signs both APKs), `web_links/onboarding/index.html` (fallback page with an `intent://` button naming the package), `web_links/index.html`. `.firebase/` git-ignored.
**Why:** a sideloaded app gets no install referrer, the `notes://` link exists only in debug builds and is not tappable in chat apps, and the HTTPS link opens a browser unless the domain is verified. Hosting `assetlinks.json` verifies it for every phone that installs the APK afterwards.
**Verified:** the JSON files parse; the SHA-256 matches `~/.android/debug.keystore`. The domain currently answers "Site Not Found".
**Not verified:** not deployed (the Firebase CLI is not installed; deploying is the owner's step), so neither verification nor the fallback page has been seen on a phone.
**Docs updated:** 09-deep-link-onboarding, AGENT_CONTEXT.
**Follow-ups:** deploy, then reinstall the APK on the test phone and check `adb shell pm get-app-links com.spacewire.notes` reports the domain verified.

## 2026-10-14 — Preview video on the paywall, URL from the backend

**Request:** add the video section to the paywall, as CashAlert has, with the URL managed from the backend.
**Changes:**
- `pubspec.yaml`: `video_player` ^2.11.1 (resolved 2.11.1, from the local cache).
- `RemoteConfig.previewVideoUrl`, read from the public `app_config` row `paywall_video_url` (https only).
- `paywall_screen.dart`: `_PreviewVideo`, in the preview card's place. Autoplays with sound, loops, cover-fit, tap to pause or play, spinner while loading, paused while a payment runs. Falls back to the picture, or no card, when it cannot play.
- New migration `20261014120000_paywall_video.sql` (the row, blank), applied to the Evos project with `supabase db push`.
- Tests: one widget test (a video that cannot play leaves a working paywall), parsing assertions. 98 total.
**Why:** one URL rather than CashAlert's per-language `subscription_videos` table, because Evos has one language. Sound on, because CashAlert's plays with sound.
**Verified:** `flutter analyze` clean, 98 of 98 tests, release APK built (59 MB) and installed on the test phone. The row is readable with the publishable key. CashAlert's public preview video answers with `video/mp4`.
**Not verified:** playback on a phone; the row is still blank.
**Docs updated:** 01-overview, 02-architecture, 07-known-issues, 09-deep-link-onboarding, AGENT_CONTEXT.
**Follow-ups:** fill `paywall_video_url` and look at the paywall on the phone.

## 2026-10-14 — Readiness check before sending an APK to a tester

**Request:** is the Evos flow working fine, and how to send a debug APK to a tester.
**Changes:** none to code.
**Verified:**
- The owner signed in again with the same number: `OTP Verified` with `new_user: false`, paywall shown.
- Fresh `flutter build apk --debug` (192 MB) and `flutter build apk` (58 MB). The release APK was installed on the test phone, opened from `https://notes-f36b3.web.app/onboarding`, stayed signed in after a force-stop and showed the paywall, with no crash in the log. It is now the build on the test phone.
- The paywall offered no UPI app on the test phone. Paytm is installed but has never been opened (`stopped=true notLaunched=true`), and Android resolves no activity for `upi://pay`, so this is the phone's state; detection on a phone with a set-up UPI app is unchecked.
**Not verified:** "Try Now" has still never been tapped against Cashfree.
**Docs updated:** 07-known-issues, AGENT_CONTEXT.
**Follow-ups:** first real payment; the Evos webhook; the CashAlert webhook fix; an Evos SMS template.

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
