import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load values from local.properties
val localProperties = Properties().apply {
    val localFile = rootProject.file("local.properties")
    if (localFile.exists()) {
        localFile.inputStream().use { load(it) }
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toInt() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
// force new minsdk/targetsdk if not set
val flutterMinSdk = localProperties.getProperty("flutter.minSdkVersion")?.toInt() ?: 24
val flutterTargetSdk = localProperties.getProperty("flutter.targetSdkVersion")?.toInt() ?: 36
val flutterCompileSdk = localProperties.getProperty("flutter.compileSdkVersion")?.toInt() ?: 36

android {
    namespace = "com.example.aqmapp"
    compileSdk = flutterCompileSdk
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.aqmapp"
        minSdk =   flutterMinSdk// ✅ FIXED
        targetSdk = flutterTargetSdk
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
