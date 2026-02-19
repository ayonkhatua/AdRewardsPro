plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hypernest.adrewardspro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // 🔥 NAYA BLOCK: Ye GitHub ko batayega ki konsi key use karni hai
    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = "123456"
            keyAlias = "myalias"
            keyPassword = "123456"
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hypernest.adrewardspro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 🔥 NAYA BLOCK: Debug hata kar "release" set kar diya
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}