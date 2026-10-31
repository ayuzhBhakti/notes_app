# Evos ad attribution and user tracking: team guide

*Written 31 Oct 2026 from the code on branch `feat/ad-attribution`. **The backend is live** (since 31 Oct: the decode function with the Meta key, the database columns, and server payment events), **but no app build with this code has been released yet**, so no install is decoded until it is. The numbers in [section 8](#8-after-the-release-the-mixpanel-check) are the targets to check after release, not results.*

This guide covers how Evos learns which ad or link brought each user, how to make links for campaigns, and how to follow a user from an ad to a paid subscription in Mixpanel. Developers will find the details in [09-deep-link-onboarding.md](09-deep-link-onboarding.md) and [10-analytics.md](10-analytics.md).

---

## Quick answers

| I want to… | Do this |
|---|---|
| Know which Meta ad a user came from | Nothing to set up once this is released and the key is set. The app reads it automatically for every Meta ad-click install ([section 3](#meta-facebook--instagram-ads)). |
| See which ad brings the most ₹3 trials | Mixpanel funnel **OTP Verified → Checkout Started → Subscription Succeeded**, broken down by `utm_content` ([Funnel A](#funnel-a--which-ad-brings-3-trials)). |
| Make a link for YouTube, WhatsApp, influencers or SMS | Use a Play Store link with `referrer=` ([section 3](#any-other-channel-youtube-whatsapp-influencers-sms)). |
| Give a partner its own name, logo, price or web page | Add a `webview_sources` row whose `source` is the partner's `utm_source` ([section 2](#2-utm_source-also-picks-the-apps-look-and-price)). |
| See one user's full journey | Find their user id in Supabase, then search it in Mixpanel → Users ([section 6](#see-one-users-journey)). |
| Count users, trials and paid subscribers per ad with SQL | Query the `profiles` table ([section 6](#from-the-database)). |

**Golden rule:** make `utm_content` unique per creative. It is the breakdown every report uses.

---

## 1. What a link does in Evos

In Evos a link **does not open a particular screen**. Everyone goes through the same steps:

```
Install (or app opened from a link)
  → mobile number → SMS code
  → paywall → ₹3 trial (UPI AutoPay)
  → the web page
```

A link has two jobs here:

1. **Tell us where the user came from**: the campaign, ad set and ad. This goes on every Mixpanel event and on the user's row in the database.
2. **Pick the app's look and price** for partner sources ([section 2](#2-utm_source-also-picks-the-apps-look-and-price)).

The four ways a user arrives:

| # | Type | Looks like | Tracks the ad? |
|---|---|---|---|
| 1 | **Play Store link with referrer** | `https://play.google.com/store/apps/details?id=com.spacewire.evos&referrer=…` | ✅ Yes, for new installs |
| 2 | **Meta ad install** (automatic) | Nothing to build. Meta puts the ad, encrypted, in the Play Store referrer. | ✅ Campaign, ad set, ad and all ids, once decoded by our backend |
| 3 | **Google Ads install** (automatic) | Nothing to build. Google adds click ids (`gclid`, `gbraid`). | ⚠️ Marked `google_ads`, but **no campaign or ad names** ([section 3](#google-ads)) |
| 4 | **App Link** | `https://notes-f36b3.web.app/onboarding?utm_source=…` | ✅ For people who already have the app. ⚠️ The link's website is not deployed, so Android may show a chooser and people without the app reach nothing. Prefer #1. |

---

## 2. `utm_source` also picks the app's look and price

The `utm_source` an install arrives with (lowercased) is saved on the phone and looked up in the `webview_sources` table. A matching row can change the app's name, logo, colour, paywall text, login slides, web page, plan and price for that user. No match means the normal settings.

- Keep `utm_source` **lowercase, one word, no spaces** (`filmyface`, not `Filmy Face`).
- A **Meta ad install arrives as `apps.facebook.com`** (or `apps.instagram.com`), not `meta` or `facebook`. A `webview_sources` row named `facebook` therefore does **not** match Meta ad installs today. To give Meta ad users their own look or price, add a row with `source = apps.facebook.com` (and one for `apps.instagram.com`). This was left as it is on purpose; changing it is a product decision.
- The analytics `utm_source` is different: it is normalised to `meta` for every Meta source, so reports group all Meta traffic together.

---

## 3. Making links for campaigns

### Naming rules (all channels)

| Parameter | What to put | Example |
|---|---|---|
| `utm_source` | Platform or partner, lowercase, one word | `youtube`, `whatsapp`, `filmyface` |
| `utm_medium` | Type of traffic | `paid`, `influencer`, `organic` |
| `utm_campaign` | Campaign name | `Evos_Diwali_Hindi` |
| `utm_term` | Ad set / ad group | `31_Oct_1st` |
| `utm_content` | **Ad / creative name. Unique per creative.** | `Evos_Reel_Hindi_30s_31OCT26` |

- `utm_source` counts as Meta when it is exactly `meta`, `facebook`, `fb`, `instagram` or `ig`. Anything else is `other`.
- `campaign_id`, `adset_id` and `ad_id` are recorded when a link has them.

### Meta (Facebook / Instagram) ads

**What happens automatically.** Every install from a Meta ad click carries the ad, encrypted, in the Play Store referrer. On first launch the app sends the whole referrer to our backend function `meta-install-referrer`, which decrypts it with Meta's key and returns:

| Meta | Saved as |
|---|---|
| Campaign name / id | `utm_campaign` / `campaign_id` |
| Ad set name / id | `utm_term` / `adset_id` |
| Ad name / id | `utm_content` / `ad_id` |
| — | `install_source = meta`, `utm_source = meta`, `utm_medium = paid` |

So every Meta ad is tracked by name with nothing to set up in Ads Manager. The app then sends `Meta Ad Attributed` once.

- If the phone is offline, the app tries again on later launches (up to 5).
- **Users who installed an older version** are decoded on their first launch after updating, while Play still keeps their install referrer (90 days). `Meta Ad Attributed` then has `is_new_install = false`.
- **View-through installs** (the person saw the ad but didn't click) have no referrer. They count as `organic`, with no ad.
- Meta's "Deep link" field in the ad is not needed: links don't open screens in Evos.

### Google Ads

Nothing to set up, and nothing to gain from one: Google's Play Store referrer has only click ids (`gclid`, `gbraid`, `gad_source`). Some installs also carry `gad_campaignid`, a campaign **number**. In the app:

- `install_source = google_ads`, `utm_source = google`, `utm_medium = paid`. ✅
- `campaign_id` = `gad_campaignid` when Google sent it. No campaign, ad set or ad names. ❌
- The `gclid` is kept on the user's database row (never sent to Mixpanel), so names could later be looked up with the Google Ads API.

**For per-campaign Google numbers, use the Google Ads console.**

### Any other channel (YouTube, WhatsApp, influencers, SMS)

Use a Play Store link with a referrer:

```
https://play.google.com/store/apps/details?id=com.spacewire.evos&referrer=utm_source%3Dyoutube%26utm_medium%3Dinfluencer%26utm_campaign%3Ddiwali%26utm_content%3Dkhushi_video1
```

- Everything after `referrer=` must be **URL-encoded**: `=` becomes `%3D` and `&` becomes `%26`. Parameters added to the Play URL itself, after the referrer, never reach the app.
- An encoder such as urlencoder.org can build the referrer part.

---

## 4. What gets recorded

### Mixpanel events along the journey

| Order | Event | Sent by | When | Useful properties |
|---|---|---|---|---|
| 1 | `App Opened` | app | Every launch | — |
| 2 | `Install Attributed` | app | Once per install | `install_source`, `utm_*` the referrer had, `install_referrer_raw` (first 100 characters) |
| 3 | `Meta Ad Attributed` | app | Once per Meta ad-click install, when decoded | `utm_campaign`, `utm_term`, `utm_content`, `campaign_id`, `adset_id`, `ad_id`, `publisher_platform`, `platform_position`, `is_instagram`, `is_new_install` |
| 4 | `Deep Link Opened` | app | An onboarding link opened the app | `after_install` |
| 5 | `Phone Entry Viewed`, `OTP Requested` | app | Mobile-number screen, code sent | — |
| 6 | `OTP Verified` | app | Sign-in succeeded. **The person is identified here** | `new_user` |
| 7 | `Paywall Viewed`, `Checkout Started` | app | Paywall, "Try Now" | `plan_id`, `upi_app` |
| 8 | `Subscription Succeeded` | app | The ₹3 mandate was approved | `amount`, `simulated` |
| 9 | `Payment Succeeded` | **server** | Every payment recorded | `payment_type`: `trial` (₹3), `auto_renewal` (monthly), `retry` (a debit after a failed one) |
| — | `Payment Failed` | server | A debit failed | `payment_type` |
| — | `Subscription Cancelled`, `Subscription Expired` | server | The mandate ended | `cashfree_status` |

The full list is in [10-analytics.md](10-analytics.md).

### Properties on every event once the ad is known

`install_source`, `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content`, `campaign_id`, `adset_id` and `ad_id`.

- **App events** carry them as super properties, from the first launch on. They hold the **latest** ad (last touch): a link with `utm_*` replaces the install's ad. An organic visit never replaces a known ad.
- **Server events** carry the same properties, read from the user's database row when the event is sent. You can break server events down by event property `utm_content` directly.

### On the user's Mixpanel profile

| Property | Meaning |
|---|---|
| `utm_campaign`, `utm_term`, `utm_content`, `ad_id`, … | Latest ad (last touch) |
| `first_utm_campaign`, `first_utm_content`, `first_ad_id`, … | First ad ever (first touch) |
| `install_source` | Where the first install came from |

No name, email or phone number is ever sent to Mixpanel.

### In the database (`profiles` table)

`install_source`, `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content`, `campaign_id`, `adset_id`, `ad_id`, `gclid`, `attributed_at`. These hold the latest ad and are saved once the user has signed in. Only the app's own database function (`save_user_attribution`) can write them, and only to the signed-in user's own row. The store-review number is never saved (it has no account).

---

## 5. Check that pre-login and post-login events join

Before sign-in, Mixpanel knows a user only by their device. At sign-in (`OTP Verified`) the app calls `identify` with the user's Supabase user id. Whether Mixpanel then joins the two into **one** person depends on a project setting that **has not been checked yet**. In another of our apps (Bhaktilok) they didn't join, and every install → purchase funnel showed about 1%.

Check it once, after the first release:

1. Mixpanel → **Project settings → Identity merge**. Note which it is: *Simplified API* or *Original API* (and whether ID merge is on).
2. **Insights**: event `$identify`, total, last 7 days. Under the Original API, each sign-in should create one; under Simplified, none are expected, and that's fine.
3. **Users**: open any person who signed in recently. Their **Activity Feed** should show `Install Attributed` and `Phone Entry Viewed` *before* `OTP Verified` on the same profile. If it starts at `OTP Verified`, the two halves aren't joined.
4. **Funnel** `Install Attributed` → `OTP Verified` (1 day), last 7 days. Joined: a large share (most installs sign in). Not joined: close to 0%.

If they don't join, start funnels at `OTP Verified` (Funnel A does). You still have the ad, because every event after the ad is known carries it. To fix it, switch the project to Simplified ID Merge (ask Mixpanel support whether existing data is affected) or turn on ID Merge for the Original API.

---

## 6. Tracking the user journey in Mixpanel

### Funnel A — Which ad brings ₹3 trials

Mixpanel → **Funnels**:

| Step | Event | Filter |
|---|---|---|
| 1 | `OTP Verified` | `utm_source` equals `meta` (or leave out for all sources) |
| 2 | `Checkout Started` | — |
| 3 | `Subscription Succeeded` | `simulated` equals `false` |

- **Conversion window:** 1 day.
- **Breakdown:** event property `utm_content` (the ad). Then try `utm_term` (ad set) and `utm_campaign`.
- This works whether or not the identity check in [section 5](#5-check-that-pre-login-and-post-login-events-join) passes, because it starts after sign-in.

### Funnel B — Trial → first paid month

| Step | Event | Filter |
|---|---|---|
| 1 | `Payment Succeeded` | `payment_type` equals `trial` |
| 2 | `Payment Succeeded` | `payment_type` is any of `auto_renewal`, `retry` |

- **Conversion window:** 30 days. The first monthly debit is a day after the trial.
- **Breakdown:** event property `utm_content`.
- Pick a date range at least 30 days in the past so everyone has had time to convert.

### Insights reports

| Question | Report |
|---|---|
| How many installs did each Meta ad bring? | `Meta Ad Attributed`, unique users, breakdown `utm_content` |
| How many installs came from each source? | `Install Attributed`, unique users, breakdown `install_source` |
| Trials per ad | `Payment Succeeded` with `payment_type = trial`, unique users, breakdown `utm_content` |
| Paid months per ad | `Payment Succeeded` with `payment_type` in `auto_renewal`, `retry`, breakdown `utm_content` |
| Failed debits per ad | `Payment Failed`, breakdown `utm_content` |
| Did a partner get its own page? | `Web Page Viewed`, breakdown `config_source`, then `web_host` |

The trial is counted twice for each user: `Subscription Succeeded` (app) and `Payment Succeeded` with `payment_type = trial` (server). Use one or the other, not both.

### See one user's journey

Mixpanel never receives phone numbers, so you need the user's id first.

1. Supabase → Table Editor → `profiles` → filter `phone` → copy the `id`. (Only people with database access can do this.)
2. Mixpanel → **Users** → search that id → open the profile. **Activity Feed** shows everything from sign-in onwards, with the ad on each event.
3. If the identity check passed, the pre-login events are there too. Otherwise open any event, copy its `$device_id`, and in **Events** filter `$device_id` equals that value.

### From the database

The most reliable per-ad numbers come from `profiles` (signed-in users, latest ad) joined to `subscription_payments`. Ask a developer to run:

```sql
select p.utm_content as ad,
       count(*) as users,
       count(*) filter (where exists (
         select 1 from public.subscription_payments s
          where s.user_id = p.id and s.status = 'success' and s.plan_type = 'trial')) as trials,
       count(*) filter (where exists (
         select 1 from public.subscription_payments s
          where s.user_id = p.id and s.status = 'success' and s.plan_type = 'monthly')) as paid
  from public.profiles p
 where p.utm_source = 'meta'
   and p.attributed_at >= '<release date>'
 group by 1
 order by 2 desc;
```

Swap `utm_content` for `utm_campaign` or `utm_term` to group by campaign or ad set.

---

## 7. Testing

| What | How |
|---|---|
| Play Store referrer and Meta decoding | Needs a real **Play Store install** (internal testing track). An APK installed by hand has no install referrer. |
| A referrer link on a test phone | The phone must have **no work or Google Workspace account** on it, or Play blanks the referrer for every install. |
| See it in Mixpanel | Tag test links with `utm_source=qa_test` so they can be filtered out of reports. |
| Watch what the app recorded | A debug build prints every analytics call to the console, tagged `[analytics]`, including `setAttribution`. |
| The backend function | `supabase functions logs meta-install-referrer` shows `decoded`, `decrypt_failed`, `other_app` or `not_configured`. It never logs the key or the referrer. |

- **Never test sign-in with a made-up number on a normal build**: it sends a real SMS to a stranger. Use a test-mode build or a number you own.
- **Never tap "Try Now" on a normal build without meaning to**: payments are live and take real money.

---

## 8. After the release: the Mixpanel check

Do this a few days after the release, filtering to the new `app_version` and comparing it with the old one:

| Check | Report | Target |
|---|---|---|
| Meta installs decoded | Insights, unique users, breakdown `app_version`: **A** = `Install Attributed` where `install_source = meta`; **B** = `Meta Ad Attributed` where `is_new_install = true`. B ÷ A | **90% or more** |
| Checkout carries the ad | `Checkout Started` where `utm_source = meta`, breakdown `app_version`, then `utm_content` (is set / is not set) | Nearly all set |
| Payments carry the ad | `Payment Succeeded` where `utm_source = meta`, date from the release on, breakdown `utm_content` (is set / is not set) | Nearly all set |

- Server events carry no `app_version`, so filter payments by date (from the release on) instead.
- Well under 90% decoded: check the function logs for `decrypt_failed` (wrong key) or `not_configured` (key not set), and that the function was deployed. **A wrong key is costly**: every Meta install that gets `decrypt_failed` gives up for good. Watch the logs on release day.

---

## 9. iOS

Evos has an iOS target in its code, but it has never been built, payments are Android-only, and analytics sends nothing on iOS. **iOS has no install referrer**, so none of this works there. Measuring iOS ads needs a different approach: Apple's SKAdNetwork / AdAttributionKit, Meta's Aggregated Event Measurement through the Facebook SDK, or a mobile measurement partner. None of this is built.

---

## 10. Status and known gaps (31 Oct 2026)

| Gap | Effect | Fix |
|---|---|---|
| App not released | No install is decoded and no ad is saved until a build with this code is on Play | Version bump, `.aab`, Play upload |
| Meta key not proven on a real ad | The function decrypts with the configured key, but no real Meta referrer has been seen | One install from a real Meta ad click; logs should show `decoded` |
| Identity merge not checked | Funnels that start before sign-in may look broken | [Section 5](#5-check-that-pre-login-and-post-login-events-join) |
| Meta installs arrive as `apps.facebook.com` | A `webview_sources` row `facebook` doesn't apply to them | [Section 2](#2-utm_source-also-picks-the-apps-look-and-price) |
| Google Ads has no names | Per-campaign Google results only in the Google Ads console | Look up `gclid` with the Google Ads API (needs a developer token) |
| View-through installs | Counted as organic | None possible from the referrer |
| App Link website not deployed | `https://notes-f36b3.web.app/...` reaches nothing for people without the app | Deploy `web_links/` or use Play Store links |
| iOS | Nothing tracked | [Section 9](#9-ios) |

---

## 11. For developers: where things live

| Part | File |
|---|---|
| The attribution model (install source, utm fields, Meta ad) | `lib/models/attribution.dart` |
| Decode, retries, the pass after an update, saving to the server | `lib/services/attribution_service.dart` |
| First-launch referrer read, `Install Attributed` | `lib/main.dart`, `lib/services/install_referrer_service.dart`, `MainActivity.kt` |
| Events, super properties, profile | `lib/services/analytics.dart`, `android/.../analytics/MixpanelSdk.kt`, `AnalyticsChannel.kt` |
| Backend calls | `lib/services/evos_backend.dart` (`decodeMetaReferrer`, `saveAttribution`) |
| Meta decrypt | `supabase/functions/_shared/meta_referrer.ts`, function `supabase/functions/meta-install-referrer/` |
| Server Mixpanel events | `supabase/functions/_shared/mixpanel.ts`, used by `cashfree-webhook` and `verify-cashfree-subscription` |
| `profiles` ad columns, `save_user_attribution` | `supabase/migrations/20261031120000_user_attribution.sql` |
| Per-source look and price | `webview_sources`, see [09-deep-link-onboarding.md](09-deep-link-onboarding.md#per-source-app-identity-the-webview_sources-table) |
| Tests | `test/attribution_test.dart`, `supabase/functions/_shared/meta_referrer.test.ts`, `mixpanel.test.ts` |
