import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing material lives outside version control (see .gitignore). Locally
// that is android/key.properties + the .jks it points at; in CI the workflow writes
// both from repository secrets before invoking Gradle. When the file is absent we
// fall back to debug signing so a fresh clone can still run `flutter run --release`.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseSigning = keystorePropertiesFile.exists()

android {
    namespace = "com.example.secondary_sales"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.secondary_sales"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // The firebase_app_distribution plugin ships two variants: its default
        // ("production") pulls only firebase-appdistribution-api, a no-op stub, while
        // "staging" pulls the full firebase-appdistribution implementation that can
        // actually check for, download and install a new build. This app declares no
        // flavors of its own, so without an explicit strategy Gradle picks the stub and
        // updateIfNewReleaseAvailable() silently does nothing.
        //
        // NOTE: the full SDK contains self-update code that Google Play considers a
        // policy violation. This is safe here because the app is distributed only via
        // Firebase App Distribution. If it is ever published to Play, switch this to
        // "production" for the Play build.
        missingDimensionStrategy("default", "staging")

        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a"))
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            // Every CI run must produce an APK signed with the same key, otherwise
            // Android refuses to install it over the previous build and testers are
            // forced to uninstall before each update.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
}

val copySplitApksWithPrefix = tasks.register("copySplitApksWithPrefix") {
    doLast {
        val flutterApkDir = project.layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        if (flutterApkDir.exists()) {
            val v8a = File(flutterApkDir, "app-arm64-v8a-release.apk")
            val v7a = File(flutterApkDir, "app-armeabi-v7a-release.apk")

            if (v8a.exists()) {
                v8a.copyTo(File(flutterApkDir, "GDFL_64bit.apk"), overwrite = true)
                v8a.copyTo(rootProject.file("GDFL_64bit.apk"), overwrite = true)
            }
            if (v7a.exists()) {
                v7a.copyTo(File(flutterApkDir, "GDFL_32bit.apk"), overwrite = true)
                v7a.copyTo(rootProject.file("GDFL_32bit.apk"), overwrite = true)
            }
        }
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(copySplitApksWithPrefix)
}
