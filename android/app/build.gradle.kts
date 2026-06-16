import java.io.FileInputStream
import java.util.Properties
import com.android.build.api.variant.FilterConfiguration.FilterType.*
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader(Charsets.UTF_8).use { reader ->
        localProperties.load(reader)
    }
}

var flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
var flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val keystorePropertiesExists = keystorePropertiesFile.exists()
if (keystorePropertiesExists) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "dev.imranr.obtainium"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        applicationId = "dev.bikram.obtainx"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    flavorDimensions += "default"

    productFlavors {
        create("normal") {
            dimension = "default"
            applicationIdSuffix = ""
        }
        create("fdroid") {
            dimension = "default"
            // Intentionally NO applicationIdSuffix: the F-Droid build shares the
            // GitHub build's applicationId (dev.bikram.obtainx) and signing key so
            // updates cross between channels seamlessly. This relies on F-Droid
            // publishing OUR signed APK via the reproducible-build path (Builds.binary
            // in the fdroiddata recipe) — do NOT re-add a suffix. The flavor still
            // exists only to run lib/main_fdroid.dart, which disables self-updating
            // (F-Droid policy: the store updates the app, it must not update itself).
            applicationIdSuffix = ""
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            val releaseSigningConfig = signingConfigs.getByName("release")
            signingConfig = if (keystorePropertiesExists && releaseSigningConfig.storeFile != null) {
                releaseSigningConfig
            } else {
                if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
                    logger.error(
                        """
                            WARNING: You are trying to create a release build, but a key.properties file was not found.
                                     You will need to sign the APKs separately.

                            To sign a release build automatically, a keystore properties file is required.

                            The following is an example configuration.
                            Create a file named [project]/android/key.properties that contains a reference to your keystore.
                            Don't include the angle brackets (< >). They indicate that the text serves as a placeholder for your values.

                            storePassword=<keystore password>
                            keyPassword=<key password>
                            keyAlias=<key alias>
                            storeFile=<keystore file location>

                            For more info, see:
                            * https://docs.flutter.dev/deployment/android#sign-the-app
                        """.trimIndent()
                    )
                }
                null
            }
        }
        getByName("debug") {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }
}

// Per-ABI versionCode = base * 10 + abi-suffix. Both the GitHub split builds and
// the F-Droid split builds use this same scheme, so each ABI's APK carries one
// versionCode across both channels (base 3800 -> x86_64 38001, armeabi-v7a 38002,
// arm64-v8a 38003) and installs are interchangeable per architecture. The *10
// multiplier keeps codes in the established 5-digit range so users already on the
// GitHub builds are never downgraded. The fdroiddata recipe reproduces these codes
// for auto-update via a VercodeOperation list (%c*10+1 / +2 / +3) — one entry per
// ABI — so F-Droid auto-detects and builds all three on each release.
val abiCodes = mapOf("x86_64" to 1, "armeabi-v7a" to 2, "arm64-v8a" to 3)

android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
        }
    }
}


dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
