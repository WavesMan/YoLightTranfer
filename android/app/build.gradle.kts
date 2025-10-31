plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.tasks.Copy

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("app/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "cn.waveyo.yolighttransfer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11

        // 启用核心库反序列�?
        isCoreLibraryDesugaringEnabled = true
    }


    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cn.waveyo.yolighttransfer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29  // Android 10 - 仅支持Android 10及以�?
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "0.1.2"
        
//        ndk {
//            abiFilters.clear()
//            abiFilters.add("arm64-v8a")
//        }
    }

//    splits {
//        abi {
//            isEnable = true      // 开�?abi 拆分
//            reset()              // 清空默认列表
//            include("arm64-v8a") // 仅包�?arm64-v8a
//            isUniversalApk = false
//        }
//    }

    signingConfigs {
        create("release") {
            // 从key.properties读取配置
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file("nfdx_waveyo_key.jks")
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        getByName("release") {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    // 核心库反序列化依�?
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}

// 配置APK输出到Flutter期望的路�?
android.applicationVariants.all {
    val variant = this
    val variantName = variant.name.capitalize()

    // 在构建完成后复制APK文件到Flutter build目录
    val copyApkTask = tasks.register<Copy>("copy${variantName}ApkToFlutterBuild") {
        from(variant.outputs.map { it.outputFile })
        into("${project.rootDir}/../build/app/outputs/flutter-apk/")
        duplicatesStrategy = DuplicatesStrategy.EXCLUDE
        rename { fileName ->
            if (fileName.contains("app-")) {
                "app-debug.apk"
            } else {
                fileName
            }
        }

        // 确保在APK生成后执�?
        dependsOn(variant.assembleProvider)
    }

    // 将复制任务添加到构建流程�?
    variant.assembleProvider.configure {
        finalizedBy(copyApkTask)
    }
}






