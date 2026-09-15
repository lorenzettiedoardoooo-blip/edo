import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}
val keyProperties = Properties()
val keyFile = rootProject.file("key.properties")
if (keyFile.exists()) keyFile.inputStream().use { keyProperties.load(it) }
android {
    namespace = "it.yokai.yokai_workout_creator"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "it.yokai.yokai_workout_creator"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (keyFile.exists()) create("personalRelease") {
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            storeFile = file(keyProperties.getProperty("storeFile"))
            storePassword = keyProperties.getProperty("storePassword")
        }
    }
    buildTypes {
        release {
            // Personal sideload builds work immediately. Add key.properties to
            // use your persistent private release key for future updates.
            signingConfig = signingConfigs.getByName(if (keyFile.exists()) "personalRelease" else "debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}
flutter { source = "../.." }
