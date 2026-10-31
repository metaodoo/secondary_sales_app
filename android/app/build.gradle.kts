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

val copyReleaseApksWithNamingConventions = tasks.register("copyReleaseApksWithNamingConventions") {
    doLast {
        val flutterApkDir = project.layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        if (!flutterApkDir.exists()) return@doLast

        val flutterRootDir = rootProject.projectDir.parentFile ?: rootProject.projectDir
        val outputApkDir = File(flutterRootDir, "output/apk")
        outputApkDir.mkdirs()

        val vName = android.defaultConfig.versionName ?: flutter.versionName ?: "1.0.0"
        val vCode = android.defaultConfig.versionCode ?: flutter.versionCode ?: 1

        val universalApk = File(flutterApkDir, "app-release.apk")
        val v8aApk = File(flutterApkDir, "app-arm64-v8a-release.apk")
        val v7aApk = File(flutterApkDir, "app-armeabi-v7a-release.apk")

        fun copyToAll(src: File, standardName: String, cleanAlias: String, extraAliases: List<String> = emptyList()) {
            if (!src.exists()) return
            // 1. In Flutter APK build directory
            src.copyTo(File(flutterApkDir, standardName), overwrite = true)
            // 2. In project output/apk/
            src.copyTo(File(outputApkDir, standardName), overwrite = true)
            // 3. In project root and android root directories
            src.copyTo(File(flutterRootDir, cleanAlias), overwrite = true)
            src.copyTo(File(rootProject.projectDir, cleanAlias), overwrite = true)
            // 4. Any extra aliases
            for (alias in extraAliases) {
                src.copyTo(File(flutterApkDir, alias), overwrite = true)
                src.copyTo(File(outputApkDir, alias), overwrite = true)
                if (alias.endsWith(".apk") && !alias.contains("/")) {
                    src.copyTo(File(flutterRootDir, alias), overwrite = true)
                }
            }
        }

        // 1. Universal Fat APK (or dual ARM fat APK)
        copyToAll(
            universalApk,
            standardName = "Shokti+_v${vName}_Universal.apk",
            cleanAlias = "Shokti+_Universal.apk",
            extraAliases = listOf(
                "Shokti_Plus_v${vName}_Universal.apk",
                "Shokti+_v${vName}+${vCode}_Universal.apk",
                "GDFL_Secondary_Sales_v${vName}_Universal.apk"
            )
        )

        // 2. ARM 64-bit APK
        copyToAll(
            v8aApk,
            standardName = "Shokti+_v${vName}_arm64-v8a.apk",
            cleanAlias = "Shokti+_64bit.apk",
            extraAliases = listOf(
                "Shokti_Plus_v${vName}_arm64-v8a.apk",
                "Shokti+_v${vName}+${vCode}_arm64-v8a.apk",
                "GDFL_64bit.apk",
                "GDFL_Secondary_Sales_v${vName}_arm64-v8a.apk"
            )
        )

        // 3. ARM 32-bit APK
        copyToAll(
            v7aApk,
            standardName = "Shokti+_v${vName}_armeabi-v7a.apk",
            cleanAlias = "Shokti+_32bit.apk",
            extraAliases = listOf(
                "Shokti_Plus_v${vName}_armeabi-v7a.apk",
                "Shokti+_v${vName}+${vCode}_armeabi-v7a.apk",
                "GDFL_32bit.apk",
                "GDFL_Secondary_Sales_v${vName}_armeabi-v7a.apk"
            )
        )
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(copyReleaseApksWithNamingConventions)
}
