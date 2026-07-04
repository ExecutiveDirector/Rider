import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // FIX: was missing — this is what actually reads google-services.json
    // and generates the Firebase config Android needs at build time.
    // Version is pulled from the classpath declared in the root
    // android/build.gradle.kts (matches vendor app's setup exactly).
    id("com.google.gms.google-services")
}

// ── Release signing ──────────────────────────────────────────────────────
// Mirrors the vendor app's setup, with one difference: vendor commits its
// key.properties + .jks directly into the repo (works, but means the
// signing password sits in plaintext in git history forever). Here,
// key.properties and the .jks are expected to be written to disk by CI
// (see .github/workflows/firebase-distribute.yml) — reconstructed from
// GitHub secrets right before this file is evaluated — or dropped in
// locally by hand for local release builds. Neither file is committed;
// both are already covered by .gitignore. If neither exists (e.g. a
// contributor's first local checkout with no secrets configured), this
// falls back to debug signing so `flutter build apk --release` still
// works rather than hard-failing.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()

if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use {
        keystoreProperties.load(it)
    }
}

android {
    namespace = "com.example.aquagasrider"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.aquagasrider"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(
                    keystoreProperties["storeFile"] as String
                )
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}