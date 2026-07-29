plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_bnx_mail"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_bnx_mail"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            isZipAlignEnabled = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

tasks.register<Copy>("copyLogo") {
    from("C:/Users/RAVI KUMAR C/.gemini/antigravity-ide/brain/ffc2f011-4ab5-4123-997d-5ff6094d169a/media__1782899402953.jpg")
    into("../../assets")
    rename { "logo.jpg" }
}

tasks.named("preBuild") {
    dependsOn("copyLogo")
}

tasks.configureEach {
    if (name.startsWith("compileFlutterBuild")) {
        dependsOn("copyLogo")
    }
}
