pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 8.7 + Kotlin 1.9.22 — chosen because the USB serial
    // plugins we depend on (flutter_libserialport 0.6.0) use
    // older classpath setups and do NOT declare the
    // com.android.library plugin required by AGP 9's strict
    // evaluation. AGP 8.7 is the latest version that works
    // without patching the plugin's build.gradle at runtime.
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

include(":app")
