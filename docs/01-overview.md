# Overview

## What the app is

Evos is a subscription app. A user signs in with a mobile number and an SMS code, pays for a UPI AutoPay trial, and then sees a web page (set by the backend) inside the app. It began as a notes app with Google sign-in; since 2026-10-22 Google sign-in is gone and the notes screens are no longer reachable, though their code remains (see [07-known-issues.md](07-known-issues.md#notes-screens-unreachable)).

- Dart package name: `evos`
- Android application ID and iOS bundle ID: `com.spacewire.evos`
- Firebase project: `notes-f36b3`
- Version: `1.0.1+2`

## Features

| Feature | Behaviour |
|---------|-----------|
| Sign in | Mobile number and SMS code, on Supabase. The number 9931133385 with the code 123456 skips the SMS and the paywall and opens the notes screen instead (local-only notes). See [09-deep-link-onboarding.md](09-deep-link-onboarding.md). |
| Paywall | Cashfree UPI AutoPay: a small amount for 24 hours, then monthly. Every text, price and icon can come from the backend. Payment has never run for real. |
| Web page | What a subscriber gets: a WebView of the backend's `webview_url`, with JavaScript, storage, zoom, back navigation, the phone's font size, and `tel:`/`mailto:`/`upi:` links handed to other apps. No file upload. |
| Notes (review number only) | List, editor, swipe-to-delete with Undo, profile. Reached only by 9931133385, backed by a local on-device store (`LocalNotesStore`), not Firebase. The Firestore-backed path is still in the code but unused. |
| App name and icon | "Evos" on the home screen, on Android and iOS. The icon is a white "E" with an amber spark on a violet gradient. Android 8+ uses an adaptive vector icon (`res/drawable/ic_launcher_foreground.xml`, `ic_launcher_background.xml`, with a themed-icon layer for Android 13+); older Android and iOS use PNGs made by `tool/app_icon/make_icons.sh` from the SVGs beside it (macOS only, uses Quick Look and `sips`). A 1024 px copy for stores or the backend's `app_logo_url` is `tool/app_icon/evos_logo_1024.png`. |
| Theme | Material 3 in the launcher icon's colours: violet `#7C3AED` (fidelity scheme) with the amber `#FBBF24` as an accent, and the Poppins font (the website's), bundled in `assets/fonts/` under the OFL. Follows the system light/dark setting. Defined in `lib/theme.dart`. The sign-in, paywall and web page take their seed colour from the backend and keep the default font; this violet/Poppins theme reaches the review number's notes screens. |
| Website | Plain HTML in `website/`, built like CashAlert's: home page, privacy policy, terms, delete-my-data, contact, 404. It still describes the notes app, which no longer matches what the app does ([07-known-issues.md](07-known-issues.md#phone-sign-in-paywall-and-web-page-changed-2026-10-22)); the legal pages list every kind of data the app collects, including mobile number and payments. Not uploaded anywhere; no domain chosen yet. Support, privacy and deletion requests go to `contact@spacewiretech.com`. |
| Analytics | Mixpanel events for every step, and the Facebook SDK for installs and ad measurement. Android only, and off until keys are added. See [10-analytics.md](10-analytics.md). |

There is no account deletion in the app.

## Tech stack

| Area | Choice | Version |
|------|--------|---------|
| Framework | Flutter (stable) | 3.47.5, Dart 3.13.4 |
| State management | `flutter_riverpod` | 3.4.3 |
| Auth (notes, unreachable) | `firebase_auth` | 6.7.0 |
| Database | `cloud_firestore` | 6.10.0 |
| Firebase core | `firebase_core` | 4.15.0 |
| Device storage | `shared_preferences`, for the onboarding stage, the phone sign-in session and the last fetched settings | 2.5.5 |
| Onboarding backend | Supabase (phone sign-in, settings, edge functions), through the pure-Dart `supabase` client | 2.16.2 |
| Payments | `com.cashfree.pg:api`, `core` and `ui`, called from Kotlin over a method channel | 2.4.0 |
| Paywall video | `video_player` (ExoPlayer on Android) | 2.11.1 |
| Web page | `webview_flutter`, `webview_flutter_android` | 4.14.1 / 4.14.1 |
| Links out of the web page | `url_launcher` | 6.3.3 |
| Play install referrer | `com.android.installreferrer:installreferrer`, called from `MainActivity.kt` | 2.2 |
| Analytics | `com.mixpanel.android:mixpanel-android` and `com.facebook.android:facebook-core`, called from Kotlin over a method channel | 8.2.4 / 18.3.0 |
| Lints | `flutter_lints` | 6.0.0 |
| End-to-end tests | Maestro CLI (installed in `~/.maestro`, not a pub dependency) | 2.11.0 |
| Android build | Gradle 9.3.1, Android Gradle Plugin 9.1.0, Kotlin 2.4.0, Java 17 target | |
| iOS build | Swift Package Manager (no Podfile), deployment target iOS 15.0 | |

There is no routing package, no deep-link plugin, no analytics plugin, no payment plugin, no code generation, no `intl`, and no dependency-injection package other than Riverpod.

The three FlutterFire packages are pinned to exact versions and must be bumped together. The reason is in the comment in [pubspec.yaml](../pubspec.yaml) and in [05-setup-and-build.md](05-setup-and-build.md#dependency-rules).

## Platform support

| Platform | Status |
|----------|--------|
| Android | Configured. Debug APK build verified on 2026-10-22. Real SMS sign-in ran on 2026-10-13; the review-number notes, the WebView and real Cashfree payment have never run on a phone. |
| iOS | Configured in code (Firebase options). Build not verified on this machine. The payment code is Android-only. |
| Web, macOS, Windows, Linux | Scaffold folders exist, but [firebase_options.dart](../lib/firebase_options.dart) throws `UnsupportedError`, so the app shows the "Evos couldn't start" screen. |

## Project layout

```
notes_app/
├── lib/                 App source (see 02-architecture.md)
├── test/                Unit and widget tests
├── .maestro/            End-to-end flows (see 08-e2e-testing.md)
├── tool/maestro.sh      Runs the Maestro CLI with the right JDK and adb
├── android/ ios/        Configured platform projects
├── web/ macos/ linux/ windows/   Unconfigured scaffolds
├── website/             Public website (still describes notes) and legal pages, plain HTML, not uploaded
├── firestore.rules      Security rules, published by hand in the Firebase console
├── pubspec.yaml         Dependencies and version
├── docs/                This documentation
├── CLAUDE.md, AGENTS.md Entry points that load docs/ai/AGENT_CONTEXT.md for AI agents
```
