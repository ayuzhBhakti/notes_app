# Setup and build

## Requirements

| Tool | Version in use | Notes |
|------|----------------|-------|
| Flutter | 3.47.5 stable (Dart 3.13.4) | `pubspec.yaml` requires Dart `^3.13.2` |
| Android Studio | Any recent version | Its bundled JDK (25) is the only JDK on the dev machine; Flutter finds it automatically |
| Android SDK | Platform 36, NDK 28.2.13676358 | Gradle installs missing components on first build |
| Xcode | 26.3 | iOS only |

Gradle 9.3.1 is downloaded by the wrapper on the first Android build.

## Commands

```sh
flutter pub get          # install dependencies
flutter run              # run on the connected device
flutter analyze          # static analysis; must report no issues
flutter test             # unit tests; all must pass
flutter build apk --debug
```

## Firebase configuration

The app is configured in Dart, not through native config files.

| Item | Where |
|------|-------|
| Firebase options (API key, app ID, project ID) | [lib/firebase_options.dart](../lib/firebase_options.dart), written by hand |
| Google OAuth client IDs | `kWebClientId` and `kIosClientId` in [lib/services/auth_service.dart](../lib/services/auth_service.dart) |
| iOS OAuth redirect | A `google-sign-in` URL type in [ios/Runner/Info.plist](../ios/Runner/Info.plist) |
| Firestore rules | [firestore.rules](../firestore.rules), published by hand (see [04-data-model.md](04-data-model.md#publishing-rules)) |

Things that are deliberately absent:

- The `google-services` Gradle plugin is not applied. [android/app/google-services.json](../android/app/google-services.json) is in the repository but the build does not read it.
- There is no `GoogleService-Info.plist` on iOS.
- The FlutterFire CLI and the Firebase CLI are not installed.

### Android signing certificate

Google sign-in on Android identifies the app by package name plus the SHA-1 of its signing key. Each developer machine has its own debug key, and each one must be added in Firebase Console → Project settings → Your apps → Add fingerprint.

```sh
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android | grep SHA1
```

If the fingerprint is missing, sign-in appears to be cancelled with no error. The app shows a hint banner for this case.

Release builds are currently signed with the debug key ([android/app/build.gradle.kts](../android/app/build.gradle.kts)).

### Supabase

The onboarding form is saved to Supabase. The project is passed at build time, and without it nothing is saved:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

The same two flags go on `flutter build`. The table to create is in [09-deep-link-onboarding.md](09-deep-link-onboarding.md#saving-the-details).

### Onboarding links

To check the deep link on a connected phone, run `./tool/deeplink.sh --check`. It uses `notes://onboarding`, a link that only debug builds register.

The real entry is a Play Store link with `referrer=flow%3Donboarding`, which works only for installs through Play. There is also a direct HTTPS link that needs a one-time device command. All three are in [09-deep-link-onboarding.md](09-deep-link-onboarding.md).

## Dependency rules

- **Bump the three FlutterFire packages together.** `firebase_core`, `firebase_auth` and `cloud_firestore` are pinned to exact versions. Each ships an iOS Swift package that pins the Firebase iOS SDK to an exact version, and all three must agree or Swift Package Manager cannot resolve.
- **Keep `google_sign_in_android` at 7.2.12 or later.** Earlier versions fail to compile under Kotlin Gradle Plugin 2.4.0.
- **Keep `google_sign_in_ios` at 6.3.0 or later.** Earlier versions do not handle the OAuth redirect under UIScene.

## Troubleshooting

### Gradle wrapper: `java.net.ConnectException: Operation timed out`

Seen on 2026-10-01 during `flutter run`. The wrapper could not download `gradle-9.3.1-all.zip`.

**Cause:** the download redirects to `release-assets.githubusercontent.com`. One of that host's four IP addresses (`185.199.109.133`) was unreachable from the developer's network, and the wrapper's Java downloader tries only the first address it gets.

**Fix:** download the file with curl, which retries across addresses, check it, and put it in the wrapper cache.

```sh
cd /tmp
curl -L --fail --retry 5 --retry-all-errors -O \
  https://services.gradle.org/distributions/gradle-9.3.1-all.zip
curl -L https://services.gradle.org/distributions/gradle-9.3.1-all.zip.sha256   # compare with:
shasum -a 256 gradle-9.3.1-all.zip
```

Then move the zip into the folder the wrapper created, next to the `.lck` file, and delete the empty `.part` file:

```
~/.gradle/wrapper/dists/gradle-9.3.1-all/<hash>/gradle-9.3.1-all.zip
```

The same failure can return for a different Gradle version. Retrying, switching network, or repeating these steps all work.

### The direct onboarding link opens the browser, not the app

The domain is not verified for the app. Approve it on the device with the command in [09-deep-link-onboarding.md](09-deep-link-onboarding.md#android).

### "We couldn't save your details"

The Supabase insert failed. In a debug build the cause is logged with the tag `[leads]`. Usual causes: no network, wrong URL or key, the `onboarding_leads` table or its insert policy missing, or a value breaking a column check. In a release build, it also appears when the build was made without the two `--dart-define` flags.

### Installing from the Play link does not start onboarding

The referrer only exists for installs made through Play. `adb install` and `flutter run` always report an organic install. Also check the link carries `referrer=flow%3Donboarding`, and that the app was not already installed.

### The app is stuck in the onboarding interface

That is by design once the link has been opened. In a debug build, finish the flow and tap "Reset deep-link flow". Otherwise clear the app's data: `adb shell pm clear com.spacewire.notes`.

### Google asks for a lock screen during sign-in

A managed (work) Google account can require a device lock screen before it may be used. That is the organisation's policy, not an app fault. Use a personal test account, or set the lock screen.

### Sign-in does nothing or is "cancelled"

The debug SHA-1 is not registered. See [Android signing certificate](#android-signing-certificate).

### "You do not have permission to do that"

Either the published Firestore rules differ from [firestore.rules](../firestore.rules), or the write breaks a rule. See [04-data-model.md](04-data-model.md#security-rules).

### Build warnings that are expected

- `firebase_auth` and `firebase_core` "apply Kotlin Gradle Plugin". Not blocking today; a future Flutter version will fail on it, so upgrade the plugins when versions with Built-in Kotlin exist.
- `java.lang.System::load` restricted-method warnings come from Gradle running on JDK 25.

### `flutter doctor` findings on the dev machine (2026-10-01)

- Android `cmdline-tools` is missing and licences are unconfirmed. This did not block the build.
- CocoaPods is not installed. The iOS project uses Swift Package Manager; an iOS build has not been attempted.
