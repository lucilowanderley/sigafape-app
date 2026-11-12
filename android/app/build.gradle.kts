import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura do .apk: android/key.properties + o arquivo .jks (nunca no GitHub).
val keyProps = Properties().also { p ->
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { p.load(it) }
}

android {
    namespace = "br.gov.rn.pm.sigafape.sigafape_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.gov.rn.pm.sigafape.app"
        // Android 6.0 (API 23): o mínimo aceito pelo Flutter atual (decisão de 2026-10-30)
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Assinatura do .apk: android/key.properties + o arquivo .jks (nunca no GitHub).
    // No GitHub Actions eles são criados a partir dos segredos do repositório. Sem eles, usa a chave de depuração.
    signingConfigs {
        if (keyProps.isNotEmpty()) {
            create("release") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyProps.isNotEmpty()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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

dependencies {
    // FileProvider, para abrir os anexos dos alertas em outro app
    implementation("androidx.core:core:1.13.1")
    // Conferência de novas notificações em segundo plano (a cada 15 min, mesmo com o app fechado)
    implementation("androidx.work:work-runtime:2.9.1")
    // Leitor de QR do Google Play Services (conferir assinatura): não pede permissão de câmera ao app
    implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
    // Orientação das fotos da ocorrência (Android 6.0 não lê EXIF de stream sem isto)
    implementation("androidx.exifinterface:exifinterface:1.3.7")
}
