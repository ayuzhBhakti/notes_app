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

- The `google-services` Gradle plugin is not applied. [android/app/google-services.json](../android/app/google-services.json) is in the repository but the build does not read it. It still describes the old package `com.spacewire.notes`; replace it once Firebase has the new one.
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

Release builds are signed with the upload key; see [Release signing](#release-signing). Its SHA-1, and the Play app-signing key's SHA-1 once Play has one, must be added too, or sign-in fails in release and Play-installed builds.

### Release signing

Release builds (`flutter build appbundle` for Play, `flutter build apk`) are signed with the upload key, created 2026-10-21:

| | |
|---|---|
| Keystore | `android/app/upload-keystore.jks` (PKCS12, RSA 4096, valid until 2054) |
| Alias | `admin` |
| Passwords | `android/key.properties` (one password, chosen by the owner, for store and key) |
| Owner | `CN=Spacewire, O=Spacewire, L=India, C=IN` |
| SHA-1 | `42:4C:E4:C7:14:C6:F8:DD:2B:E0:B3:B5:12:16:86:78:CC:C0:D7:60` |
| SHA-256 | `C3:40:52:4B:EB:71:07:05:F5:4C:D7:BA:CD:0E:E9:B2:2A:6E:B5:4A:B0:4C:2B:61:4A:AF:69:10:89:83:87:10` |

Both files are gitignored and exist only on this machine. **Back them up together somewhere safe** (a password manager). Every update to the Play listing must be signed with this key; with Play App Signing a lost upload key can be reset through Play support, but that takes days.

[build.gradle.kts](../android/app/build.gradle.kts) reads `key.properties`. Without that file a release build is signed with the debug key and Gradle logs a warning; Play rejects such a bundle. To use the key on another machine, copy both files into the same places.

Check which key signed a build:

```sh
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep SHA1
```

### Supabase

The onboarding interface signs in, reads its settings and takes payment through Supabase. The Evos project (`sqvlgiqypqvjykczuhgz`) is the default in [supabase_options.dart](../lib/supabase_options.dart), so a plain build uses it. Its backend is not set up yet, so "Send code" fails on such a build. For test mode (no SMS, the code is `123456`, simulated payment) switch the backend off in a debug build with `flutter run --dart-define=SUPABASE_URL=`. To use another project:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

The same two flags go on `flutter build`. Creating and filling the project is in [09-deep-link-onboarding.md](09-deep-link-onboarding.md#setting-up-the-backend).

### Analytics keys

Mixpanel and the Facebook SDK stay off until their keys replace the placeholders in [analytics_keys.xml](../android/app/src/main/res/values/analytics_keys.xml). Where to find each key, and what a build without them does, is in [10-analytics.md](10-analytics.md#configuration).

### Onboarding links

To check the deep link on a connected phone, run `./tool/deeplink.sh --check`. It uses `notes://onboarding`, a link that only debug builds register.

The real entry is a Play Store link with `referrer=flow%3Donboarding`, which works only for installs through Play. There is also a direct HTTPS link that needs a one-time device command. All three are in [09-deep-link-onboarding.md](09-deep-link-onboarding.md).

## Website upload (Hostinger)

The public website in `website/` is uploaded by hand to Hostinger, whose CDN sits in front (response header `server: hcdn`). It has not been uploaded yet.

**After changing a CSS or JS file, change the `?v=` value in every page, because Hostinger's CDN keeps serving its cached copy otherwise. Purging in hPanel (Websites -> CDN -> Purge all) also works.** The CDN keeps one copy per compression method, and the Brotli copy that Chrome, Edge and Safari get can stay old after an upload, so pages arrive with stale styling. HTML pages are not cached. Every page loads `css/styles.css?v=20261019`; use today's date (`YYYYMMDD`), one value for the whole site. Replace it in all pages at once with `sed -i '' -E 's/\?v=[0-9]+"/?v=<new date>"/' website/*.html`. Never rename the files instead. The JavaScript is inline in each page, so there is no `.js` file to tag.

`website/.htaccess` sends `www.` to the bare domain and shows `404.html` for missing pages. It has no HTTP-to-HTTPS rule on purpose: Hostinger forces HTTPS itself, and a second rule can loop. Its name starts with a dot, so Finder hides it: check it is in every upload. `404.html` has `<base href="/">`, so it is styled at any address on the server but unstyled when opened from disk.

After an upload, check that the CDN serves the new files:

```sh
DOMAIN=example.com
for f in index.html "css/styles.css?v=20261019"; do
  curl -s -A "Mozilla/5.0 Chrome/141" -H "Accept-Encoding: gzip, deflate, br, zstd" -D - -o /dev/null "https://$DOMAIN/$f" \
    | grep -iE '^(last-modified|x-hcdn-cache-status)' | tr '\n' ' '; echo " <- $f"
done
```

Good: every `last-modified` date is the upload date. A file with an older date and `x-hcdn-cache-status: HIT` is a stale CDN copy: change the `?v=` value and upload the HTML again, or purge the CDN.

## Dependency rules

- **Bump the three FlutterFire packages together.** `firebase_core`, `firebase_auth` and `cloud_firestore` are pinned to exact versions. Each ships an iOS Swift package that pins the Firebase iOS SDK to an exact version, and all three must agree or Swift Package Manager cannot resolve.
- **Keep `google_sign_in_android` at 7.2.12 or later.** Earlier versions fail to compile under Kotlin Gradle Plugin 2.4.0.
- **Mixpanel and the Facebook SDK are Gradle dependencies, not pub packages.** They are in [android/app/build.gradle.kts](../android/app/build.gradle.kts) and used from Kotlin. Do not add `mixpanel_flutter` or `facebook_app_events` beside them.
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

### App bundle: `Release app bundle failed to strip debug symbols from native libraries`

Seen on 2026-10-21 with `flutter build appbundle`. **Cause:** Flutter checks the bundle with a tool from the Android SDK command-line tools, which are not installed (`flutter doctor` shows `cmdline-tools component is missing`). The `.aab` is still written and signed, but the command reports failure. **Fix:** Android Studio → Settings → Languages & Frameworks → Android SDK → SDK Tools → tick *Android SDK Command-line Tools (latest)* → Apply, then `flutter doctor --android-licenses`.

### Release build: `Dart snapshot generator failed with exit code -9`

Seen on 2026-10-05 during `flutter build apk`, together with `Failed to find ".../android-x64-release/darwin-x64/gen_snapshot"`. Debug builds were unaffected because they do not use `gen_snapshot`.

**Cause:** the Flutter SDK on this machine was unpacked from a zip downloaded with Safari, so every file in it, including the bundled engine cache, carries the `com.apple.quarantine` attribute. macOS killed the quarantined release `gen_snapshot` binaries (exit code -9 is SIGKILL) and they were gone from the three `android-*-release/darwin-x64` folders afterwards. Flutter did not download them again because the folders still existed.

**Fix:** delete the gutted folders and let Flutter fetch them again. Files Flutter downloads itself are not quarantined.

```sh
E=~/flutter/bin/cache/artifacts/engine
rm -r $E/android-arm-release/darwin-x64 $E/android-arm64-release/darwin-x64 $E/android-x64-release/darwin-x64
flutter precache --android
```

The `android-*-profile` binaries are still the quarantined originals. If `flutter build apk --profile` fails the same way, do the same for the `-profile` folders.

### The direct onboarding link opens the browser, not the app

The domain is not verified for the app. Approve it on the device with the command in [09-deep-link-onboarding.md](09-deep-link-onboarding.md#android).

### "Something went wrong on our side" on the mobile-number screen

Supabase refused the request, or a release build was made with the backend switched off: in a debug build the cause is logged with the tag `[evos]`. Usual causes: phone sign-in not enabled, the SMS hook not set or failing, or the Fast2SMS secrets missing.

### Installing from the Play link does not start onboarding

The referrer only exists for installs made through Play. `adb install` and `flutter run` always report an organic install. Also check the link carries `referrer=flow%3Donboarding`, and that the app was not already installed.

### The app is stuck in the onboarding interface

That is by design once the link has been opened, in every build: no screen offers a way back. Clear the app's data (or `./tool/deeplink.sh --reset`): `adb shell pm clear com.spacewire.evos`.

### Google asks for a lock screen during sign-in

A managed (work) Google account can require a device lock screen before it may be used. That is the organisation's policy, not an app fault. Use a personal test account, or set the lock screen.

### Sign-in does nothing or is "cancelled"

The debug SHA-1 is not registered. See [Android signing certificate](#android-signing-certificate).

### "You do not have permission to do that"

Either the published Firestore rules differ from [firestore.rules](../firestore.rules), or the write breaks a rule. See [04-data-model.md](04-data-model.md#security-rules).

### Build warnings that are expected

- `firebase_auth` and `firebase_core` "apply Kotlin Gradle Plugin". Not blocking today; a future Flutter version will fail on it, so upgrade the plugins when versions with Built-in Kotlin exist.
- `java.lang.System::load` restricted-method warnings come from Gradle running on JDK 25.

### Logcat errors that are expected

`GraphRequest can't be used when Facebook SDK isn't fully initialized`, about five times. With placeholder keys it appears on every launch: the SDK refuses its own network calls because the app keeps it switched off. With real keys it appears only on the first launch after install or after clearing data, before `MetaSdk.kt` switches the SDK on; that switch is saved, so later launches start it fully. Checked 2026-10-21: the same first launch then sent the install to Facebook.

### `flutter doctor` findings on the dev machine (2026-10-01)

- Android `cmdline-tools` is missing and licences are unconfirmed. This did not block the build.
- CocoaPods is not installed. The iOS project uses Swift Package Manager; an iOS build has not been attempted.
