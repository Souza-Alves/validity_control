pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val propertiesFile = file("local.properties")
        if (propertiesFile.exists()) {
            propertiesFile.inputStream().use { stream: java.io.InputStream -> 
                properties.load(stream) 
            }
        }
        val sdkPath: String? = properties.getProperty("flutter.sdk")
        requireNotNull(sdkPath) { "flutter.sdk não encontrado no arquivo local.properties" }
        sdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://googleapis.com") }
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
     // Garante que o Gradle aceite os repositórios que acabamos de colocar dentro do app/build.gradle.kts
    repositoriesMode.set(org.gradle.api.initialization.resolve.RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()         
        mavenCentral()   
        maven { url = uri("https://googleapis.com") }
    }
}

plugins {
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false 
}

include(":app")