import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key for Play, read from android/key.properties (not in git; see
// docs/05-setup-and-build.md#release-signing). Without that file, release
// builds fall back to the debug key so they still build on other machines;
// Play rejects such a build, so nothing debug-signed can be published.
val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties: Properties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.spacewire.evos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.spacewire.evos"
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

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("android/key.properties not found: release build signed with the debug key.")
                signingConfigs.getByName("debug")
            }
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
