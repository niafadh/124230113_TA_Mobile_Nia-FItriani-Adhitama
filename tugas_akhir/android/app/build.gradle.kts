plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin harus di bawah Android dan Kotlin plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.tugas_akhir"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Tambahkan ini agar mendukung desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.tugas_akhir" // sesuaikan package Anda
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        // jika butuh multiDex:
        // multiDexEnabled = true
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

dependencies {
    // Tambahkan ini ⬇️ agar desugaring aktif
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Dependency default Flutter tetap dipertahankan
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.23")
}
