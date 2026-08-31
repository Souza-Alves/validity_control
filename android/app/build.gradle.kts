import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Detecta a flag `--dart-define=DEV_MODE=true` para gerar um app separado
// (applicationId + nome diferentes), permitindo instalar dev e producao juntos.
val isDevMode: Boolean = run {
    val raw = (project.findProperty("dart-defines") as String?) ?: ""
    raw.split(",").filter { it.isNotEmpty() }.any {
        runCatching { String(Base64.getDecoder().decode(it)) }
            .getOrDefault("") == "DEV_MODE=true"
    }
}

android {
    namespace = "com.controlevalidades.controle_validades"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

gradle.projectsEvaluated {
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:none", "-nowarn"))
    }
}
    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.controlevalidades.controle_validades"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Em modo dev: applicationId e nome diferentes para conviver com o app
        // de producao no mesmo device.
        if (isDevMode) {
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Validades DEV")
        } else {
            resValue("string", "app_name", "Controle de Validades")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Ofusca e remove codigo nativo (Kotlin/Java) nao usado no release,
            // dificultando a engenharia reversa.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
gradle.projectsEvaluated {
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:none", "-nowarn"))
    }
}