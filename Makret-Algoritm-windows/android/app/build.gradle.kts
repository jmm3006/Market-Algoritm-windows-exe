// C:\Users\jamsh\Desktop\For Python DJ\algoritm_app_market\android\app\build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.algoritm_app_market"
    compileSdk = flutter.compileSdkVersion

    // --- MANA BU QATORNI O'ZGARTIRING ---
    ndkVersion = "27.0.12077973" // <-- Talab qilingan NDK versiyasini to'g'ridan-to'g'ri belgilaymiz
    // --- YUQORIGA O'ZGARTIRING ---

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.algoritm_app_market"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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