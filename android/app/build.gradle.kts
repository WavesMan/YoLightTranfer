plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.waveyo.yolighttransfer_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        
        // ĺŻç¨ć ¸ĺżĺşĺĺşĺĺ?
        isCoreLibraryDesugaringEnabled = true
    }


    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.waveyo.yolighttransfer_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29  // Android 10 - 仅支持Android 10及以上
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "0.1.2"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ć ¸ĺżĺşĺĺşĺĺäžčľ?
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}

// 配置APK输出到Flutter期望的路径
android.applicationVariants.all {
    val variant = this
    val variantName = variant.name.capitalize()
    
    // 在构建完成后复制APK文件到Flutter build目录
    val copyApkTask = tasks.register<Copy>("copy${variantName}ApkToFlutterBuild") {
        from(variant.outputs.map { it.outputFile })
        into("${project.rootDir}/../build/app/outputs/flutter-apk/")
        rename { fileName ->
            if (fileName.contains("app-")) {
                "app-${variant.baseName}.apk"
            } else {
                fileName
            }
        }
        
        // 确保在APK生成后执行
        dependsOn(variant.assembleProvider)
    }
    
    // 将复制任务添加到构建流程中
    variant.assembleProvider.configure {
        finalizedBy(copyApkTask)
    }
}
