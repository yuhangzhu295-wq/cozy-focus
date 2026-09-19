import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
if (releasePropertiesFile.isFile) {
    releasePropertiesFile.inputStream().use { input ->
        releaseProperties.load(input)
    }
}

val releaseStoreFile = releaseProperties.getProperty("storeFile")
val hasReleaseSigning = releaseStoreFile != null &&
    releaseProperties.getProperty("storePassword") != null &&
    releaseProperties.getProperty("keyAlias") != null &&
    releaseProperties.getProperty("keyPassword") != null &&
    rootProject.file(releaseStoreFile).isFile

android {
    namespace = "com.example.cozy_focus_app"
    compileSdk = flutter.compileSdkVersion
    // Use the highest NDK version required by any plugin (backward compatible)
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Required by flutter_local_notifications (Java 8 desugaring)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.cozy_focus_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Debug signing enables local build verification only; it is not
            // production/store signing when android/key.properties is absent.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // Required for flutter_local_notifications Java 8 API desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
