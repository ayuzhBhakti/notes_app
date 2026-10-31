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

## 2026-10-31 — Two shareable guides: admin panel and Mixpanel events

**Request:** two simple docs to share: how to use the admin panel, and every Mixpanel/backend event. Markdown files, not Claude artifacts.
**Changes:** `docs/ADMIN_PANEL_GUIDE.md` (for admins: unlocking, adding a source, every field from `admin/form.js` with what it changes, the rules — blank inherits except login slides, the Cashfree plan id overriding the monthly charge, hiding, when changes show, Meta installs arriving as `apps.facebook.com` — install links, preview, common problems). `docs/MIXPANEL_EVENTS_GUIDE.md` (for the team: how tracking works, the journey, the ad fields, all 27 app events, the 4 server events, the 3 Facebook events, the profile, reports, rules, what is live). Linked from `docs/README.md`, and added to its "keeping docs current" table. Two empty Claude Docs had been created before the user asked for files ("Evos Admin Panel Guide", "Evos Mixpanel Events Guide"); left for the user to delete.
**Verified:** every field, label and button name read from `admin/index.html`/`admin/form.js`; every event from `lib/services/analytics.dart` and `docs/10-analytics.md`. Not reviewed by an admin.
**Docs updated:** `docs/ADMIN_PANEL_GUIDE.md` (new), `docs/MIXPANEL_EVENTS_GUIDE.md` (new), `docs/README.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** the admin panel needs a hosted address and `admin_panel_secret` before an admin can use it.

---

## 2026-10-31 — "App bar space" on the web page: checked in the app and the admin preview

**Request:** the web page still seemed to keep the app bar's space; check the app and the admin panel.
**Found:** *Admin preview:* the live-site layer was placed at a fixed `top: 84px` (28 px status bar + the old 56 px app bar), so a 56 px gap stayed. Fixed in `admin/preview/preview.css` to `top: 28px`. *App:* no gap. A test-mode build of the current code on the test phone, seeded onto the web stage, shows the WebView starting right under the status bar. The bar seen at the top (logo, "Evos", ☰) is **the website's own header**, part of the page at the global `webview_url` (`subtle-sopapillas-a755d8.netlify.app`). That site also still describes the old Google-sign-in notes app.
**Verified:** screenshots on RZ8T606RJ0N (loading, then loaded). The admin change was not opened in a browser.
**Docs updated:** `docs/ai/TASK_LOG.md`.
**Follow-ups:** the site's header and copy are the website's to change, not the app's. The test-mode build is still installed on the test phone (uninstall it before a Play install).

---

## 2026-10-31 — Admin preview: web page without the app bar

**Request:** the admin panel's phone preview still showed the web page's app bar, removed from the app earlier today.
**Changes:** `admin/preview/screens.js` `web()` no longer draws the bar (brand header, Reload, ⋮ menu) in either state (page set, or "You're all set"). `appBar` stays for the code screen's back arrow. The "Website link" field highlights the page area, which is unchanged.
**Why:** the preview is a hand-made copy of the screens; the app-bar removal (entry below) missed it. A screen change must be mirrored in `admin/preview/` (09-deep-link-onboarding.md).
**Verified:** rendered `renderScreen("web", …)` with and without `webview_url`: no `appbar`, no `refresh`, no `more_vert`, content present. `deno test admin/preview/resolve.test.js` 20/20. Not opened in a browser.
**Docs updated:** `docs/ai/TASK_LOG.md`.
**Follow-ups:** none.

---

## 2026-10-31 — Login slides: a source never inherits the global carousel

**Request:** if a `webview_sources` row has no `login_slide_images`/`login_slide_titles`, show no carousel; it was showing the global `app_config` slides.
**Changes:** `SupabaseEvosBackend.mergeSourceRow` blanks `login_slide_images` and `login_slide_titles` before laying a matched row on top (`_sourceOnlyColumns`), so a source shows only its own slides and none when its columns are NULL. Every other column still inherits on NULL. Installs that match no row (organic, unknown, unmatched source) still get the global slides. Mirrored in the admin preview (`mergeRows` in `admin/preview/resolve.js`) and its help text (`admin/form.js`). Tests: two in `onboarding_logic_test.dart` (no slides → empty carousel; own slides → shown); `admin/preview/resolve.test.js` (one new, one updated).
**Verified:** `flutter analyze` clean; `flutter test` 183/183 (the no-slides test failed first); `deno test admin/preview/resolve.test.js` 20/20 (failed first). Not run on a phone. A phone that already cached the global slides switches on its next settings fetch, and the sign-in layout (frozen per launch) follows on the launch after.
**Docs updated:** `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** ships with the next build (it is app code, not a backend setting).

---

## 2026-10-31 — Release readiness check (1.0.3+4)

**Request:** check whether the app is ready for release.
**Verified:** `flutter analyze` clean; `flutter test` 181/181; `deno test` 29/29; `check-syntax` OK on both flows. `flutter build appbundle` succeeded: `app-release.aab` 62.6 MB, version `1.0.3+4` (above live versionCode 2), signed by `CN=Spacewire`, SHA-256 `C3:40:52:4B…`, the upload key. On the test phone (RZ8T606RJ0N, Evos not installed before), a test-mode debug build passed **Maestro `review_account` (1m 46s) and `onboarding` (1m 28s)**. Uninstalling it afterwards was refused by the permission system, so it is still on the phone. Live backend: Cashfree production with id/secret set, plan set, SMS settings set, `webview_url` set, Meta key and Mixpanel token set; all six functions active. Live ledger: 6 successful ₹3 trials (last 2026-10-30), 7 failed trials, 1 failed monthly debit.
**Not ready yet (non-code):** (1) the code is uncommitted on `feat/ad-attribution` (44 files, including separate admin-panel work) and should be committed and merged before the upload build; (2) the live `paywall_show_strike_price` is still `true`; (3) the Play listing, screenshots and `website/` still describe a notes app (Play metadata policy); (4) the review number gets a different app (cloaking risk, owner accepted); (5) the privacy policy update is not uploaded anywhere (no domain), and Play's Data safety form must cover phone number, payments, app activity, device/advertising ID and ad attribution; (6) not exercised on a phone in a real-backend build: the Meta decode (needs a Play install), the no-strike paywall.
**Docs updated:** `docs/ai/TASK_LOG.md`, `docs/ai/AGENT_CONTEXT.md`.
**Follow-ups:** the six items above; uninstall the test build from the phone before the Play internal-track install.

---

## 2026-10-31 — Paywall: struck-through monthly price off by default

**Request:** remove the struck-through ₹299 on the paywall ("not needed").
**Changes:** it is the backend switch `paywall_show_strike_price`, so the switch stays and its default flips: `RemoteConfig.showStrikePrice` defaults to `false` (blank, missing or unreadable = hidden; `true` still shows it). Mirrored in the admin panel preview (`admin/preview/resolve.js`, default `false`) as 09-deep-link-onboarding.md requires. The AutoPay sentence, which states the monthly price, is untouched (rule 16). Tests: the two paywall widget tests now expect no `₹299`/`₹499` on its own; new "the backend can turn the struck-through price back on"; logic tests expect the `false` default; `admin/preview/resolve.test.js` likewise.
**Not done:** setting the live `app_config.paywall_show_strike_price` from `true` to `false` was **refused by the permission system**. The live row is explicitly `true`, which overrides the new default, so the struck price keeps showing until the owner sets it to `false` (Table Editor). No `webview_sources` row overrides it.
**Verified:** `flutter analyze` clean; `flutter test` 181/181 (the changed expectations failed first); `deno test admin/preview/resolve.test.js` 19/19 (failed first). Not run on a phone.
**Docs updated:** `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** the owner sets the live row to `false`.

---

## 2026-10-31 — Web page screen: app bar removed

**Request:** remove the app bar from the web page screen ("not needed"). Asked whether Log out (only there, plus Reload) should go too; the owner chose to remove it.
**Changes:** `lib/screens/onboarding/web_screen.dart`: no `AppBar` (it held the logo and name, Reload, and a ⋮ menu with Log out); the body is in a `SafeArea`; the WebView is keyed by `ValueKey(url)` instead of a `GlobalKey` that only Reload used; `brand.dart` import dropped. The failed-load "Try again" keeps its own reload. Tests: `onboarding_flow_test.dart` replaces "Log out on the web page returns to the number" with "the web page is full screen: no app bar, Log out or Reload", and "Check again" now expects no app bar; `analytics_test.dart`'s "logging out is tracked, then the identity is reset" goes through the review account's Profile Log out (same `OnboardingController.signOut`). `.maestro/flows/onboarding.yaml` asserts the menu and Log out are gone instead of logging out.
**Why:** owner's decision. Consequence, accepted: subscribers have no Log out anywhere (paywall none since 2026-10-14); switching numbers needs clearing the app's data. `Signed Out` now fires only for the review account.
**Verified:** `flutter analyze` clean; `flutter test` 180/180 (the two new expectations failed first); `./tool/maestro.sh check-syntax .maestro/flows/onboarding.yaml` OK. Not run on a phone (the flow needs a test-mode build).
**Docs updated:** `docs/09-deep-link-onboarding.md`, `docs/08-e2e-testing.md`, `docs/03-app-flow.md`, `docs/10-analytics.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** none.

---

## 2026-10-31 — Meta decryption key set on the live project; function deployed and verified

**Request:** put the owner's Install Referrer Decryption Key in the backend and check that it works.
**Changes:** `supabase secrets set META_INSTALL_REFERRER_KEY` was refused (the CLI account lacks the privilege for project secrets). Instead inserted the single private row `app_config.meta_install_referrer_key` (`is_public = false`) with `supabase db query --linked`; confirmed 64 hex characters without printing it. The migration `20261031120000` was **not** pushed (its insert is `ON CONFLICT DO NOTHING`, so pushing it later keeps the key). `supabase functions deploy meta-install-referrer --no-verify-jwt` was **refused by the permission system** (production deploy), so the function is not live. No file in the repo contains the key.
**Verified:** locally, the function's own `decodeMetaReferrer` with this key decrypts a sample encrypted with it (campaign, ad set, ad and 18-digit ids exact) and refuses another app id (`other_app`). That proves the key's format and the decrypt path, not that Meta encrypts with this key: only a real Meta ad-click referrer can show that. `supabase functions list`: `meta-install-referrer` absent.
**Docs updated:** `docs/ai/TASK_LOG.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/07-known-issues.md`, `docs/09-deep-link-onboarding.md`.
**Then:** the owner deployed `meta-install-referrer` (v1, ACTIVE, `verify_jwt = false`). Live checks, plain POST with no auth header (as the app calls it before sign-in): organic referrer → `200 {"ad":null}`; Meta source with junk content → `422 decrypt_failed`; a sample encrypted with the configured key → `200` with campaign, ad set, ad and the 18-digit ids exact (so the live function reads the key row and decrypts); another app's id → `422 other_app`.
**Then (owner: "deploy that also"):** `supabase db push` applied `20261031120000_user_attribution.sql` (dry run first: the only pending migration). Checked live: the 11 `profiles` columns exist; `save_user_attribution` is `SECURITY DEFINER`, `search_path=public`, executable by `authenticated` and not `anon`; `profiles` still has only `profiles_select_own`; `meta_install_referrer_key` kept (64, private). Filled the private `mixpanel_token` row with the app's own token from `analytics_keys.xml` (32 hex, `is_public = false`). `deno check` clean on both payment functions, 29/29 Deno tests. `supabase functions deploy cashfree-webhook` was **refused by the permission system** (production deploy), so `cashfree-webhook` (v2) and `verify-cashfree-subscription` (v1) still run the old code: no server Mixpanel events yet. Nothing breaks meanwhile: the old functions do not read the new columns.
**Then:** the owner deployed both: `cashfree-webhook` v3 (`verify_jwt = false`) and `verify-cashfree-subscription` v2 (`verify_jwt = true`), 2026-10-31 16:24. Smoke checks that cannot touch a payment: unsigned webhook → `401 Invalid webhook signature`; verify without auth → `401 UNAUTHORIZED_NO_AUTH_HEADER`; `meta-install-referrer` organic → `200 {"ad":null}`. Live data: 0 of 40 profiles have an ad (expected until the app release); no payment recorded since the deploy, so no server Mixpanel event has fired yet.
**Follow-ups:** watch for the first `Payment Succeeded` in Mixpanel (and `mixpanel` lines in `supabase functions logs cashfree-webhook`); the app release (version bump, `.aab`, Play upload); a real Meta ad-click install to prove the key; the identity-merge check and the after-release check in `docs/DEEPLINK_GUIDE.md` §5 and §8.

---

## 2026-10-31 — Ad attribution: Meta install referrer decode, attribution model, server Mixpanel events

**Request:** for every user, know which ad they came from and put it on every Mixpanel event (app and backend), so ad → install → sign-in → checkout → trial → paid can be followed. Adapted from the Bhaktilok prompt and guide.
**Changes:**
- **Backend:** `supabase/functions/_shared/meta_referrer.ts` (parse Meta's `utm_content` envelope, check app id `2015134735846694`, AES-256-GCM decrypt with the tag at the end of `data`, map adgroup→ad / campaign→ad set / campaign_group→campaign, ids read from raw JSON as text). New function `meta-install-referrer` (`verify_jwt = false` in `config.toml`; 200 `{ad}` / `{ad:null}`, 422 `decrypt_failed`/`other_app`, 400, 500 `not_configured`; stores nothing; non-Meta referrers answered without a DB read; key read from the one private row `meta_install_referrer_key`, cached 60 s, env `META_INSTALL_REFERRER_KEY` fallback; never logs key or referrer). `_shared/mixpanel.ts` (server events with the user's ad from `profiles`, `distinct_id` = user id, `$insert_id` = payment id, 3 s timeout, never throws). `cashfree-webhook` sends `Payment Succeeded`/`Payment Failed` (only when the payment row is newly inserted), `Subscription Cancelled`/`Subscription Expired` (only on a real status change); `verify-cashfree-subscription` sends `Payment Succeeded` for a payment it records first. `payment_type`: trial / auto_renewal / retry. `app_config.ts`: `mixpanelToken`. Also fixed a pre-existing type error in `verify-cashfree-subscription` (`isAuthorizationSuccess` took `string | undefined`, was passed `string | null`; `deno check` failed on `main`; type-only change).
- **Migration** `20261031120000_user_attribution.sql`: `profiles` gains `install_source`, `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content`, `campaign_id`, `adset_id`, `ad_id`, `gclid`, `attributed_at`; `SECURITY DEFINER` RPC `save_user_attribution` (own row via `auth.uid()`, whitelisted `install_source`, length caps, organic/unknown never replaces a known ad; EXECUTE revoked from PUBLIC and anon, granted to authenticated); private rows `meta_install_referrer_key`, `mixpanel_token` (blank). No new write policy.
- **App:** `lib/models/attribution.dart` (one model: install_source meta/google_ads/organic/other/unknown, utm_*, ids, gclid, gad_campaignid → campaign_id; `MetaAd`, `MetaDecodeResult`). `lib/services/attribution_service.dart` (`recordInstallAttribution` in `main()` when Play's answer is final; `AttributionService.start()` after the first frame decodes a Meta click by sending the **full** referrer, retries no-answer/5xx/401/403/404/408/429 on up to 5 launches, settles on other 4xx; reads the referrer once after an update for older installs; `recordLink` for links with utm_*; `syncToServer` via the RPC, per sign-in, skipped for the review account). `InstallSource` now only feeds `install_source_v1` (unchanged behaviour); its parser is shared as `referrerPairs`. `Analytics`: `registerAttribution` (channel `setAttribution`), `installAttributed(Attribution…)` now once per install, new `metaAdAttributed`; `Web Page Viewed`'s `install_source` renamed `config_source`. `EvosBackend.decodeMetaReferrer`/`saveAttribution`. `OnboardingStore` attribution keys. Kotlin `MixpanelSdk`/`AnalyticsChannel`: stores latest + first, re-registers super properties (unregistering stale ones), `people.set` latest (unsetting absent fields), `people.setOnce` first_* + install_source; legacy `install_*` storage kept until the first `setAttribution`.
- **Review** (ecc code-reviewer): 0 critical/high. Fixed: unauthenticated function read all of `app_config` per call; sync marker was per device not per user; late Meta decode overwrote a newer link; duplicate cancel/expire events; stale Mixpanel person fields; failed trial debit reported at the recurring amount. Not changed (spec says stop on 4xx): a wrong key settles installs as `decrypt_failed` for good — logged in 07-known-issues.
- `website/privacy-policy.html`: the ad and Google's click id are kept with the account. Date bumped. Not uploaded.
**Why:** Meta encrypts the ad in the referrer; only a server holding the key can read it. Funnels start at `OTP Verified` because identity merge is unverified.
**Verified:** `flutter analyze` clean; `flutter test` 180/180 (29 new in `test/attribution_test.dart` and updated `analytics_test.dart`); `deno check` clean on all six functions; `deno test --allow-net supabase/functions/_shared/` 29/29 (12 `meta_referrer.test.ts`, 6 `mixpanel.test.ts`, 11 existing), decrypt tested with per-run random keys only; `flutter build apk --debug` builds. **Not run on a phone, not deployed, no real Meta referrer decoded, Mixpanel identity merge not measured** (no Mixpanel access here).
**Deploy plan (owner runs; nothing done here):**
1. `cd notes_app && ~/.local/bin/supabase db push` — applies `20261031120000_user_attribution.sql`. Check: Table Editor → `profiles` has the 11 new columns; `app_config` has blank private `meta_install_referrer_key` and `mixpanel_token`.
2. Table Editor → `app_config`: `meta_install_referrer_key` = the 64-hex key (Meta App Dashboard → Settings → Basic → Android → Install Referrer Decryption Key); `mixpanel_token` = the token in `android/app/src/main/res/values/analytics_keys.xml`. Keep both `is_public = false`. (Or `supabase secrets set META_INSTALL_REFERRER_KEY=…` / `MIXPANEL_TOKEN=…`.)
3. `deno check` each, then `supabase functions deploy meta-install-referrer` (picks up `verify_jwt = false` from `config.toml`), `supabase functions deploy cashfree-webhook`, `supabase functions deploy verify-cashfree-subscription`.
4. Smoke test: `curl -X POST https://sqvlgiqypqvjykczuhgz.supabase.co/functions/v1/meta-install-referrer -H 'Content-Type: application/json' -d '{"referrer":"utm_source=google-play&utm_medium=organic"}'` → `{"ad":null}`. With `utm_source=apps.facebook.com&utm_content=x` → 422 `decrypt_failed` (proves the key is read; a 500 `not_configured` means it is not).
5. Bump the version, build the `.aab`, upload to internal testing; install from Play on a phone with no work account, via a real Meta ad click if possible; check logs for `decoded` and Mixpanel for `Meta Ad Attributed`.
6. After release: the check in `docs/DEEPLINK_GUIDE.md` §8 (≥90% of new Meta installs get `Meta Ad Attributed`; `Checkout Started`/`Payment Succeeded` carry `utm_content`) and the identity check in §5.
**Docs updated:** `docs/DEEPLINK_GUIDE.md` (new), `docs/10-analytics.md`, `docs/09-deep-link-onboarding.md`, `docs/04-data-model.md`, `docs/07-known-issues.md`, `docs/README.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`, `website/privacy-policy.html`.
**Follow-ups:** deploy (above); measure identity merge; decide whether Meta ad installs (`apps.facebook.com`) should get a `webview_sources` row; consider making `decrypt_failed` retryable; the webhook/verify payment-id mismatch; iOS needs SKAdNetwork/AEM (not built).

---

## 2026-10-31 — Admin panel: live phone preview of every onboarding screen

**Request:** show all of the app's screens in the source admin panel and reflect every change live, so the owner knows what a field changes; design the screens to match the mobile app exactly. Plan first.
**Changes (front-end only, `admin/`; nothing deployed, no backend/DB/app change):**
- `admin/preview/resolve.js` (+ `resolve.test.js`, 19 Deno tests): a rule-for-rule JS port of `RemoteConfig.fromRows` (blank/optional/list/paired rules, https-only links incl. Dart's empty-host case, ratio clamp, amount rules, slide pairing, `{trial}`/`{recurring}`, icon names).
- `admin/preview/theme.js` + vendored `vendor/material-color-utilities-0.3.0.js`: `ColorScheme.fromSeed(fidelity)` exactly as `BrandShell`. Checked against Flutter's Dart `material_color_utilities` 0.13.0 for 4 seeds × light/dark: identical hex for every role used.
- `admin/preview/screens.js` + `preview.css`: Sign-in (carousel and plain layouts), Code, Paywall, UPI sheet, Processing, Web page ("You're all set" when no link), at the Flutter widgets' dp sizes, M3 2021 type scale, Roboto, Material Symbols Rounded.
- `admin/preview/preview.js`: big phone that jumps to the focused field's screen, scrolls to it and outlines its part (dashed "appears here" ghost for blank, hidden parts); live rail of all six screens; "All screens" grid; dark mode; slideshow 2 s / social proof 3 s; paywall video kept across re-renders; the web page in a sandboxed frame (no `allow-same-origin`); `stop()` on leaving the editor.
- `admin/form.js` (form code moved out of `app.js`): each field names its screen/part; Default/Custom tag per field; icon picker (28 app icons or an https image) on features and social proof; features are icon+label rows (icon *n* pairs with the *n*-th filled label, as the app does). Upsert payload unchanged (same columns, blank → null).
- `admin/app.js`, `admin/index.html`: wiring, wider editor with sticky preview column, sticky header with Save while editing, floating Preview button on narrow screens, a strict CSP (own scripts only; inline handlers removed).
**Why:** the old preview was one simplified paywall card covering 6 of ~30 fields. The colour library is vendored, not loaded from a CDN, because the page holds the admin password.
**Verified:** `deno test admin/preview/resolve.test.js` 19/19; `deno lint admin/` clean. In Chrome (local server, admin function stubbed in-page so nothing was written; public `app_config` read live): every screen rendered with the real global settings (video, slides, logo, web page); focus → screen jump + outline; ghosts; badge/price/autopay update together; icon picker writes `diamond|ad_free|crown|cloud`; save payload checked; dark scheme `#1F0F12` for `#E91E63` matches Dart; broken images fall back; Enter does not reload; Cancel stops video and unloads the frame; no CSP violations; 390px width has no horizontal scroll. Code review (ecc:code-reviewer): approve; both MEDIUMs (CDN script, no teardown) and the LOWs fixed. `flutter analyze`/`flutter test` were **not** clean, but from unrelated in-progress attribution work already in the tree (`lib/models/attribution.dart`, `install_source.dart`, `test/attribution_test.dart`); no Dart was touched by this task.
**Docs updated:** `admin/README.md`, `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md` (where-things-are row, rule 27, last-verified date), `docs/ai/TASK_LOG.md`.
**Follow-ups:** not deployed to the Netlify panel (`graceful-sundae-161b78`) — owner's call. A self-hosted Supabase URL would need adding to the CSP `connect-src`. The highlight-colour swatch shows the default purple when blank even if the brand colour differs (the preview itself is correct).

---

## 2026-10-26 — Portrait lock + phone-input autofill fix

**Request:** (1) lock the app to portrait (stop rotation); (2) a keyboard-suggested/autofilled number like `917409290026` was keeping only the first 10 digits (`9174092900`) instead of stripping the `91`.
**Changes:**
- **Portrait lock:** `android/app/src/main/AndroidManifest.xml` MainActivity `android:screenOrientation="portrait"` (covers the native splash too); `lib/main.dart` also calls `SystemChrome.setPreferredOrientations([portraitUp])` before `runApp` (Flutter side + iOS).
- **Phone input:** `_IndianMobileFormatter` in `phone_screen.dart` now strips the country code **by length** — exactly 12 digits starting `91` → drop `91`; exactly 11 starting `0` → drop `0` — instead of only on a detected bulk paste (`arrivedWhole`). An autofilled suggestion isn't seen as a paste, which is why the old code fell through to "keep first 10". The length-based rule still never eats the first two digits of a real number that starts with 91 when an 11th digit is typed (only triggers at exactly CC+10).
- Tests: `onboarding_flow_test.dart` (+2) — `919876543210` and `09876543210` both resolve to `9876543210`.
**Verified:** `flutter analyze` clean; `flutter test` 151/151. On device (debug build reinstalled): forced `user_rotation=1` (landscape) → app stayed **portrait** on both splash and paywall (`Orientation: 0`). The autofill path is a single `commitText`, which the widget test covers; not reproducible via incremental `adb input text`, so on-device autofill is for the owner to confirm with their keyboard.
**Docs updated:** `docs/ai/TASK_LOG.md`.
**Follow-ups:** fold these into the next release build; the owner to confirm the keyboard-suggestion autofill on-device.

---

## 2026-10-26 — On-device E2E of the per-source system (Samsung Galaxy M12)

**Request:** 100% end-to-end test of the whole system on the connected physical device.
**Setup:** device had `com.spacewire.evos` 1.0.2+3 (predates Phase A/B) → uninstalled; built + installed a fresh **debug** APK from current code (real backend). Device has WiFi but **no cellular service** (SIM out of service), so no on-device SMS. Seeded a vivid test source `zz_devtest` (DevTest App, green #16A34A, trial ₹11, recurring ₹555) and set `install_source=zz_devtest` via `run-as` (debug).
**Verified on device (screenshots):**
- App launches against the live backend, fetches global config → phone sign-in branded **Evos** (global).
- **Per-source identity overlay:** with `install_source=zz_devtest`, the sign-in screen rebranded to **“Welcome to DevTest App”** with the green theme (name + colour from the live `webview_sources` overlay). The green theme also applied to the Send-code button and OTP boxes.
- **Per-source pricing/overlay on device:** the device's live-fetched config cache held the full overlay — `cashfree_trial_amount=11`, `cashfree_recurring_amount=555`, `plan_name=DevTest Monthly`, `webview_url=…/devtest` — i.e. the paywall would display ₹11/₹555.
- **Review account:** `9931133385`/`123456` → no SMS (intercepted at `providers.dart:567`) → skipped paywall → **local Notes** screen; created and persisted a local note.
**Findings:**
1. **Cashfree is now LIVE in PRODUCTION** (`app_id`/`secret` set, `cashfree_environment=production`). Tapping Try Now would create a real mandate, so the on-device payment step was **not** attempted (user had assumed Cashfree was empty). Documented in AGENT_CONTEXT.
2. **Per-source recurring amount vs. `cashfree_plan_id`:** `buildPlanDetails()` prefers `plan_id` and ignores inline amounts. The global `cashfree_plan_id` is set, so a per-source `cashfree_recurring_amount` changes the **paywall display** but NOT the **actual recurring charge** unless the source also sets its own `cashfree_plan_id` (or the global one is blank). The per-source **trial** (authorization) amount IS honoured.
**Paywall render — DONE (2026-10-26, owner's own number `7409290026`, real SMS, OTP entered by owner):** signed in → **paywall** (the number is a pre-existing account with an expired trial, so not active → paywall). It rendered the full per-source overlay: brand "DevTest App" + green theme; heading "1-Day ₹11 Trial"; subtitle "On-device per-source test"; price ~~₹555~~ **₹11**; autopay line "₹11 today for the first 24 hours, then ₹555 every month…"; CTA "Start DevTest"; features + preview video inherited from global. **"Start DevTest" was NOT tapped** (production Cashfree = real money).
**Not tested:** a real charge (production Cashfree — avoided); the web-page screen (needs an active subscription).
**Cleanup:** `zz_devtest` row deleted (only `facebook`/`filmyface` remain). The owner's `917409290026` profile pre-existed (status `trial`, expired) — left as-is. Device still has the debug build signed in as `7409290026` with `install_source=zz_devtest` cached (row now gone → next fetch falls back to global); offer to reset/reinstall the release.
**Docs updated:** `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`, `docs/09-deep-link-onboarding.md`.
**Follow-ups:** decide how per-source recurring pricing should work given the global `plan_id` (per-source Cashfree plans, or blank the global plan_id); optional paywall visual render with a relay number; a Cashfree **sandbox** charge before trusting per-source pricing end-to-end.

---

## 2026-10-24 — Admin panel UI simplified for non-technical users

**Request:** the admin form was too hard to fill; make it easy for a normal user.
**Changes (front-end only — `admin/index.html`, `admin/app.js`, `admin/config.js`, `admin/README.md`):**
- Removed the per-field **Override checkbox**. New model: **blank = use the app default, filled = override** (blank still sends `null`). Real defaults are read live from public `app_config` and shown as greyed placeholders.
- **Basics** (8 everyday fields) always visible; the other ~21 settings under a collapsed **Show advanced options**.
- Friendlier inputs: colour picker + hex, ₹ price number fields, image fields with thumbnail, Features as up-to-4 rows, Login slideshow as add/remove image+caption rows.
- **Live preview card** (brand colour, logo/name, "₹trial today, then ₹monthly/month", button) updating as you type.
- Plain-language labels/help throughout; clearer list (colour dot + name + source + active/hidden).
- `config.js`/`app.js` use `globalThis` instead of `window` (lint-clean).
**Why:** the override/inherit vocabulary and 29 flat fields were the main friction. Dropped the rare "empty = hide a section" capability (blank now always = default); advanced edits still possible via Table Editor. **No backend change** — `source_config.ts` allowlist/validation unchanged.
**Verified:** `deno lint admin/*.js` clean (no syntax errors). Not run in a browser here; logic traced by hand. Flutter suite unaffected (no Dart touched).
**Deploy:** re-publish the `admin/` folder to Netlify (drag-drop or push if Git-connected). The panel is currently **locked** (`admin_panel_secret` blank from the E2E cleanup) — owner sets it in the Table Editor to use the panel.
**Docs updated:** `admin/README.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** optional browser visual check; Cashfree sandbox test still owed before relying on per-source pricing.

---

## 2026-10-24 — admin-source-config deployed + full E2E against the live backend

**Request:** deploy the admin function and do full end-to-end testing of per-source identity + pricing.
**Changes:** no code. Deployed `admin-source-config` (`supabase functions deploy`, `verify_jwt=false` from config.toml). Set a temporary `admin_panel_secret` to run the tests, then **reset it to blank** (panel locked) so no AI-generated credential is left live — owner sets their own in the Table Editor.
**E2E verified against the live project (all pass):**
- *Read/overlay:* anon REST read of an active source returns full identity + pricing; service-role read (the exact `applySourcePricing` query) returns the same amounts → paywall display == Cashfree charge; inactive row → anon sees 0 (falls back to global); anon INSERT → 401.
- *Device pipeline:* the actual live row → `mergeSourceRow` → `RemoteConfig` = E2E Brand, cyan theme, 2 slides, plan_e2e, ₹7/₹499, AutoPay filled (temp test, deleted).
- *Payment fn:* deployed; unauthenticated POST → 401 (auth guard/verify_jwt intact).
- *Admin fn (over HTTP):* no/wrong secret → 401; correct secret → list; CORS preflight returns `x-admin-secret` in allow-headers; upsert writes identity+pricing and an injected `cashfree_secret_key`/`admin_panel_secret`/`is_public` were dropped (the real `admin_panel_secret` row stayed intact); validation 400s for bad colour / non-https / zero amount / bad source; delete → 200. Blank secret → 401 (safe lock).
- *Suites:* Flutter 149/149, Deno `source_config.test.ts` 11/11, `deno check` clean on all functions.
**Cleanup:** all `zz_*` test rows deleted; `webview_sources` back to `facebook`/`filmyface`; secret blanked; scratchpad secret file removed.
**Not tested (environment limits):** the real mobile app on a device, and a real/sandbox **Cashfree charge** (Cashfree keys in `app_config` still empty).
**Docs updated:** `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** owner sets `admin_panel_secret` to use the panel; a Cashfree **sandbox** end-to-end test with a per-source amount before relying on per-source pricing in production.

---

## 2026-10-24 — Phase B pushed + deployed to the live project

**Request:** push and deploy Phase B.
**Changes:** no code. Pushed migration `20261024130000_source_pricing.sql` (`supabase db push`) and deployed `create-cashfree-subscription` (`supabase functions deploy create-cashfree-subscription`, which re-uploaded the shared `app_config.ts` with `applySourcePricing`). `admin-source-config` deliberately NOT deployed this round; `admin_panel_secret` still blank.
**Verified:** `deno check` clean on the function before deploy; `migration list` shows `20261024130000` local==remote; `webview_sources` now 31 columns with the 4 pricing columns nullable; unauthenticated POST to the deployed function returns 401 `UNAUTHORIZED_NO_AUTH_HEADER` (auth guard intact, verify_jwt still on, no anonymous invocation).
**Behaviour now:** no `webview_sources` row has a pricing column set, so every install still gets the **global** price; per-source pricing takes effect only once a row's amounts are filled.
**Not verified:** no real or sandbox Cashfree charge exercised in this environment.
**Docs updated:** `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** a Cashfree **sandbox** end-to-end test with a per-source amount before relying on it; deploy `admin-source-config` + set `admin_panel_secret` when the panel is wanted; optionally fix the pre-existing `verify-cashfree-subscription` type error.

---

## 2026-10-24 — Per-source app identity, Phase B (plan & prices)

**Request:** move to Phase B — per-source plan and prices, on top of Phase A's visual identity.
**Changes:**
- `supabase/migrations/20261024130000_source_pricing.sql` — adds `plan_name`, `cashfree_plan_id`, `cashfree_trial_amount`, `cashfree_recurring_amount` (text, nullable) to `webview_sources`.
- `supabase/functions/_shared/source_config.ts` — allowlists the 4 pricing columns; new `amount` kind (positive number, stored as text; empty = inherit, never ₹0).
- `supabase/functions/_shared/app_config.ts` — `SOURCE_PRICING_KEYS`, `applySourcePricing(client, map, installSource)` (best-effort overlay of the 4 keys from the active source row), and `loadAppConfig(client, installSource?)`.
- `supabase/functions/create-cashfree-subscription/index.ts` — reads `install_source` from the request body (selector only, never an amount) and passes it to `loadAppConfig`; logs the source.
- `lib/services/evos_backend.dart` — `createSubscription(String? installSource)` on the interface and all impls; the Supabase one sends `install_source` (lowercased, non-unknown) in the function body.
- `lib/services/payment_gateway.dart` — `CashfreePaymentGateway(installSource:)`, normalised and forwarded to `createSubscription`.
- `lib/providers.dart` — passes `onboardingStore.installSource` into the gateway.
- `admin/` — "Plan & prices" field group; editor note updated to warn these override real money.
- Tests: `test/payment_source_test.dart` (+2, gateway forwards the normalised/null source); `source_config.test.ts` (+2, amount validation + pricing allowlist); `test/support/harness.dart` signature update.
**Why:** amounts are read server-side from the table, never from the client, so a spoofed source can only pick another real partner's price (same risk profile as `webview_url`). The paywall display and the Cashfree charge both read the same source row, so they can't drift. Best-effort server overlay means any lookup error charges the known global price rather than failing the payment; partial deploys (function vs. migration) are safe for the same reason.
**Verified:** `flutter analyze` clean; `flutter test` 149/149 pass. **QA audit (2026-10-24):** Deno is actually installed (`/opt/homebrew/bin/deno`), so `deno test --allow-net source_config.test.ts` → 11/11 pass, and `deno check` was run on every touched function. The audit found and fixed two issues: (1) a TS type error in `applySourcePricing` (`maybeSingle()` result cast — `create-cashfree-subscription` and `cashfree-webhook` now `deno check` clean); (2) a blank per-source amount was being stored as `""`, which reads as the global price server-side but as the app's default on the paywall — now coerced to `null` (inherit) so display and charge can't disagree. **Not verified:** migration NOT pushed, function NOT deployed (live payment path — owner's call); no sandbox/real charge exercised. **Pre-existing (not mine, not fixed):** `verify-cashfree-subscription/index.ts:151` has a `deno check` type error (`isAuthorizationSuccess(authorizationStatus)` with a nullable arg) — latent, predates Phase B.
**Docs updated:** `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** push `20261024130000`, deploy `create-cashfree-subscription` (and `admin-source-config` + set `admin_panel_secret` for the panel), then a Cashfree **sandbox** test with a per-source amount before production.

---

## 2026-10-24 — Phase A migration pushed to the live project

**Request:** deploy the DB changes (before moving to Phase B).
**Changes:** none to code. Pushed migration `20261024120000_webview_source_identity.sql` to the live Supabase project `sqvlgiqypqvjykczuhgz` with `supabase db push` (CLI at `~/.local/bin/supabase`, linked).
**Verified (read-only `supabase db query --linked`):** `migration list` shows `20261024120000` local==remote; `webview_sources` now has 27 columns with `webview_url` nullable; `admin_panel_secret` exists, `is_public=false`, value blank; existing rows `facebook`/`filmyface` → instagram still active; the only policy is `webview_sources_active_read` (SELECT, anon/authenticated) — no write policy.
**Not done (still blocks the panel):** `admin-source-config` edge function NOT deployed; `admin_panel_secret` NOT set (blank = panel locked, which is the safe default). Deno not installed, so the TS tests did not run.
**Docs updated:** `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** deploy the function + set the secret when the panel is wanted; then Phase B (per-source prices/plan).

---

## 2026-10-24 — Per-source app identity, Phase A (visual identity + admin panel)

**Request:** build an admin panel to manage `webview_sources`, and make that table hold the whole app identity per install source (name, logo, colour, paywall fields, login slides, prices, plan) so the app fetches its identity by `install_source`, not just the web page URL.
**Decisions (owner):** typed columns (not JSONB); Phase A = visual identity only, prices/plan deferred to Phase B; admin auth = a private `app_config.admin_panel_secret` row checked by an edge function; write everything locally, push/deploy nothing.
**Changes:**
- `supabase/migrations/20261024120000_webview_source_identity.sql` — adds the visual-identity columns to `webview_sources` (column names = `app_config` keys; NULL inherits, non-null overrides, empty hides) and the private `admin_panel_secret` row. Prices/plan deliberately omitted (Phase B).
- `lib/services/evos_backend.dart` — `_applySourceWebUrl` → `_applySourceOverrides`; new pure `mergeSourceRow` overlays every non-meta, non-null column onto the config map generically. `fetchConfig` doc updated.
- `supabase/functions/_shared/source_config.ts` — the write allowlist + validation (`SOURCE_COLUMNS`, `coerceColumn`, `buildSourceRow`, `normalizeSource`). Secrets are not columns, so cannot be written.
- `supabase/functions/admin-source-config/index.ts` — service-role edge function (list/upsert/delete) behind the `x-admin-secret` header vs. `admin_panel_secret` (blank = locked); CORS for the browser panel.
- `supabase/config.toml` — `[functions.admin-source-config] verify_jwt = false` (browser sends the publishable key, not a JWT, and the function does its own secret auth).
- `admin/` — standalone static panel (`index.html`, `app.js`, `config.js`, `README.md`); typed secret only (no apikey/Authorization, matching `verify_jwt = false` and the CORS allow-list), all writes through the edge function.
**QA pass (2026-10-24, before any deploy) found and fixed three issues:** (1) migration now drops `NOT NULL` on `webview_url` — an un-overridden URL is `null` (inherit) and would otherwise fail the upsert; (2) added the `verify_jwt = false` entry above, without which the gateway would 401 every browser call; (3) removed `apikey`/`Authorization` from the panel's fetch so the CORS preflight matches `Access-Control-Allow-Headers`.
- Tests: `test/onboarding_logic_test.dart` (+4, `mergeSourceRow` inherit/override/empty/meta); `test/support/harness.dart` fake gains `overridesBySource`; `supabase/functions/_shared/source_config.test.ts` (Deno, unrun here).
**Why:** typed columns give the admin form named fields + schema-enforced safety and keep the app's read path a flat `Map<String,String>` into `RemoteConfig.fromRows` unchanged. The NULL/empty distinction gives a clean inherit-vs-hide semantic. Writes go through a service-role function so the table keeps no anon/authenticated write policy (rules #17a).
**Verified:** `flutter analyze` clean; `flutter test` 147/147 pass. **Not verified:** the migration/function are NOT pushed or deployed (owner's call); Deno is not installed, so the TS tests did not run; nothing exercised on a phone or against the live backend.
**Docs updated:** `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`, `admin/README.md`.
**Follow-ups:** Phase B — per-source prices/plan: add `cashfree_*_amount`/`cashfree_plan_id`/`plan_name` columns, make `create-cashfree-subscription` source-aware (thread `install_source` through `createSubscription`), extend the allowlist. Then push the migration, deploy `admin-source-config`, set `admin_panel_secret`, and run the Deno tests.

---

## 2026-10-23 — Version bump to 1.0.2+3 and signed release bundle (NOT uploaded)

**Request:** bump the version and build for Play; make sure everything is correct.
**Changes:** `pubspec.yaml` 1.0.1+2 -> 1.0.2+3 (versionCode 3; live Play is 2).
**Verified:** `flutter analyze` clean; 143 tests pass; `flutter build appbundle` wrote a signed `.aab`; cert = upload key `C3:40:52…`, package `com.spacewire.evos`, versionName 1.0.2; keystore files untouched.
**Readiness — NOT ready to publish as-is (flagged to owner):**
1. **Payment: owner confirmed working on 2026-10-23** (not verified in this environment — the review number skips to notes and a normal number needs a real OTP). Taken as cleared on the owner's word.
2. **Review-account cloaking.** `9931133385`/`123456` sees local notes; everyone else sees the paywall/web page. Showing reviewers different content than users is a Play policy violation that commonly causes removal. Owner has accepted the risk (rule 5); re-flagged at submission.
3. **Store listing, screenshots and `website/` still describe the notes app**, not phone sign-in/subscription/web page. Mismatch can cause rejection and misleads users.
4. This bundle replaces the live Google-sign-in notes app with a completely different flow.
**Docs updated:** `docs/ai/AGENT_CONTEXT.md`, `docs/ai/TASK_LOG.md`.
**Follow-ups:** before a *public* release, update the store listing/screenshots/website to describe phone sign-in + subscription + web page, and decide on the cloaking risk. Recommend an Internal testing track first. Upload is the owner's manual Play Console step (no credentials/tooling here).

---

## 2026-10-23 — Per-source web page: end-to-end verification on device + live backend

**Request:** two rows added to `webview_sources`; do full end-to-end testing.
**Rows (live):** `filmyface` and `facebook` → `https://www.instagram.com/?hl=en`; global `app_config.webview_url` → `https://subtle-sopapillas-a755d8.netlify.app`.
**Verified (nothing changed in code; this is QA):**
- **Data layer, app's exact anon queries (curl):** `source=eq.filmyface&is_active=eq.true` and `facebook` → instagram; `google-play`, `whatsapp`, `FilmyFace` → `[]` (fall back; case-sensitive, so the app's lowercasing matters). RLS: anon reads active rows only; anon INSERT 401.
- **Live resolution on the device** (real-backend debug build, real network, source seeded via `run-as`, read back from `evos_config_v1`): `filmyface` → instagram, `facebook` → instagram, `google-play` → netlify (global). Proves the real `SupabaseEvosBackend.fetchConfig` two-query merge end-to-end. (`flutter test` can't hit the network — `TestWidgetsFlutterBinding` forces HTTP 400 — so this had to be on device.)
- **WebView render:** with `filmyface` resolved, the web screen loaded `instagram.com` inside the Evos app bar (screenshot). Reached by seeding stage=web + a session (real sign-in needs a real number; payment→web is still blocked by the incomplete Cashfree setup, a pre-existing gap).
- **Analytics (the review fix) live:** `Web Page Viewed` fired to Mixpanel with `install_source: filmyface`, `web_host: www.instagram.com`, `has_url: true` (logcat `status`/Mixpanel accepted).
- `flutter analyze` clean; 143 tests pass.
**Notes/risks confirmed:** a third-party page (instagram) renders full-screen inside the Evos chrome — the brand/trust point from the review, shown in practice. `adb`/organic installs save source `google-play` (not `unknown`), which correctly falls back.
**Docs updated:** `docs/ai/TASK_LOG.md`, `docs/ai/AGENT_CONTEXT.md`.
**Follow-ups:** the only unproven production path is real payment → web (blocked by Cashfree setup, unrelated to this feature). The phone now has the debug build with data cleared; reinstall the Play build if the released one is wanted back.

---

## 2026-10-22 — Per-source web page: review fixes (visibility, is_active guard, drop cached provider)

**Request:** fix the review's two medium risks and the low one.
**Changes:**
- `analytics.dart` / `web_screen.dart`: `Web Page Viewed` now carries `install_source` and `web_host` (host only, never the URL), so a source landing on the wrong page or none is visible in Mixpanel instead of failing silently.
- `evos_backend.dart`: the `webview_sources` lookup adds `.eq('is_active', true)` as a second guard, so a loosened RLS policy could never serve a disabled partner URL.
- `providers.dart`: removed `installSourceProvider`; `refresh()` reads `onboardingStoreProvider.installSource` directly, so the value is never a stale cached one (it is written in main() before runApp).
- Test: the tagged-source web-page test now also asserts `Web Page Viewed` carries `install_source`.
**Verified:** `flutter analyze` clean; 143 tests pass; no references to the removed provider remain.
**Docs updated:** `docs/10-analytics.md`, `docs/ai/AGENT_CONTEXT.md`.
**Follow-ups:** optional `CHECK (source = lower(source))` / `webview_url <> ''` constraints on `webview_sources` would need a new migration pushed (go-ahead). The remaining review test-gaps (main.dart save path, 'unknown' skip, best-effort swallow) are not yet covered.

---

## 2026-10-22 — Per-source web page: `webview_sources` table, URL chosen by install source

**Request:** the WebView URL should depend on the deep-link `install_source` (e.g. `filmyface` loads the page saved for filmyface). Plan it, then build.
**Changes:**
- `supabase/migrations/20261022130000_webview_sources.sql` (new): table `webview_sources(source pk, webview_url, is_active)`, RLS public-read on active rows, SELECT grant, no write policy. **Not pushed.**
- `OnboardingStore`: `installSource` / `saveInstallSource` (`install_source_v1`), so the source survives to the web step.
- `main.dart`: saves the parsed source (lowercased, unless `unknown`) after reading the referrer.
- `providers.dart`: `installSourceProvider`; `RemoteConfigController.refresh()` passes it to `fetchConfig`.
- `evos_backend.dart`: `fetchConfig(String? installSource)`; `SupabaseEvosBackend` does one filtered `webview_sources` read and overrides `webview_url`, best-effort (swallows errors so a missing table never loses the rest of the config). `UnconfiguredEvosBackend` matches the signature.
- `WebScreen`, `RemoteConfig`: unchanged — `webUrl` is just the (possibly overridden) `webview_url`.
- Tests: `FakeBackend.webUrlBySource` + `fetchConfig(source)`; `launch(installSource:)`; two web-page tests (tagged source gets its page; no source gets the global one).
**Why:** decided with the owner — client filtered-select (migration only, no edge function), scope limited to the web URL. Best-effort lookup lets the app ship before the migration is pushed.
**Verified:** `flutter analyze` clean; 143 tests pass (was 141). The `SupabaseEvosBackend` two-query merge has no unit test (no live client, like the rest of that class); the client wiring is covered through `FakeBackend`. **Migration pushed to the live project on owner's go-ahead** (`supabase db push`, only `20261022130000` was pending); verified over REST with the app's anon key: table reads `[]`, a filtered `source=eq.filmyface` read returns `[]`, an anon INSERT is rejected 401. No rows yet; not run on a phone.
**Docs updated:** `docs/09-deep-link-onboarding.md`, `docs/ai/AGENT_CONTEXT.md`.
**Follow-ups:** fill `webview_sources` rows (and the global `webview_url`) in the Table Editor; bump the version and upload a build; then verify on a phone with a tagged referrer link (personal-account phone only).

---

## 2026-10-22 — Play referrer: cause found (managed account on the phone)

**Request:** the owner found the cause and confirmed the Play Store link works; the link page is not needed.
**Changes:** `web_links/onboarding/index.html` reverted to its previous version. `assetlinks.json` keeps Play's signing key (without it the HTTPS link can never open an app installed from Play).
**Why:** Play checks every Google account on the device and resets the install referrer when any of them is enterprise-managed, even if a personal account is the active one in Play. The test phone's only account was a Workspace account (`bhaktilok.app`), so every install read `utm_source=(not%20set)&utm_medium=(not%20set)` with the click recorded. The app's code was never at fault.
**Verified:** the owner removed the Workspace account and confirmed the link opens onboarding. On the phone: only a `@gmail.com` account now; Evos 1.0.1 installed by Play at 17:53 IST.
**Docs updated:** `docs/ai/AGENT_CONTEXT.md`, `docs/07-known-issues.md`, `docs/09-deep-link-onboarding.md`.
**Follow-ups:** users with a work account on their phone will never get the referrer; Mixpanel `install_referrer_raw` = `(not%20set)` with `referrer_click_recorded: true` identifies them.

---

## 2026-10-22 — Onboarding link: App Links page that works when Play drops the referrer

**Request:** research the Install Referrer and deep-link docs again and make the onboarding link work using Google's own mechanisms, no third-party SDK.
**Changes:** `web_links/.well-known/assetlinks.json` lists Google Play's app signing key (`4A:2D:5C:…`, read from the Play install with `pm get-app-links`), the upload key (`C3:40:52:…`, from the `.aab`) and the debug key; before, only the debug key, so a Play install could never verify the domain (state 1024 on the test phone). `web_links/onboarding/index.html`: one "Get Evos" button, a Chrome intent URL with the package and `S.market_referrer` (opens the app if installed, otherwise Play with the referrer), and text asking to come back and tap again after installing.
**Why:** the official pages (installreferrer overview, library, AIDL reference, release notes; App Links create-deeplinks) say nothing about what Play puts in the referrer or about "(not set)". Opening the Play link through Chrome also gave notes (17:39 IST), after Gmail, adb, full-UTM and `market://` had. A Chrome intent link is deterministic whatever Play does with the referrer.
**Verified:** page served from this Mac to the test phone's Chrome (`adb reverse`), live Play build 1.0.1: installed, the button opened Evos on "Welcome to Evos"; uninstalled, the button opened Play's Evos page (`market://details` via `MarketDeepLinkHandlerActivity`), Play installed it, back on the page the button opened onboarding. Not deployed: `notes-f36b3.web.app` still answers 404, the Firebase CLI and Node are not installed, and verification of the domain by Android (autoVerify) has therefore not run.
**Docs updated:** `docs/09-deep-link-onboarding.md`.
**Follow-ups:** owner's go-ahead to deploy `web_links/` (install the Firebase CLI, `firebase login` by the owner, `firebase deploy --only hosting`), then re-verify on the phone and test from a WhatsApp/Gmail tap. Campaign link becomes `https://notes-f36b3.web.app/onboarding`. Whether `S.market_referrer` reached the app: Mixpanel "Install Attributed" of 17:41 IST.

---

## 2026-10-22 — Sign-in screen: stop the carousel from rearranging the layout after it loads

**Request:** on the sign-in screen the image carousel loads after a moment and shifts the widgets, which looks odd; fix the placement.
**Cause:** `remoteConfigSettledProvider` reports settled as soon as a config saved by an earlier launch exists. If that saved config had no slides but the network refresh then returned some, `hasSlides` flipped false→true after the first frame, swapping the whole layout branch (brand header in, heading from headlineMedium to headlineSmall, carousel pushed above the form) — a visible jump.
**Change:** `phone_screen.dart` now freezes the carousel-or-not decision the first time the form is shown (`_useCarousel ??= hasSlides`) and drives all layout off that, not live `hasSlides`. Slides that arrive after the form is on screen no longer restructure it; they show on the next launch. The warming/readiness logic still uses live slides. Not ported from Clenio (its phone screen was unchanged); specific to this app.
**Verified:** `flutter analyze`: no issues. `flutter test`: 141 passed, including a new regression test ("slides arriving after the form is shown do not rearrange it"). `flutter build apk --debug`: built.
**Docs updated:** `docs/02-architecture.md`, `09-deep-link-onboarding.md`, `ai/AGENT_CONTEXT.md`, this log.
**Follow-ups:** none. (A first-ever launch whose saved config lacks slides shows the carousel only from the second launch — accepted, to avoid the jump.)

---

## 2026-10-22 — Paywall: fix the stuck loading state when Try Now is left without paying (ported from Clenio)

**Request:** apply the paywall loading-state fix done in the Clenio app — tapping Try Now and coming back without paying must not leave the paywall stuck loading.
**Cause:** the Kotlin `startSubscription` held the `MethodChannel.Result` open until Cashfree's callback, and the Dart gateway then polled for up to ~24 s. Cashfree does not always call back when the user returns without paying, so the paywall could spin indefinitely with no way out.
**Changes (ported from Clenio's working tree; its unrelated UPI-icon change was left out):**
- `PaymentsChannel.kt`: `startSubscription` answers `success(null)` as soon as the UPI app opens; Cashfree's callbacks are sent to Dart as a separate `cashfreeResult` call (`onSubscriptionVerify`→ok, `onSubscriptionFailure`→code). Removed the held `pending` Result and `already_in_progress`. The callback is registered at `register()` too, in case Android recreated the activity.
- `payment_gateway.dart`: added `CheckoutStage`, `onStage`, `leave()`, `checkLastAttempt()`, a `PaymentsPlatform` seam (`MethodChannelPaymentsPlatform` with a `results` stream and `nextResume()`), and `CashfreeResult`. Rewrote `CashfreePaymentGateway`: a `leave` completer, a callback/resume race with a grace window, capped waits (`holdLimit` 6 s, `callbackGrace` 1.5 s), and a background `checkLastAttempt` (`backgroundLimit` 60 s). Kept `EvosBackend.verifySubscription` returning `bool` (did not adopt Clenio's `MandateState`). Added `PaymentError.slowNetwork`.
- `providers.dart`: `PurchaseController` passes `onStage`, uses `_finish`/`_succeeded`/`_checkLater`, exposes `leave()`; new `CheckoutStageController`/`checkoutStageProvider`.
- `paywall_screen.dart`: a full-screen `_Processing` overlay driven by `checkoutStageProvider`, wrapped in `PopScope` so Back calls `leave()`; removed the CTA button spinner. `_paying` tracks the app for the overlay text.
- `errors.dart`: message for `PaymentError.slowNetwork`.
- Tests: `FakeGateway` implements the new interface (records `stages`, supports `leave()`/`checkLastAttempt()`); new flow tests for Back-stops-the-payment and a late approval after a cancel.
**Verified:** `flutter analyze`: no issues. `flutter test`: 140 passed. `flutter build apk --debug`: built (Kotlin compiles). Not run on a phone: the `cashfreeResult` path and the real Cashfree SDK are covered only by the `FakeGateway` in widget tests.
**Docs updated:** `docs/02-architecture.md`, `07-known-issues.md`, `09-deep-link-onboarding.md`, `ai/AGENT_CONTEXT.md`, this log.
**Follow-ups:** run a real sandbox payment on a phone to confirm the callback path and the capped waits; the server can still create a second mandate on a double tap (unchanged).

---

## 2026-10-22 — Review number opens local-only notes instead of the web page

**Request:** the test number 9931133385 (OTP 123456) must open the notes screen after verification, not the WebView. The WebView is only for other numbers, after subscription.
**Risk flagged, owner accepted:** reviewers seeing a notes app while buyers get a paywalled web page is what Play's cloaking policy can flag. The owner has repeated the instruction, so it is built; the risk is recorded in [07-known-issues.md](07-known-issues.md#notes-screens-unreachable) and [09-deep-link-onboarding.md](09-deep-link-onboarding.md#the-review-account).
**Changes:**
- New `OnboardingStage.notes`; `OnboardingController.reviewSignedIn()` now sets `notes` (+`reviewAccount`) instead of `web`. `refresh()` still skips the review account.
- New `lib/services/local_notes_store.dart` (`LocalNotesStore`): notes in `shared_preferences` via `OnboardingStore` (`local_notes_v1`), a broadcast stream, create/update/delete/restore, device-clock timestamps, no Firebase. New `OnboardingStore.loadNotes`/`saveNotes`.
- New providers `localNotesStoreProvider`, `localNotesStreamProvider`, `localNoteActionsProvider` (`LocalNoteActions`, mirrors `NoteActions`, fires the same note analytics).
- `AppGate`: `notes` stage renders `NotesListScreen` outside `BrandShell`, so it keeps the app's violet theme.
- `NotesListScreen`, `NoteEditorScreen` repointed from `notesStreamProvider`/`noteActionsProvider` to the local providers; dropped `firebase_auth`/`UserAvatar`/`currentUserProvider`. `ProfileScreen` rewritten: no Firebase user (generic "Signed in" card, "saved on this device"), Log out calls `OnboardingController.signOut`.
- The Firestore notes path (`notesStreamProvider`, `NoteActions`, `NotesRepository`, `AuthService`, `currentUserProvider`, `signInControllerProvider`) is now unused but kept.
- Tests: `review account` group lands on notes, creates a note, checks it persists to `local_notes_v1`, survives a restart, and logs out from Profile. Maestro `review_account.yaml` rewritten to land on notes, create a note, restart, and log out from Profile.
**Verified:** `flutter analyze`: no issues. `flutter test`: 138 passed. `flutter build apk --debug`: built. `check-syntax` on `review_account.yaml`: OK. Not run on a phone (same install-signature block as the previous entry).
**Docs updated:** `docs/01-overview.md`, `02-architecture.md`, `03-app-flow.md`, `07-known-issues.md`, `08-e2e-testing.md`, `09-deep-link-onboarding.md`, `10-analytics.md`, `ai/AGENT_CONTEXT.md`, this log.
**Follow-ups:** as the previous entry, plus — decide whether to delete the now-unused Firestore notes code; confirm with the owner they understand the Play-review risk of the review number seeing a different app; run `review_account.yaml` on a phone after uninstalling the Play build.

---

## 2026-10-22 — Phone sign-in for everyone; Google sign-in and maintenance screen removed; WebView

**Request:** the deep link does not work, so change the whole flow: remove Google sign-in, use the mobile number and code for everyone, send number 9931133385 with a fixed code 123456 straight to the notes screen, show everyone else the paywall and, after subscribing, a WebView with full settings; remove the maintenance screen. The URL comes from `app_config`.
**Declined part:** sending the review number to the notes screen while every other user gets the paywall and web page. Reviewers would see a different app from paying users (Play's Deceptive Behavior policy). The owner agreed to a version where the review number lands on the same web page, then asked again for notes on that number; that part was not built. The review number skips the SMS and the paywall onto the web page.
**Changes:**
- `pubspec.yaml`: removed `google_sign_in`, `google_sign_in_android`, `google_sign_in_ios`; added `webview_flutter`, `webview_flutter_android` 4.14.1 and `url_launcher` 6.3.3.
- Deleted `lib/screens/auth_gate.dart`, `sign_in_screen.dart`, `onboarding/maintenance_screen.dart`. `auth_service.dart` keeps only Firebase auth state and sign-out; `SignInController` only signs out. `errors.dart` lost the Google mappings. `Info.plist` lost the Google URL scheme.
- `OnboardingStage` is now `signIn`, `paywall`, `web` (no `inactive`, no `maintenance`); `OnboardingState` has `reviewAccount`. Older saved values map: `maintenance` → `web`, `inactive`/`details`/`member` → `signIn`.
- `OnboardingController`: every launch starts at sign-in unless a later stage is saved; links and the referrer only send `Deep Link Opened`; `refresh` and `signOut` skip the server for the review account; new `reviewSignedIn()`.
- `PhoneAuthController`: the review number (`lib/models/review_account.dart`) sends no SMS and accepts only 123456.
- New `lib/screens/onboarding/web_screen.dart`: app bar (logo, Reload, menu with Log out), WebView with JavaScript, zoom, media without a tap, third-party cookies, text zoom from the phone's font size, debugging in debug builds, progress bar, error view, back through history, non-http links to other apps; "You're all set" with "Check again" while there is no URL.
- `RemoteConfig`: `webUrl` from `webview_url` (https only) replaces `maintenanceTitle`/`maintenanceMessage`. New migration `20261022120000_webview_url.sql` (not pushed).
- `Analytics`: removed the five Google sign-in events, `identify(uid, name, email)` and `Maintenance Viewed`; `Deep Link Opened` lost `started_onboarding`; added `Web Page Viewed` (`has_url`), `Web Page Failed` (`reason`), `Review Account Signed In`.
- `main.dart`: no Google initialisation; the referrer is kept for analytics only.
- Tests rewritten for the new start, the review account and the web page screen. Maestro: new `flows/onboarding.yaml` and `flows/review_account.yaml`; the notes flows, `deeplink_local`, `onboarding_deeplink` and the subflows moved to `.maestro/retired/` (gitignored folder, so moved rather than deleted). `tool/deeplink.sh --check` runs `onboarding.yaml`.
**Verified:** `flutter analyze`: no issues. `flutter test`: 137 passed. `flutter build apk --debug`: built. Both flows pass `check-syntax`. **Not run on a phone:** the test phone (`RZ8T606RJ0N`) has the Play-signed build installed; `adb install -r` of the test-mode build failed with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and it was not uninstalled without asking.
**Docs updated:** `README.md`, `docs/README.md`, `docs/01-overview.md`, `02-architecture.md`, `03-app-flow.md`, `05-setup-and-build.md`, `06-conventions.md`, `07-known-issues.md`, `08-e2e-testing.md`, `09-deep-link-onboarding.md`, `10-analytics.md`, `ai/AGENT_CONTEXT.md`, this log.
**Follow-ups:** push the migration and set `webview_url` (owner's go-ahead); run both flows on a phone after uninstalling the Play build; rewrite the Play listing, screenshots and `website/` to describe the subscription and web page; declare the review account in Play Console → App access; decide whether to delete the notes code and Firebase; bump the version before the next upload; consider file upload and camera/location for the WebView.

---

## 2026-10-22 — Play release notes for 1.0.1+2

**Request:** what the release notes for the new release should say.
**Changes:** none in the repo; the text was given in chat.
**Why:** the only change since 1.0.0+1 is the install-referrer retry and its analytics, which users cannot see, so the notes are a generic "stability and reliability" line. They name the notes app only, like the listing and the website.
**Verified:** under Play's 500-character limit. Not checked in Play Console.
**Docs updated:** this log only.
**Follow-ups:** none.

---

## 2026-10-22 — Play referrer: market:// link also withheld

**Request:** owner reports `(not set)` still, with the release live at 100% rollout; find a Play-only way.
**Changes:** docs only.
**Verified:** test phone (only account: Workspace `bhaktilok.app`; Play Store 53.6.15), live 1.0.1+2 installed by Play at 15:09 IST from `market://details?id=com.spacewire.evos&referrer=utm_source%3Dmarket_probe%26utm_medium%3Dlink%26flow%3Donboarding` sent to Play explicitly (without the package, Samsung's Galaxy Store also offers to open `market://`). Opened the notes app. Searches found no documented Play change or fix for "(not set)".
**Docs updated:** `docs/07-known-issues.md`.
**Follow-ups:** owner to say which phone and account gave their latest "(not set)". Decide a deterministic fallback (verified App Link page after install).

---

## 2026-10-22 — Play referrer: a full-UTM link is withheld too

**Request:** find a Play-only way to make the onboarding link work (no third-party SDK).
**Changes:** docs only.
**Verified:** test phone, live 1.0.1+2, installed by Play at 14:57 IST from `...&referrer=utm_source%3Dprobe%26utm_medium%3Dlink%26utm_campaign%3Donboarding%26utm_content%3Devos_onboarding%26utm_term%3Dt1%26flow%3Donboarding` (adb into Play). Mixpanel: `install_referrer_raw: utm_source=(not%20set)&utm_medium=(not%20set)`, `referrer_click_recorded: true`. Play drops the whole referrer, standard UTM fields included, so the hypothesis that it keeps only UTM fields is ruled out; no link format will help on this phone and account.
**Docs updated:** `docs/07-known-issues.md`, `docs/ai/AGENT_CONTEXT.md`.
**Follow-ups:** install through the link on a phone whose only Google account is a personal @gmail.com one, and read `install_referrer_raw`.

---

## 2026-10-22 — Play referrer on the live 1.0.1+2: Play withholds it

**Request:** the owner released 1.0.1+2, installed it from the onboarding link (Gmail, test phone, 14:42 IST) and shared the Mixpanel event.
**Changes:** docs only.
**Verified:** Mixpanel `Install Attributed`: `install_referrer_raw: utm_source=(not%20set)&utm_medium=(not%20set)`, `referrer_click_recorded: true`, `referrer_attempt: 1`. Play registered the tap on the link but replaced the link's referrer with "(not set)". The app treats that answer as final, which is correct. The earlier `install_source: unknown` was almost certainly the same string (the parser drops "(not set)"), not an empty answer. Phone: installer `com.android.vending`, version 1.0.1, opened from Gmail (uid 10200). Its only Google account is a Workspace account (`bhaktilok.app`); developer reports say a fresh, unmanaged account is the fix for "(not set)". Not official Google documentation.
**Docs updated:** `docs/ai/AGENT_CONTEXT.md`, `docs/07-known-issues.md`.
**Follow-ups:** test on a phone signed in only to a personal @gmail.com account. If that also reads "(not set)", Play will not carry the referrer for this app and onboarding needs another way in (attribution SDK, or own click matching).

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
