plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

android {
    namespace = "com.creadix.xannhael"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.creadix.xannhael"
        minSdk = 28
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        debug {
            // Android emulator reaches the Rails host on the host machine via 10.0.2.2.
            buildConfigField("String", "BASE_URL", "\"http://10.0.2.2:3000\"")
        }
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // ponytail: placeholder host, not a real domain. Set the real production
            // HTTPS host here before shipping a release build.
            buildConfigField("String", "BASE_URL", "\"https://xannhael.example.com\"")
        }
    }

    buildFeatures {
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.activity)
    implementation(libs.androidx.constraintlayout)
    implementation(libs.hotwire.core)
    implementation(libs.hotwire.navigation.fragments)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
}