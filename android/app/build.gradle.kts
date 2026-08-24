import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Đọc khoá ký release. FAIL LỚN nếu thiếu — KHÔNG rơi về debug signing (D3) ──
// Debug key đổi là người dùng mất sạch dữ liệu; im lặng rơi về debug là bẫy chết người.
val keyProps = Properties()
val keyPropsFile = rootProject.file("key.properties")
val hasReleaseKey = keyPropsFile.exists()
if (hasReleaseKey) {
    keyProps.load(FileInputStream(keyPropsFile))
}

android {
    namespace = "dev.tony.tonyfino"
    // compileSdk 37: flutter_secure_storage 11 yêu cầu. targetSdk vẫn 36 (bản đã test).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Phase 12: `flutter_local_notifications` đòi desugaring core library
        // (dùng java.time API trên minSdk 24, dưới API 26 gốc không có).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "dev.tony.tonyfino"   // BẤT BIẾN trọn đời app (D1)
        minSdk = 24
        targetSdk = 36                         // Play yêu cầu ≥36; đây là bản emulator đã test
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
                storeFile = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // Bản debug là PACKAGE RIÊNG — không bao giờ đụng dữ liệu thật (D1)
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "TonyFino (dev)")
        }
        getByName("release") {
            resValue("string", "app_name", "TonyFino")
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // KHÔNG rơi về debug. Fail lớn để không bao giờ ship APK ký sai khoá.
                throw GradleException(
                    "Thiếu android/key.properties — không thể ký bản release.\n" +
                    "Xem docs/decisions.md § D3. KHÔNG rơi về debug signing vì debug key\n" +
                    "đổi là người dùng mất sạch dữ liệu (phải gỡ cài để cài đè khác khoá)."
                )
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Cặp với `isCoreLibraryDesugaringEnabled` ở trên.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
