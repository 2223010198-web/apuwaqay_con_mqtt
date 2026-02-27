// android/app/build.gradle
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.apuwaqay.apu_waqay"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.apuwaqay.apu_waqay"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 1️⃣ Desugaring para compatibilidad con librerías Java 8+ en Androids antiguos
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // 2️⃣ Core KTX requerido para ContextCompat y validación robusta de permisos en SDK 36
    implementation("androidx.core:core-ktx:1.12.0")
}