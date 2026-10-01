# Overview

## What the app is

Notes is a personal note-taking app. A user signs in with Google and keeps a private list of text notes that syncs through Cloud Firestore and keeps working offline.

- Dart package name: `notes`
- Android application ID and iOS bundle ID: `com.spacewire.notes`
- Firebase project: `notes-f36b3`
- Version: `1.0.0+1`

## Features

| Feature | Behaviour |
|---------|-----------|
| Sign in | Google only, through Firebase Authentication. No email/password, no anonymous use. |
| Notes list | Live list, newest edit first. Each row shows a title, a two-line preview and a relative time. |
| Create and edit | One editor screen for both. Title (max 200 characters) and a free-form body. |
| Delete | Swipe a row left, or use the delete button in the editor. A 6-second snackbar offers Undo. |
| Offline | Writes land in Firestore's local cache at once and sync on reconnect. Unsynced rows show "Saving…". |
| Profile | Photo or initials, name, email, user ID, and Log out with a confirmation dialog. |
| Theme | Material 3, indigo seed colour, follows the system light/dark setting. |
| Deep-link onboarding | Installing from a Play Store link with `referrer=flow%3Donboarding` replaces the notes app with a details form (saved to Supabase), a paywall (simulated payment) and a member home. No sign-in, and no way back to notes. See [09-deep-link-onboarding.md](09-deep-link-onboarding.md). |

There is no search, no folders or tags, no rich text, no attachments, no sharing, and no account deletion.

## Tech stack

| Area | Choice | Version |
|------|--------|---------|
| Framework | Flutter (stable) | 3.47.5, Dart 3.13.4 |
| State management | `flutter_riverpod` | 3.4.3 |
| Auth | `firebase_auth` + `google_sign_in` | 6.7.0 / 7.2.0 |
| Database | `cloud_firestore` | 6.10.0 |
| Firebase core | `firebase_core` | 4.15.0 |
| Device storage | `shared_preferences`, for onboarding state only | 2.5.5 |
| Onboarding form storage | Supabase, through the pure-Dart `supabase` client | 2.16.2 |
| Play install referrer | `com.android.installreferrer:installreferrer`, called from `MainActivity.kt` | 2.2 |
| Lints | `flutter_lints` | 6.0.0 |
| End-to-end tests | Maestro CLI (installed in `~/.maestro`, not a pub dependency) | 2.11.0 |
| Android build | Gradle 9.3.1, Android Gradle Plugin 9.1.0, Kotlin 2.4.0, Java 17 target | |
| iOS build | Swift Package Manager (no Podfile), deployment target iOS 15.0 | |

There is no routing package, no deep-link plugin, no payment SDK, no code generation, no `intl`, and no dependency-injection package other than Riverpod.

The three FlutterFire packages are pinned to exact versions and must be bumped together. The reason is in the comment in [pubspec.yaml](../pubspec.yaml) and in [05-setup-and-build.md](05-setup-and-build.md#dependency-rules).

## Platform support

| Platform | Status |
|----------|--------|
| Android | Configured. Debug APK build verified on 2026-10-01. Onboarding by Play Store referrer is implemented but untested through Play. |
| iOS | Configured in code (Firebase options, client ID, URL scheme). Build not verified on this machine. Onboarding has no way in on iOS. |
| Web, macOS, Windows, Linux | Scaffold folders exist, but [firebase_options.dart](../lib/firebase_options.dart) throws `UnsupportedError`, so the app shows the "Notes couldn't start" screen. |

## Project layout

```
notes_app/
├── lib/                 App source (see 02-architecture.md)
├── test/                Unit tests for pure logic
├── .maestro/            End-to-end flows (see 08-e2e-testing.md)
├── tool/maestro.sh      Runs the Maestro CLI with the right JDK and adb
├── android/ ios/        Configured platform projects
├── web/ macos/ linux/ windows/   Unconfigured scaffolds
├── firestore.rules      Security rules, published by hand in the Firebase console
├── pubspec.yaml         Dependencies and version
├── docs/                This documentation
├── CLAUDE.md, AGENTS.md Entry points that load docs/ai/AGENT_CONTEXT.md for AI agents
```
