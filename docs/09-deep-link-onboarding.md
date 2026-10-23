# Phone sign-in, paywall and web page (Evos)

Since 2026-10-22 this is the whole app. Every user signs in with a mobile number and an SMS code, meets a paywall with a Cashfree UPI AutoPay trial, and once subscribed sees a web page in a WebView. The one exception is the review number 9931133385, which opens a local notes screen instead (see [The review account](#the-review-account)). Before that date it was a second interface reached only through an onboarding link, with an "under maintenance" screen after the paywall, and everyone else got the notes app with Google sign-in. The links still exist and are reported to analytics, but no longer change anything on screen. The file keeps its old name so links to it keep working.

The app is called **Evos**. Its name, logo, colour, paywall wording, prices and the web page's URL come from the backend. The backend is Supabase, built the same way as the CashAlert app's.

**What has and has not run.** The screens, the state logic and the Android payment code are written, tested with fakes, and run on a phone in test mode (before 2026-10-22; the new flow and the WebView have not run on a phone). **Sign-in works for real** (2026-10-13: a code sent by SMS through the hook and Fast2SMS, verified, new account, paywall shown, on the test phone). **Payment has never run:** the Cashfree settings are unfilled. See [What is not verified](#what-is-not-verified).

## The review account

One number is let in without an SMS or a payment and lands on the notes screen:

| Number | Code | Lands on |
|--------|------|----------|
| `9931133385` (India, +91) | `123456` | The notes screen (`OnboardingStage.notes`), with local-only notes |

- Checked on the device, in `PhoneAuthController` ([providers.dart](../lib/providers.dart)) against [review_account.dart](../lib/models/review_account.dart). No SMS is sent, Supabase is not called, and there is no server or Firebase session. Any other code is "That code isn't right". The same digits with another country code are an ordinary number.
- Its notes use `LocalNotesStore` ([local_notes_store.dart](../lib/services/local_notes_store.dart)) in `shared_preferences`: device-local, not synced, cleared with the app's data. The screens read `localNotesStreamProvider` and write through `localNoteActionsProvider`.
- The saved state carries `"review": true`, so start-up and every refresh skip the subscription check, which would otherwise find no session and send the device back to sign-in. Log out clears it without calling the server.
- Works in every build, test mode or not. Anyone who learns the number gets the notes app free.
- Reported as `Review Account Signed In`, never identified ([10-analytics.md](10-analytics.md)).
- Declare it in Play Console under App content → App access.

**This is the owner's explicit decision (2026-10-22).** Note the risk: if this number is handed to Google Play reviewers, reviewers would see a notes app while real buyers get a paywalled web page, which is the kind of difference Play's Deceptive Behavior (cloaking) policy can flag. The owner accepted that after it was raised.

## Verifying locally

With a phone connected and a **test-mode** debug build installed (`flutter run --dart-define=SUPABASE_URL=`):

```sh
./tool/deeplink.sh --check    # runs the Maestro flow onboarding.yaml
./tool/deeplink.sh --reset    # clear the app's data: back to the mobile-number screen
```

**Test mode.** The app talks to the Evos Supabase project by default. A debug build made with `--dart-define=SUPABASE_URL=` (an empty value) has no backend, so it stands in for one: any valid number is accepted, no SMS is sent, the code is `123456`, and the payment is simulated. All three screens say so ("Test mode: no SMS is sent." on the number and code screens, "Test mode: no payment is taken." on the paywall). A release build made that way refuses at the first step instead. Test mode fetches no settings, so the web page screen shows "You're all set" unless settings are seeded on the device (see [Setting up the backend](#setting-up-the-backend)).

`onboarding.yaml` is for a test-mode build only: on a normal build it would text a code to the number it types, which belongs to a stranger. It asserts the test-mode notice before tapping "Send code", so on a normal build it fails there, having sent nothing. `review_account.yaml` is safe on any build.

## Decisions

Made with the product owner on 2026-10-01, 2026-10-13 and 2026-10-22.

| Question | Decision |
|----------|----------|
| Who sees this flow | Everyone, since 2026-10-22. Until then only users who arrived by the link |
| Google sign-in | Removed, 2026-10-22 |
| App name | Evos, from the backend |
| Sign-in | Mobile number and SMS code. One screen for the number, one for the code. A new number becomes an account when its code is verified, so there is no separate sign-up |
| Details form | Removed |
| Backend | Supabase, like CashAlert |
| Payment | Cashfree UPI AutoPay, auto-renewing, the same model as CashAlert: a small amount today for 24 hours, then a monthly debit |
| Paywall layout | The same as CashAlert's |
| After paying | A WebView of the backend's `webview_url` (2026-10-22). Before that, an "under maintenance" screen |
| Store-review / 9931133385 | The notes screen, with local-only notes. Owner's decision 2026-10-22 |

Chosen by the implementer, not confirmed by the product owner:

- **A separate Supabase project from CashAlert,** which is what was then supplied (`sqvlgiqypqvjykczuhgz`). Sharing one would make a CashAlert subscriber an Evos subscriber, because both key the subscription on the phone account.
- **The paywall invents nothing.** CashAlert's shows a star rating, a subscriber count and rotating "… just started a trial" lines that are fixed text in the app. Here those parts appear only if the backend sends them, and are blank by default. The heading pill shows the trial price rather than the word FREE, because the trial is charged.
- **Default prices.** ₹3 for 24 hours, then ₹299 a month, until the backend says otherwise.
- **The web page screen has an app bar** with the logo and name, a reload button and a menu holding "Log out", so a subscriber can always sign out.

## Flow

```mermaid
flowchart TD
    Launch([App launch]) --> Stored{Stage saved<br/>on device}
    Stored -- none or signIn --> Phone[PhoneScreen]
    Stored -- paywall or web --> Resume[Resume there,<br/>then ask the server]
    Phone -- code sent --> Otp[OtpScreen]
    Otp -- change number --> Phone
    Otp -- "verified, not subscribed" --> Paywall[PaywallScreen]
    Otp -- "verified, already subscribed" --> Web[WebScreen]
    Otp -- "review number + 123456" --> Notes[NotesListScreen, local]
    Paywall -- mandate confirmed --> Web
    Paywall -- cancelled or failed --> Paywall
    Web -- log out --> Phone
    Web -- subscription ended --> Paywall
    Notes -- log out --> Phone
```

- **The server decides who has paid.** The stage saved on the device is only what to show first. At every start, whenever the paywall or the web page comes back to the front, and on "Check again", the app asks the server and moves between paywall and web page to match. A subscriber on a new phone goes from the code screen straight to the web page. The review account is never asked about: it sits on the `notes` stage and skips the check.
- **Offline, nothing moves.** If the server cannot be reached the device stays where it last knew it was, so a subscriber is not sent back to the paywall for having no signal.
- **Log out** is on the web page screen only (the paywall has none, by decision of 2026-10-14) and returns to the mobile-number screen.
- **Links change nothing.** `notes://onboarding` (debug builds), `https://notes-f36b3.web.app/onboarding` and a Play Store referrer with `flow=onboarding` are each reported as `Deep Link Opened` and otherwise ignored.
- **An older build's saved stage** is mapped on the first launch of this one: `maintenance` becomes the web page; `inactive` (the notes app), `details` and `member` become the mobile-number screen.

## Screens

Designs: <https://claude.ai/artifact/R8sDE5Buj8BJo7E14StMTW> (the paywall there predates the CashAlert layout).

| Screen | File | Behaviour |
|--------|------|-----------|
| Mobile number | [phone_screen.dart](../lib/screens/onboarding/phone_screen.dart) | With slides from the backend: a small logo-and-name header; a carousel card that takes all spare height (the slide's title, the app screenshot shown whole with rounded corners and a shadow on a light tint of the brand colour, and dots; moves on every 2 seconds and can be swiped); then "Welcome to <name>", the number field and "Send code" right under it. The carousel hides while the keyboard is open and the field keeps its focus; the field does not autofocus, so the carousel shows first. On a first launch (no settings saved on the device) the screen shows a spinner until the settings have answered and the first slide image has loaded, at most 4 seconds, so the form never appears without the carousel and then rearranges when the slides arrive; the other slide images load during that wait too. After that, and on every later launch, the saved settings draw the screen at once. **The carousel-or-not choice is frozen the first time the form is shown** (`_useCarousel` in [phone_screen.dart](../lib/screens/onboarding/phone_screen.dart)): if the saved settings have no slides but the refresh then adds some, they do not restructure a screen already on display (that late jump was the 2026-10-22 fix); the carousel appears on the next launch instead. Without slides: logo, heading and form, top-aligned, field autofocused. The field starts with a country selector (flag and calling code, India by default); tapping it opens a searchable sheet of about 190 countries, by name, code or ISO code ([country.dart](../lib/models/country.dart)). For India, "Send code" is off until the number is a valid Indian mobile (ten digits, first digit 6 to 9), and a pasted `+91 98765 43210` or `098765…` is reduced to its ten digits. For other countries the only rule is the international one, 6 digits up to 15 in all, with a leading 0 and a pasted country code removed. **Only Indian numbers can receive a code today**: `sms-hook` refuses any other with `sms_country_not_supported`, which the app shows as "We can't send codes to this country yet." Delivering elsewhere needs a second SMS provider in `sms-hook`; paying needs more than UPI AutoPay, which is India-only. Pre-filled when coming back from the code screen. |
| Code | [otp_screen.dart](../lib/screens/onboarding/otp_screen.dart) | Six boxes over one hidden field, so paste and the keyboard's SMS suggestion work. The sixth digit verifies by itself; "Verify" is there too. A wrong code empties the boxes. "Resend code" appears after 30 seconds. Back, in the app bar or the system's, returns to the number. |
| Paywall | [paywall_screen.dart](../lib/screens/onboarding/paywall_screen.dart) | CashAlert's layout without its "Log out": logo and name on top; heading with a pill; rating; preview video (or picture); up to four feature badges; the monthly price struck through beside the trial price; a rotating line of social proof; a bottom bar with the UPI app on the left and "Try Now" on the right. Each part with nothing to show is left out. Every text, icon, price and the accent colour can come from the `paywall_*` rows below; a blank text uses the app's own. While a payment runs, a full-screen **processing screen** covers the paywall (a spinner, the stage, and "keep the app open"); the system Back button leaves it and stops the wait. |
| Notes (review number) | [notes_list_screen.dart](../lib/screens/notes_list_screen.dart), [note_editor_screen.dart](../lib/screens/note_editor_screen.dart), [profile_screen.dart](../lib/screens/profile_screen.dart) | The list (pinned "Notes" title, a profile button, a "New note" button), the editor (title and body, save, delete, swipe-to-delete with Undo) and a plain Profile with "Log out". Backed by `LocalNotesStore`, device-local, no Firebase. Shown with the app's own violet theme, outside `BrandShell`. |
| Web page | [web_screen.dart](../lib/screens/onboarding/web_screen.dart) | An app bar (logo and name, "Reload", a ⋮ menu with "Log out") over a WebView of `webview_url`. JavaScript on; DOM storage, multiple windows, pinch zoom, and fullscreen video on (the plugin's defaults plus `enableZoom`); media may start without a tap; third-party cookies accepted; text size follows the phone's font-size setting (`setTextZoom`); WebView debugging in debug builds. A thin progress bar while a page loads. A failed main page shows "This page couldn't be loaded." and "Try again"; a failed image or script does not. Back goes back in the page's history, and closes the app when there is none. Links that are not http(s), such as `tel:`, `mailto:`, `upi:` or `whatsapp:`, open in the app that handles them (`url_launcher`). Not supported: file upload, and the page's requests for camera, microphone or location, which are denied. Blank or non-https `webview_url`: "You're all set", a line saying the page is not available yet, and "Check again". |

One sentence on the paywall is always shown: the statement that money will be taken every month. The backend words it in `paywall_autopay_text`, where `{trial}` and `{recurring}` become the two prices from the amount rows, so the words cannot drift from what is charged. Blank uses the app's own: "₹3 today for the first 24 hours, then ₹299 every month by UPI AutoPay. Cancel any time in your UPI app." (owner's decision, 2026-10-19; before that it could not come from the backend). Whoever edits that row is responsible for it still saying that money is taken every month.

**Icons** (`paywall_feature_icons`, `paywall_social_proof_icon`) are an https link to a small PNG or WebP, or a name from `kPaywallIcons` in [paywall_screen.dart](../lib/screens/onboarding/paywall_screen.dart): `check`, `check_circle`, `verified`, `lock`, `shield`, `security`, `star`, `sparkle`, `bolt`, `rocket`, `bell`, `rupee`, `wallet`, `card`, `gift`, `offer`, `crown`, `diamond`, `heart`, `thumb_up`, `people`, `support`, `clock`, `calendar`, `cancel`, `phone`, `cloud`, `ad_free`. A fixed list because release builds keep only the icons the code names; an icon chosen by number would draw as an empty box. A blank, an unknown name or a broken link shows the default (a tick, a sparkle).

**The preview video** comes from `paywall_video_url`, and plays as on CashAlert: it starts by itself with sound, loops, and a tap pauses or plays it. **The card has the shape set in `paywall_video_aspect_ratio` (default `1:1`) from the first frame and never changes size.** It used to start 16:9 and grow when the video reported its own shape, which pushed the price down (fixed 2026-10-19). Full width at that shape, or narrower and centred when taller than 45% of the screen height. The video is fitted inside, never cropped: a video of another shape shows bands at the sides or top. While it loads, `paywall_preview_image_url` fills the card behind a spinner; if it cannot play, that picture stays, or with no picture there is no card. It pauses while a payment runs and while the app is in the background. The live video (2026-10-19) is 1080×1080 and 10.8 MB, which takes several seconds on mobile data; a 720 px copy of about 2–3 MB would start sooner. CashAlert picks a video per app language from a `subscription_videos` table; Evos has one language and one URL.

## Backend

Everything is in [supabase/](../supabase/), adapted from CashAlert's. It is deployed to the project. `sms-hook` has delivered a real code; **the three Cashfree functions have not handled a real request yet**.

| Part | File | Role |
|------|------|------|
| Paywall rows | [migrations/20261019120000_paywall_controls.sql](../supabase/migrations/20261019120000_paywall_controls.sql) | Adds the ten `paywall_*` rows of 2026-10-19 with the app's defaults. Pushed 2026-10-19 |
| Carousel rows | [migrations/20261014130000_login_slides.sql](../supabase/migrations/20261014130000_login_slides.sql) | Adds `login_slide_images` and `login_slide_titles` |
| Video row | [migrations/20261014120000_paywall_video.sql](../supabase/migrations/20261014120000_paywall_video.sql) | Adds `paywall_video_url` |
| SMS settings rows | [migrations/20261013130000_sms_config_rows.sql](../supabase/migrations/20261013130000_sms_config_rows.sql) | Adds the four SMS rows where the first migration ran before it had them |
| Tables and policies | [migrations/20261013120000_evos_init.sql](../supabase/migrations/20261013120000_evos_init.sql) | `app_config`, `profiles`, `subscription_payments`, the `has_active_subscription()` function, and a trigger that makes a profile for each new sign-in |
| Per-source web page | [migrations/20261022130000_webview_sources.sql](../supabase/migrations/20261022130000_webview_sources.sql) | `webview_sources` (`source`, `webview_url`, `is_active`), public-read like `app_config`. **Pushed 2026-10-22**, no rows yet. The app overrides `webview_url` with the active row matching its install source |
| `sms-hook` | [functions/sms-hook/](../supabase/functions/sms-hook/index.ts) | Supabase Auth makes and checks the code; this delivers it through Fast2SMS |
| `create-cashfree-subscription` | [functions/create-cashfree-subscription/](../supabase/functions/create-cashfree-subscription/index.ts) | Creates the mandate with the Cashfree id and secret and returns a session id |
| `verify-cashfree-subscription` | [functions/verify-cashfree-subscription/](../supabase/functions/verify-cashfree-subscription/index.ts) | Asks Cashfree whether the mandate went through and records the payment |
| `cashfree-webhook` | [functions/cashfree-webhook/](../supabase/functions/cashfree-webhook/index.ts) | Records each monthly debit, failure, cancellation and expiry. This is what keeps access going after the first day |

Left out of the CashAlert original: push notifications, server-side Mixpanel events, the failed-debit retry job, the status-event log and the daily report.

### Settings: the `app_config` table

Key and value rows, edited in the Supabase Table Editor. A third column, `is_public`, decides who can read a row. The app reads the public rows with the anon key; row-level security returns nothing else, however it is asked.

| Key | Public | Meaning | Default |
|-----|--------|---------|---------|
| `app_name` | yes | Name shown in the interface and in the recent-apps list | `Evos` |
| `app_logo_url` | yes | HTTPS image. Blank shows the first letter of the name on a tile | blank |
| `theme_color` | yes | `#RRGGBB`. The whole colour scheme is generated from it | `#6D28D9` |
| `paywall_title_prefix`, `paywall_title_badge`, `paywall_title_suffix` | yes | The three parts of the heading. A blank badge shows the trial price | `1-Day`, blank, `Trial` |
| `paywall_rating_value`, `paywall_rating_caption` | yes | Stars and the text beside them. Blank hides the row | blank |
| `login_slide_images` | yes | App screenshots for the carousel on the mobile-number screen, https links separated by `\|`. Shown whole, never cropped, so any portrait screenshot fits. Keep each file small: around 720 px wide, JPG or WebP, under about 300 KB. The app decodes them at the size drawn, but still downloads the whole file. Blank hides the carousel. Added by migration `20261014130000` | blank |
| `login_slide_titles` | yes | One title per image, separated by `\|`, paired by position. A missing title is blank | blank |
| `paywall_video_url` | yes | HTTPS link to an MP4 (H.264) video for the preview card. Added by migration `20261014120000` | blank |
| `paywall_preview_image_url` | yes | HTTPS image, shown when there is no video or it cannot play. Both blank hides the card | blank |
| `paywall_video_aspect_ratio` | yes | Shape of the video card, `W:H` (`1:1`, `9:16`, `16:9`) or a number. Outside 1:4 to 4:1 falls back. Added by migration `20261019120000`, as are all the rows below marked so | `1:1` |
| `paywall_subtitle` | yes | A line under the heading. Blank hides it. `20261019120000` | blank |
| `paywall_features` | yes | Up to four badges, separated by `\|` | `Full access\|Cancel anytime\|Secure UPI AutoPay` |
| `paywall_feature_icons` | yes | One icon per badge, separated by `\|`, paired by position (see Icons above). `20261019120000` | ticks |
| `paywall_show_strike_price` | yes | `true` or `false`: the monthly price struck through beside the trial price. `20261019120000` | `true` |
| `paywall_accent_color` | yes | `#RRGGBB` for the pill, the large price and the icons; text on the pill turns black or white to stay readable. The button follows `theme_color`. `20261019120000` | blank (theme) |
| `paywall_autopay_text` | yes | The sentence that money is taken every month, with `{trial}` and `{recurring}`. Blank uses the app's own. `20261019120000` | blank |
| `paywall_social_proof_icon` | yes | Icon of the social-proof strip. `20261019120000` | blank (sparkle) |
| `paywall_cta_text`, `paywall_upi_select_text`, `paywall_upi_sheet_title` | yes | The button, the UPI app selector with no app found, and the UPI sheet's title. Blank uses the app's own. `20261019120000` | `Try Now`, `Select UPI App`, `Pay with UPI AutoPay` |
| `paywall_social_proofs` | yes | Rotating lines, separated by `\|`. Blank hides the strip | blank |
| `webview_url` | yes | The **default** HTTPS page the web page screen loads, for subscribers and the review account, when no per-source page applies (see `webview_sources` below). Blank or not https shows "You're all set" instead. Added by migration `20261022120000` (pushed) | blank |
| `maintenance_title`, `maintenance_message` | yes | No longer read by the app (2026-10-22). Left in the table | see the migration |
| `plan_name` | yes | Plan name given to Cashfree when no plan id is set | `Evos Premium Monthly` |
| `cashfree_plan_id` | yes | A plan made in the Cashfree dashboard. Blank: the plan is described inline from the amounts | blank |
| `cashfree_trial_amount` | yes | Rupees authorised today | `3` |
| `cashfree_recurring_amount` | yes | Rupees debited each month | `299` |
| `cashfree_app_id`, `cashfree_secret_key` | **no** | Cashfree credentials | blank |
| `cashfree_environment` | **no** | `production` takes real money; anything else is sandbox | `sandbox` |
| `customer_email_domain` | **no** | A domain the business owns. Cashfree needs an email per customer and a phone sign-in has none, so one is made as `user+<phone>@<domain>` | blank |
| `fast2sms`, `fast2sms_dlt_sender_id`, `fast2sms_dlt_te_id` | **no** | Fast2SMS API key, DLT sender id and template (message) id, read by `sms-hook`. The same three keys CashAlert's table has, to be filled with the same values | blank |
| `send_sms_hook_secret` | **no** | The secret the dashboard shows when the Send SMS hook is saved | blank |

- **The Cashfree id and secret never reach the app.** They are private rows, read only by edge functions with the service role. The app receives a single-use session id. Never mark either row public.
- The app keeps the last settings it fetched on the device, so the next start is already branded before the network answers, and still is with no network. A missing row, a blank value or a bad one (a colour that is not `#RRGGBB`, a negative price, an `http:` image) falls back to the default rather than breaking a screen. Parsing is in [remote_config.dart](../lib/models/remote_config.dart).
- **The launcher icon and the name under it do not change with the backend.** Android fixes them when the app is built. The home-screen name is "Evos" and the icon is the Evos mark (both since 2026-10-14). The icon is made from [tool/app_icon/](../tool/app_icon/): see 01-overview.
- The two amounts are read twice: by the app to show them, and by the server to charge them. Both read the same rows.

### Sign-in

`signInWithOtp` and `verifyOTP` on Supabase Auth, called from [evos_backend.dart](../lib/services/evos_backend.dart). The number is always sent as `+91` and ten digits.

The pure-Dart `supabase` client keeps a session in memory only, so the app saves it itself: each new or refreshed session is written to the device as JSON, and put back before the first call that needs it. A session the server refuses (revoked, or the account deleted) is dropped and the user signs in again.

The SMS is not read automatically. The code field carries the one-time-code autofill hint, so a keyboard that offers the code from Messages can fill it. CashAlert uses the SMS User Consent API; this app does not.

### Payment

```mermaid
sequenceDiagram
    participant App
    participant Fn as Edge functions
    participant CF as Cashfree
    participant UPI as UPI app
    App->>Fn: create-cashfree-subscription
    Fn->>CF: create subscription (id + secret)
    CF-->>Fn: subscription id, session id
    Fn-->>App: subscription id, session id, environment
    App->>UPI: Cashfree SDK opens the chosen app (startSubscription returns at once)
    UPI-->>App: cashfreeResult callback (verified, or cancelled/failed)
    loop up to ~6 s, 1 s apart
        App->>Fn: verify-cashfree-subscription
        Fn->>CF: status of the mandate
    end
    Fn-->>App: mandate authorised
    CF->>Fn: webhook, now and at every later debit
```

- `PaymentGateway` in [payment_gateway.dart](../lib/services/payment_gateway.dart) has `upiApps()`, `subscribe(app, {onStage})`, `leave()`, `checkLastAttempt()` and `isSimulated`. `CashfreePaymentGateway` is used when a Supabase project is configured; otherwise `SimulatedPaymentGateway`.
- The Cashfree SDK (2.4.0, the version CashAlert uses) is called from Kotlin in [PaymentsChannel.kt](../android/app/src/main/kotlin/com/spacewire/evos/payments/PaymentsChannel.kt) over the channel `com.spacewire.evos/payments`. It offers PhonePe, Google Pay, Paytm and BHIM, whichever are installed, and preselects the first.
- `subscribe` completes on success, throws `PaymentCanceled` when the user backs out of the UPI app or leaves the processing screen, and throws `PaymentFailure` or `BackendFailure` otherwise. `onStage` drives the paywall's processing screen (`preparing`, `openingApp`, `confirming`).
- **The processing screen cannot get stuck (fixed 2026-10-22).** `startSubscription` now returns as soon as the UPI app opens; Cashfree's answer arrives separately as a `cashfreeResult` call, so the device is never blocked on a callback that may never come. Every wait is capped: creating the subscription and confirming the mandate each wait at most `holdLimit` (6 s), and if Cashfree has not called back within `callbackGrace` (1.5 s) of the app returning, the server is asked anyway. **Back on the processing screen calls `leave()`**, which stops the wait at once. Before this, the SDK call was held open until Cashfree called back — and it does not always call back when the user returns without paying — so the paywall could load for a long time with no way out.
- **A late approval lets the user in by itself.** After a cancel, a pending result or a decline, `checkLastAttempt()` keeps asking the server for up to `backgroundLimit` (60 s) without holding any screen; if the bank approves and the user is still on the paywall, they are let in. A new Try Now (a new attempt id) makes the background check give up.
- **A payment still being confirmed is not called a failure.** If Cashfree has not confirmed within the hold the paywall says so; the background check, the next return to the front, or the next app start then lets a completed payment in.
- **A failure says why.** `create-cashfree-subscription` returns a `code` with every failure: `cashfree_keys_missing`, `email_domain_missing`, `phone_not_indian`, `cashfree_auth_failed` (Cashfree answered 401 or 403: wrong id or secret, or keys from the other environment), `cashfree_rejected_<status>`, `cashfree_error_<status>`, `config_unreadable`, `server_error`. The app shows it as "Error code: …" under "Something went wrong on our side", and sends it as the `reason` of `Checkout Failed`. The full message is in the function's log, and in a debug build's log as `[evos] Backend call failed`.
- **Asking to pay when already subscribed** gets a 409 from the server, and the app simply lets the user in.
- **Tapping "Try Now" again starts a new attempt** with its own subscription id; answers about the previous id are ignored (`_attempt`/`_lastSubscriptionId`). The server still refuses a *new* subscription only once the first is confirmed (inherited from CashAlert), so two taps can still create two mandates server-side.
- Whether the subscription is active is the SQL function `has_active_subscription()`: trial or active and not past its end date, or cancelled but still inside the period already paid for.

## How it is built

```mermaid
flowchart LR
    Play[Play Store] -- install referrer --> InstallReferrerService
    InstallReferrerService --> OnboardingController
    Platform[Android / iOS] -- link URL --> DeepLinkService
    DeepLinkService --> OnboardingController
    OnboardingStore <--> OnboardingController
    OnboardingController -- stage --> AppGate
    AppGate --> BrandShell
    BrandShell --> Phone[PhoneScreen] & Otp[OtpScreen] & Paywall[PaywallScreen] & Web[WebScreen]
    Phone & Otp --> PhoneAuthController --> EvosBackend
    Paywall --> PurchaseController --> PaymentGateway --> EvosBackend
    RemoteConfigController --> EvosBackend
    RemoteConfigController -- name, colour, text --> BrandShell
    EvosBackend --> Supabase[(Supabase)]
    PhoneAuthController & PurchaseController --> OnboardingController
```

| Part | File | Role |
|------|------|------|
| `InstallReferrerService` | [install_referrer_service.dart](../lib/services/install_referrer_service.dart), [MainActivity.kt](../android/app/src/main/kotlin/com/spacewire/evos/MainActivity.kt) | Reads the Play Store install referrer through a method channel, for analytics |
| Review account | [review_account.dart](../lib/models/review_account.dart) | The store-review number and code |
| `DeepLinkService` | [deep_link_service.dart](../lib/services/deep_link_service.dart) | Receives links from the platform, for analytics |
| `EvosBackend` | [evos_backend.dart](../lib/services/evos_backend.dart), [supabase_options.dart](../lib/supabase_options.dart) | Sign-in, settings, subscription status and the two payment functions. `SupabaseEvosBackend`, or `UnconfiguredEvosBackend` (test mode) with no project |
| `PaymentGateway` | [payment_gateway.dart](../lib/services/payment_gateway.dart), [PaymentsChannel.kt](../android/app/src/main/kotlin/com/spacewire/evos/payments/PaymentsChannel.kt) | Cashfree UPI AutoPay, or the simulated stand-in |
| `OnboardingStore` | [onboarding_store.dart](../lib/services/onboarding_store.dart) | The stage, the session and the last settings, on the device |
| `RemoteConfig` | [remote_config.dart](../lib/models/remote_config.dart) | The settings, with defaults and parsing |
| `OnboardingState` | [onboarding.dart](../lib/models/onboarding.dart) | The stage, the review-account flag, and their JSON form |
| `OnboardingController`, `RemoteConfigController`, `PhoneAuthController`, `PurchaseController` | [providers.dart](../lib/providers.dart) | Stage and entitlement; settings; sending and checking the code; starting the subscription |
| `BrandShell`, `BrandLogo`, `BrandHeader` | [brand.dart](../lib/widgets/brand.dart) | Apply the backend's name and colour to every screen; draw the logo |
| `WebScreen` | [web_screen.dart](../lib/screens/onboarding/web_screen.dart) | The WebView (`webview_flutter`, `webview_flutter_android`) and its settings; `url_launcher` for non-web links |
| `AppGate` | [app_gate.dart](../lib/screens/app_gate.dart) | Root widget; renders the screen for the current stage |

### Per-source web page: the `webview_sources` table

The web page a subscriber lands on can depend on where the install came from. A Play link tagged `utm_source=filmyface` makes the app load the page saved for `filmyface`, instead of the global `webview_url`.

| Column | Meaning |
|--------|---------|
| `source` | The install source, lowercased: the `utm_source` of the Play referrer. Primary key |
| `webview_url` | The page to load for that source |
| `is_active` | `false` hides the row (the policy returns active rows only), without deleting it |

How it works:

- **The source is remembered on the device.** `main()` parses the install referrer once (see below), and saves the source (lowercased) in `install_source_v1` (`OnboardingStore.installSource`). It is read on every later launch through `installSourceProvider`, because the web page step comes many launches after the referrer was read.
- **The lookup is one filtered read.** `SupabaseEvosBackend.fetchConfig(installSource)` fetches `app_config` as before, then, for a known source, reads the one matching `webview_sources` row and overrides the `webview_url` value. The client never downloads the whole table.
- **Fallback chain:** the source's active row → the global `app_config.webview_url` → the "You're all set" screen. An unattributed install (`unknown`, organic, or a phone with a work account that makes Play strip the referrer) always gets the global page.
- **Best-effort.** The `webview_sources` read is wrapped so a missing row (the table is live but empty as of 2026-10-22) or any error just leaves the global `webview_url`; the rest of the settings are never lost.
- **Cached like the rest of the settings.** The resolved `webview_url` is saved in `evos_config_v1`, so the next launch is instant and offline-correct (the source does not change after install).

### The Play Store referrer

> **Testing:** use a phone with **no work or Google Workspace account** signed in. If any account on the device is enterprise-managed, Play resets the referrer to `utm_source=(not%20set)&utm_medium=(not%20set)`, even when a personal account is the active one in Play (found 2026-10-22). Mixpanel's `install_referrer_raw` and `referrer_click_recorded` show what Play sent.

A Play Store link can carry a `referrer` parameter. Play keeps it through the install and hands it to the app afterwards. Since 2026-10-22 it decides nothing: when it contains `flow=onboarding` the app sends `Deep Link Opened` with `after_install: true`, and that is all. Campaign parameters can sit alongside it: `referrer=utm_source%3Dmail%26flow%3Donboarding`.

- **No plugin.** [MainActivity.kt](../android/app/src/main/kotlin/com/spacewire/evos/MainActivity.kt) exposes Google's Install Referrer library on the channel `com.spacewire.evos/install_referrer`.
- **Read in `main()`, before `runApp`,** with a 3-second limit.
- **Read until settled.** An answer with any content sets `install_referrer_checked` on the device. An empty answer (seen on every Play install on 2026-10-22) is counted in `install_referrer_attempts` and asked for again on the next launch, up to 5 launches. A failed read (no Play Store, timeout) is not counted and is tried again on the next launch.
- **Encoded or not.** `flow%3Donboarding`, a referrer handed over still encoded, is accepted too.
- **Reported.** `Install Attributed` carries Play's raw answer and whether Play recorded a link tap, so Mixpanel shows what Play actually sent ([10-analytics.md](10-analytics.md)).
- **Android only.** On iOS the read returns nothing, and there is no equivalent App Store mechanism.

An install that did not come from a link returns Play's default, `utm_source=google-play&utm_medium=organic`.

### Receiving the direct link

Links change nothing on screen since 2026-10-22, but are still received and reported. No plugin is used. Flutter already delivers links, and `DeepLinkService` reads them:

- **Cold start:** the link is the platform's initial route name.
- **While running:** the link arrives through `WidgetsBindingObserver.didPushRouteInformation`.

Two framework behaviours shape the code, and both are easy to break:

- **`DeepLinkService.start()` must run before `runApp`.** Flutter asks observers in registration order and stops at the first that handles the link. `WidgetsApp` registers its own, which pushes the link as a named route. Registering first keeps links out of the Navigator.
- **`MaterialApp` has no `home`.** With `home`, a cold-start link makes the Navigator try to push the URL as a route and report an error. [main.dart](../lib/main.dart) uses `onGenerateInitialRoutes` and `onGenerateRoute` to always start on the single `AppGate` route. Flutter does not allow `home` and `onGenerateInitialRoutes` together.

### What is stored on the device

Three keys in `shared_preferences`:

| Key | Holds |
|-----|-------|
| `onboarding_v1` | `{"stage": "paywall"}`. One of `signIn`, `paywall`, `web`, `notes`; `"review": true` is added for the review account (always with `notes`) |
| `local_notes_v1` | The review account's notes, as a JSON list. See `LocalNotesStore` |
| `evos_session_v1` | The Supabase session as JSON (access and refresh tokens) |
| `evos_config_v1` | The public settings as last fetched |

- The stage is loaded before `runApp`, so the first frame is already the right interface.
- A missing, corrupt or unrecognised stage decodes to `signIn`: signing in again is always safe.
- The `notes` stage only ever belongs to the review account. Stages saved by older builds: `maintenance` decodes to `web`; `inactive` (the old notes app), `details` and `member` to `signIn`.
- A stage past sign-in with no session on the device is shown as sign-in, unless it is the review account, which has no session.
- The mobile number and the code are never stored. Clearing the app's data removes all three keys, and `install_referrer_checked` and `install_referrer_attempts`.
- Each step is reported to analytics, without the number or the code. The events are in [10-analytics.md](10-analytics.md#onboarding).

## Setting up the backend

The project is `sqvlgiqypqvjykczuhgz` (`https://sqvlgiqypqvjykczuhgz.supabase.co`), created 2026-10-13, and its URL and publishable key are the defaults in [supabase_options.dart](../lib/supabase_options.dart). **Done on 2026-10-13: steps 1 to 5** (linked, both migrations applied, four functions deployed, Send SMS hook set, Phone enabled, SMS rows filled with CashAlert's values). **Not done: the Cashfree part of step 6, and step 7.** All of them change a live project and need the owner's go-ahead. The Supabase CLI is at `~/.local/bin/supabase` and is logged in to the account that owns the project.

[tool/setup_backend.sh](../tool/setup_backend.sh) does steps 1, 2 and 5: `deploy` links, pushes the schema and deploys the four functions; `check` reports, read-only, what the project has. The SMS settings are four `app_config` rows, not function secrets, so there is nothing to push for them. (`secrets` pushes an optional `supabase/functions/.env`; a secret is used only when its row is empty.)

1. **Link the project:** `supabase link --project-ref sqvlgiqypqvjykczuhgz`.
2. **Apply the schema:** `supabase db push`.
3. **Deploy the functions** (step 5 below, done by the script) so the hook has a URL to point at.
4. **SMS.** (The Phone provider form will not save with empty Twilio fields; any placeholder text works, and the hook makes them unused.) Authentication → Hooks → Send SMS hook → HTTPS, `https://sqvlgiqypqvjykczuhgz.supabase.co/functions/v1/sms-hook`; save and copy the secret. Authentication → Sign In / Providers → Phone → enable. Then fill four `app_config` rows: `fast2sms`, `fast2sms_dlt_sender_id` and `fast2sms_dlt_te_id` with the values from CashAlert's `app_config`, and `send_sms_hook_secret` with the secret just copied. With CashAlert's template the SMS wording is CashAlert's until Evos has its own DLT template.
5. **Deploy the functions:** `supabase functions deploy` for each of `sms-hook`, `create-cashfree-subscription`, `verify-cashfree-subscription`, `cashfree-webhook`. Type-check first with `deno check` (Deno is not installed on this machine).
6. **Fill in `app_config`:** `cashfree_app_id`, `cashfree_secret_key`, `customer_email_domain`, and the brand and paywall rows. Leave `cashfree_environment` as `sandbox` until tested.
7. **Cashfree dashboard:** enable Subscriptions, add the webhook URL `https://<ref>.supabase.co/functions/v1/cashfree-webhook`, and ask Cashfree to whitelist the package `com.spacewire.evos` for production.
8. **Build the app.** Nothing to pass: a plain `flutter run` or `flutter build` uses this project. The publishable key is safe to ship; row-level security is what protects the data. To point a build at another project:

   ```sh
   flutter run \
     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<publishable key>
   ```
9. **Set `webview_url`** once migration `20261022120000_webview_url.sql` is pushed (step 2), to the https page subscribers should see.

The Play Store reviewer needs nothing here: the review account is handled in the app ([above](#the-review-account)).

## Platform setup

### Android

**Play Store link.** Nothing to configure in the app. The install referrer only exists for installs that go through Play, so it can be tested only with a build on a Play testing track (internal testing or internal app sharing), opened through a link with the `referrer` parameter. A build installed with `adb` or `flutter run` always reports an organic install.

**UPI apps.** [AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) lists the four UPI packages under `<queries>`. Android 11 and later hides any app not listed there, so the list must match `UPI_APPS` in `PaymentsChannel.kt`.

**Direct link: the one to share with the team** while the app is not on Play: `https://notes-f36b3.web.app/onboarding`. The manifest declares an `autoVerify` intent filter for it; the host must equal `kDeepLinkHost` in [deep_link_service.dart](../lib/services/deep_link_service.dart).

The domain is Firebase Hosting of the `notes-f36b3` project. The site to deploy there is in the repository, **not yet deployed** (as of 2026-10-14 the domain answers "Site Not Found"):

| File | Purpose |
|------|---------|
| [firebase.json](../firebase.json), [.firebaserc](../.firebaserc) | Hosting config. `appAssociation` is `NONE` so Hosting serves our own `assetlinks.json` instead of generating one |
| [web_links/.well-known/assetlinks.json](../web_links/.well-known/assetlinks.json) | Tells Android the link belongs to `com.spacewire.evos` signed with Google Play's app signing key (`4A:2D:5C:…`, what installs from Play carry), the upload key (`C3:40:52:…`, release builds installed by hand) and this machine's debug key (`D3:D7:62:…`). With it, the link opens the app with no question asked |
| [web_links/onboarding/index.html](../web_links/onboarding/index.html) | What a browser shows when the app is not installed (or the domain is not verified): one "Get Evos" button, a Chrome `intent://` URL naming the package. Installed, it opens the app on `/onboarding`; not installed, Chrome opens Play's page for the app and passes `S.market_referrer` as the install referrer. The page asks the user to come back and tap again after installing, because Play withheld the referrer on every test install (2026-10-22). Tested on the test phone against the live Play build on 2026-10-22, served from this Mac: both branches worked and the second tap opened onboarding |

Deploy, once, from the repository root: `brew install firebase-cli`, `firebase login`, `firebase deploy --only hosting`. Android verifies the domain when the app is installed, so a phone that installed the APK before the deploy needs to reinstall it (or `adb shell pm verify-app-links --re-verify com.spacewire.evos`).

Until then, a tester on Android 12 or later can approve the domain by hand, once: Settings → Apps → Evos → Set as default (Open by default) → Add link → tick `notes-f36b3.web.app`.

The file it serves, at `https://notes-f36b3.web.app/.well-known/assetlinks.json`:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.spacewire.evos",
    "sha256_cert_fingerprints": [
      "4A:2D:5C:C1:47:55:AF:2E:E5:09:76:5B:27:72:98:AA:CD:37:C6:FE:FA:35:9F:DC:30:5A:DD:68:D7:73:9E:55",
      "C3:40:52:4B:EB:71:07:05:F5:4C:D7:BA:CD:0E:E9:B2:2A:6E:B5:4A:B0:4C:2B:61:4A:AF:69:10:89:83:87:10",
      "D3:D7:62:74:68:BB:CE:E9:E8:FF:92:7D:FA:05:7B:50:1B:7B:BD:6A:14:E0:5C:BA:7B:8E:03:CE:E0:B9:30:96"
    ]
  }
}]
```

In order: Google Play's app signing key (read with `adb shell pm get-app-links com.spacewire.evos` from a Play install; also in Play Console → Test and release → App integrity), the upload key (read from the signed `.aab` with `keytool -printcert -jarfile`), and this machine's debug key. Without Play's key, links never open an app installed from Play. Add each developer's debug key if they need verified links.

It is not needed for the Play Store route. With adb, the domain can also be approved on a device directly:

```sh
adb shell pm set-app-links-user-selection --user cur --package com.spacewire.evos true notes-f36b3.web.app
```

Then open the link:

```sh
adb shell am start -a android.intent.action.VIEW -d "https://notes-f36b3.web.app/onboarding"
```

### iOS

Not configured. The payment code is Android-only: on iOS the paywall would find no UPI apps. The WebView and phone sign-in have no iOS-specific code but have never been built for iOS. The Google sign-in URL scheme was removed from `Info.plist` on 2026-10-22.

## Tests

- [onboarding_logic_test.dart](../test/onboarding_logic_test.dart): link and referrer matching, stage encoding including older builds' values and the review flag, the mobile-number rules, and `RemoteConfig` parsing and fallbacks.
- [onboarding_flow_test.dart](../test/onboarding_flow_test.dart): widget tests that pump the real `NotesApp`: a plain launch and links (reported, nothing else), the review account (no SMS, fixed code, onto the local notes screen, a note created and kept across a restart, log out without the server), the number and code screens (validation, failure, retry, wrong code, resend, change number), the paywall (backend text, icons, prices and colour, the video card's size, UPI app choice, success, decline, cancel, pending, already subscribed), the web page screen (no URL, Check again picking one up, http refused; the WebView itself cannot exist in a widget test), log out, and restarts (lapsed subscription, missed payment, offline, refused session, older builds' stages).
- [analytics_test.dart](../test/analytics_test.dart): the events the flow sends, in order, and that neither the number nor the code is among them.
- [support/harness.dart](../test/support/harness.dart): the fake backend, fake gateway and launch helper the two widget-test files share.
- [onboarding.yaml](../.maestro/flows/onboarding.yaml) and [review_account.yaml](../.maestro/flows/review_account.yaml): the whole journey in test mode, and the review account, on a device. Written 2026-10-22, not run yet. Their predecessor `onboarding_deeplink` passed on 2026-10-19.

## What is not verified

- **Parts of sign-in.** Working on the test phone against the live project (2026-10-13): the settings fetch, a code sent and verified for a new number, the session saved, the paywall reached. Not seen: a returning number, a wrong or expired code from the real server, resend, a session restored after a restart or refreshed after it expires, log out, and the status check answering "subscribed".
- **The three Cashfree functions.** Deployed, which means they bundled, but none has handled a real request. `sms-hook` has.
- **A real payment.** `CashfreePaymentGateway` and `PaymentsChannel.kt` compile and the app builds with the SDK, but the Cashfree sheet has never been opened from this app, in sandbox or production. That `action_cancelled` is the SDK's code for a user cancel was read from the SDK's classes, not observed.
- **A backend-supplied logo, preview picture, preview video or carousel image.** Only the letter tile has been seen on a device. The carousel is covered by widget tests (slides, auto-advance, swipe, keyboard, slow first launch), and was seen on the test phone from a fresh install on 2026-10-21 with the backend's placeholder images. The video's failure path is covered by a widget test; playback is not.
- **The web page screen on a phone.** The WebView, its settings, back navigation, external links and the error view have not run on a device.
- **The review account's notes on a phone.** The local notes screen, create/edit/delete, persistence across a restart and log out are covered by widget tests only.
- **A Play Store referrer reaching the app.** Tried on 2026-10-22 on the live build: Play withheld it every time; see [07-known-issues.md](07-known-issues.md#deep-link-onboarding). It now matters for attribution only.

## Open items

Listed in [07-known-issues.md](07-known-issues.md#deep-link-onboarding).
