plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.spacewire.notes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.spacewire.notes"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Used directly by MainActivity.kt to read the Play Store install referrer.
    implementation("com.android.installreferrer:installreferrer:2.2")
    // Used directly by the analytics/ package, over a method channel, rather
    // than through two Flutter plugins. Keys: res/values/analytics_keys.xml.
    implementation("com.mixpanel.android:mixpanel-android:8.2.4")
    implementation("com.facebook.android:facebook-core:18.3.0")
    // Cashfree UPI AutoPay, used directly by the payments/ package over a
    // method channel. The same version as the CashAlert app.
    implementation("com.cashfree.pg:api:2.4.0")
    implementation("com.cashfree.pg:core:2.4.0")
    implementation("com.cashfree.pg:ui:2.4.0")
}
