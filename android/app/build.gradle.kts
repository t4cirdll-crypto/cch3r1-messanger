import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional release signing: provide `android/key.properties` with
//   storeFile=...  storePassword=...  keyAlias=...  keyPassword=...
// (the file is .gitignored). On CI, the android-apk.yml workflow writes one
// from the ANDROID_KEYSTORE_BASE64 / ANDROID_KEYSTORE_PASSWORD / etc. secrets
// before the build. If the file is absent, release falls back to the debug
// signing config so `flutter build apk --release` still works locally.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        load(FileInputStream(f))
    }
}

android {
    namespace = "com.cchr.cch3r1_messanger"
    compileSdk = flutter.compileSdkVersion
    // Явная версия NDK — flutter_local_notifications / just_audio / record /
    // gal / image_picker / video_player / permission_handler / sqflite требуют
    // 27.0.12077973. Иначе Gradle warning'ит и перерасходует время на re-resolve.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications требует core library desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.cchr.cch3r1_messanger"
        // record_android 5.2.1 и ряд других плагинов требуют minSdk 23+.
        // flutter.minSdkVersion в 3.29.x тянет 21 — поэтому фиксируем явно,
        // иначе манифест-merge падает с "minSdkVersion 21 cannot be smaller
        // than version 23 declared in library [:record_android]".
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                val storeFilePath = keystoreProperties["storeFile"] as String?
                if (storeFilePath != null) {
                    storeFile = file(storeFilePath)
                    storePassword = keystoreProperties["storePassword"] as String?
                    keyAlias = keystoreProperties["keyAlias"] as String?
                    keyPassword = keystoreProperties["keyPassword"] as String?
                }
            }
        }
    }

    buildTypes {
        release {
            // Если в android/key.properties есть keystore — подписываем релиз
            // им (для CI / публикации в Google Play). Иначе — debug-ключ,
            // чтобы `flutter build apk --release` работал локально из коробки.
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
