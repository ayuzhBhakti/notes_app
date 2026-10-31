# Evos Mixpanel Events Guide

*Last updated: 31 Oct 2026*

Evos sends every step of a user's journey to Mixpanel, from install to monthly payment. Every event carries the ad the user came from. The **app** sends 27 events and the **server** sends 4 more. Mixpanel never receives a phone number, a sign-in code, or note text.

The full technical list is in [10-analytics.md](10-analytics.md). Making campaign links is in [DEEPLINK_GUIDE.md](DEEPLINK_GUIDE.md).

---

## 1. How tracking works

```
  Install from an ad or link
            │
            ▼
  ┌──────────────────┐   events from the phone    ┌────────────┐
  │    Evos app      │ ─────────────────────────► │            │
  │ (sign-in, paywall│                            │  Mixpanel  │
  │  web page)       │                            │            │
  └────────┬─────────┘                            └────────────┘
           │ saves "which ad" on the user's row          ▲
           ▼                                             │
  ┌──────────────────┐  payments, renewals, cancels      │
  │ Server (Supabase)│ ──────────────────────────────────┘
  └──────────────────┘   each with the same ad fields
```

- **Before sign-in**, Mixpanel knows the user only by their phone (device).
- **At sign-in** (`OTP Verified`) the app tells Mixpanel who the user is, by their account id (never the phone number).
- **Server events** use the same account id, so they land on the same user.

---

## 2. The user journey

The main events in the order a new user sends them:

| Step | Event | Sent by |
|---|---|---|
| 1 | `App Opened` | App |
| 2 | `Install Attributed` (where the install came from) | App |
| 3 | `Meta Ad Attributed` (only for a Facebook/Instagram ad click) | App |
| 4 | `Phone Entry Viewed` | App |
| 5 | `OTP Requested` | App |
| 6 | `OTP Verified` (user is signed in and identified) | App |
| 7 | `Paywall Viewed` | App |
| 8 | `Checkout Started` (tapped "Try Now") | App |
| 9 | `Subscription Succeeded` (₹3 trial approved) | App |
| 10 | `Payment Succeeded`, `payment_type` = `trial` | Server |
| 11 | `Web Page Viewed` | App |
| 12 | `Payment Succeeded`, `payment_type` = `auto_renewal` (each month) | Server |

---

## 3. Which ad a user came from

These properties are added to **every event**, from the app and from the server, as soon as the ad is known:

| Property | Meaning | Example |
|---|---|---|
| `install_source` | Where the install came from: `meta`, `google_ads`, `organic`, `other` or `unknown` | `meta` |
| `utm_source` | The platform or partner | `meta`, `google`, `youtube` |
| `utm_medium` | Type of traffic | `paid` |
| `utm_campaign` | Campaign name | `Evos_AppInstalls_Hindi` |
| `utm_term` | Ad set name | `Broad_18-45` |
| `utm_content` | **Ad name (the creative). The most useful breakdown.** | `Evos_Reel_Hindi_30s` |
| `campaign_id`, `adset_id`, `ad_id` | Meta's ids for the same three | `120212345678901234` |

What `install_source` means:

| Value | When |
|---|---|
| `meta` | A Facebook or Instagram ad click, or a link with `utm_source` = meta, facebook, fb, instagram or ig |
| `google_ads` | A Google Ads click. Google gives no campaign or ad names, so check the Google Ads console for those |
| `organic` | Found in the Play Store with no link. Also a Meta ad that was seen but not clicked |
| `other` | Any other link with a `utm_source` (YouTube, WhatsApp, a partner) |
| `unknown` | Play gave nothing usable |

These are the user's **latest** ad. If they later open a link with a different campaign, that becomes the latest. A visit with no campaign never replaces a known ad.

---

## 4. Every app event

### Install and links

| Event | When it fires | Useful properties |
|---|---|---|
| `App Opened` | Every time the app starts | — |
| `Install Attributed` | Once per install, when Play says where it came from | the ad fields, `install_referrer_raw` (what Play sent), `referrer_click_recorded` |
| `Meta Ad Attributed` | Once per Facebook/Instagram ad-click install, after the server reads the ad | `utm_campaign`, `utm_term`, `utm_content`, the three ids, `publisher_platform`, `platform_position`, `is_instagram`, `is_new_install` |
| `Deep Link Opened` | The app was opened from an Evos link | `after_install` |

### Sign-in

| Event | When it fires | Useful properties |
|---|---|---|
| `Phone Entry Viewed` | The mobile-number screen opens | — |
| `OTP Requested` | "Send code" or "Resend code" is tapped | `resend`, `country` (e.g. `IN`) |
| `OTP Request Failed` | The code could not be sent | `reason` |
| `OTP Verified` | The code was right; the user is now identified | `new_user` |
| `OTP Verify Failed` | The code was wrong, or could not be checked | `reason` |
| `Review Account Signed In` | The Play review number signed in (not a real user) | — |

### Paywall and payment

| Event | When it fires | Useful properties |
|---|---|---|
| `Paywall Viewed` | The paywall opens | — |
| `UPI App Selected` | The user picks a different UPI app | `upi_app` (e.g. PhonePe) |
| `Checkout Started` | "Try Now" is tapped | `plan_id`, `upi_app` |
| `Subscription Succeeded` | The ₹3 trial mandate was approved | `plan_id`, `amount`, `currency`, `simulated` |
| `Checkout Cancelled` | The user backed out of the UPI app | `plan_id` |
| `Checkout Failed` | The payment failed or could not start | `plan_id`, `reason` |

### Web page

| Event | When it fires | Useful properties |
|---|---|---|
| `Web Page Viewed` | The web page screen opens (on every launch for a subscriber) | `has_url`, `config_source` (the partner tag), `web_host` |
| `Web Page Failed` | The web page could not load | `reason` (e.g. `timeout`) |

### Review account only

The Play review number opens a small notes screen. These events come only from it, so they are not real users:

`Notes List Viewed`, `Note Editor Opened`, `Note Created`, `Note Updated`, `Note Deleted`, `Note Restored`, `Note Action Failed`, `Profile Viewed`, `Signed Out`.

---

## 5. Server events

The server sends these because the app is often closed when they happen (for example, the monthly debit). Each one carries the ad fields from [section 3](#3-which-ad-a-user-came-from) and `event_source` = `server`.

| Event | When it fires | Useful properties |
|---|---|---|
| `Payment Succeeded` | A payment is recorded for the first time | `payment_type`: `trial` (₹3), `auto_renewal` (monthly), `retry` (a debit that worked after a failed one). Also `amount`, `currency`, `plan_type` |
| `Payment Failed` | A debit failed | `payment_type` (`auto_renewal` or `retry`), `amount` |
| `Subscription Cancelled` | The user cancelled or paused the AutoPay mandate | `cashfree_status` |
| `Subscription Expired` | The mandate ended | `cashfree_status` |

### Facebook (Meta) events

The app also tells Facebook about three moments, so Meta ads can optimise:

| Facebook event | When |
|---|---|
| Complete registration | A new account signed in for the first time |
| Initiated checkout | "Try Now" was tapped |
| Purchase + Subscribe | A real (not test) trial payment succeeded |

---

## 6. The user's Mixpanel profile

| Property | Meaning |
|---|---|
| `utm_campaign`, `utm_term`, `utm_content`, `ad_id`, … | The latest ad |
| `first_utm_campaign`, `first_utm_content`, `first_ad_id`, … | The first ad ever, never overwritten |
| `install_source` | Where the first install came from |

No name, email or phone number is stored on the profile. To find one user, a developer looks up their account id in Supabase (table `profiles`) and you search that id in Mixpanel → **Users**.

---

## 7. Ready-made reports

**A. Which ad brings the most ₹3 trials** (Funnels)

| Step | Event | Filter |
|---|---|---|
| 1 | `OTP Verified` | `utm_source` = `meta` (or no filter for all sources) |
| 2 | `Checkout Started` | — |
| 3 | `Subscription Succeeded` | `simulated` = `false` |

Conversion window: 1 day. Breakdown: `utm_content`.

**B. Trial → first paid month** (Funnels)

| Step | Event | Filter |
|---|---|---|
| 1 | `Payment Succeeded` | `payment_type` = `trial` |
| 2 | `Payment Succeeded` | `payment_type` = `auto_renewal` or `retry` |

Conversion window: 30 days. Breakdown: `utm_content`. Use a date range at least 30 days back.

**C. Quick counts** (Insights, count unique users)

| Question | Event | Breakdown |
|---|---|---|
| Installs per Meta ad | `Meta Ad Attributed` | `utm_content` |
| Installs per source | `Install Attributed` | `install_source` |
| Trials per ad | `Payment Succeeded`, `payment_type` = `trial` | `utm_content` |
| Paid months per ad | `Payment Succeeded`, `payment_type` = `auto_renewal` or `retry` | `utm_content` |
| Failed debits per ad | `Payment Failed` | `utm_content` |
| Cancellations per ad | `Subscription Cancelled` | `utm_content` |

---

## 8. Rules and things to watch out for

- **Count unique users, not totals.** Screen events fire on every visit; `Web Page Viewed` fires on every launch for a subscriber.
- **The trial appears twice:** `Subscription Succeeded` (app) and `Payment Succeeded` with `trial` (server). Use one or the other, not both.
- **Hide test traffic.** Filter out `simulated` = `true`, the `Review Account Signed In` users, and links tagged `utm_source` = `qa_test`.
- **Start funnels at `OTP Verified`** until the identity check below is done. A funnel that starts before sign-in may look broken (close to 0%) if Mixpanel doesn't join the user's two halves.
- **Server events have no app version.** Filter them by date instead.
- **Meta ads seen but not clicked** count as `organic`, with no ad.

---

## 9. What is live today (31 Oct 2026)

| Part | Status |
|---|---|
| Server events (`Payment Succeeded` and the others) | **Live.** They start with the next real payment |
| Reading Meta ads on the server | **Live** |
| `Meta Ad Attributed` and the ad fields on app events | Waiting for the next app release on Play |
| Joining pre-sign-in and post-sign-in events into one user | **Not checked yet.** In Mixpanel: open a recent user's Activity Feed. If it shows `Install Attributed` before `OTP Verified`, it works |
