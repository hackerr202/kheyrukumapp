import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (isReleaseBuildRequested) {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties for release build. " +
                "Configure ANDROID_KEYSTORE_BASE64, KEY_ALIAS, STORE_PASSWORD, and KEY_PASSWORD."
        )
    }
    val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missingKeys = requiredKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missingKeys.isNotEmpty()) {
        throw GradleException("Missing release signing keys in android/key.properties: $missingKeys")
    }
    val storePath = keystoreProperties.getProperty("storeFile")
    if (!project.file(storePath).exists()) {
        throw GradleException("Release keystore file not found at android/app/$storePath")
    }
}

android {
    namespace = "com.kheyrukum.portal"
    compileSdk = 36
    ndkVersion = "27.3.13750724"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.kheyrukum.portal"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storePath = keystoreProperties.getProperty("storeFile")
                if (!storePath.isNullOrBlank()) {
                    storeFile = project.file(storePath)
                }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
