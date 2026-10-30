plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.roborazzi)
}

// Read upload credentials from the environment; never commit keystores or passwords.
val uploadSigning = listOf("COOKBOOK_KEYSTORE_PATH", "COOKBOOK_KEYSTORE_PASSWORD",
    "COOKBOOK_KEY_ALIAS", "COOKBOOK_KEY_PASSWORD").associateWith {
    providers.environmentVariable(it).orNull
}
val hasUploadSigning = uploadSigning.values.all { !it.isNullOrBlank() }

android {
    namespace = "com.jackabee.mealie"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.jackabee.mealie"
        minSdk = 26
        targetSdk = 36
        versionCode = 24
        versionName = "1.1.21"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (hasUploadSigning) {
            create("upload") {
                storeFile = file(uploadSigning.getValue("COOKBOOK_KEYSTORE_PATH")!!)
                storePassword = uploadSigning.getValue("COOKBOOK_KEYSTORE_PASSWORD")
                keyAlias = uploadSigning.getValue("COOKBOOK_KEY_ALIAS")
                keyPassword = uploadSigning.getValue("COOKBOOK_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (hasUploadSigning) signingConfig = signingConfigs.getByName("upload")
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    testOptions {
        unitTests {
            // Needed by Robolectric so screenshot tests can inflate real
            // resources/themes. The existing plain-JUnit tests are unaffected.
            isIncludeAndroidResources = true
        }
    }
}

// Screenshot tests are debug-only: they need the ComponentActivity from
// androidx.compose.ui:ui-test-manifest (a debugImplementation dependency) and
// are driven by the recordRoborazziDebug / verifyRoborazziDebug tasks. Keep
// them out of the release unit-test variant so plain `gradlew test` stays green.
tasks.withType<Test>().configureEach {
    if (name == "testReleaseUnitTest") {
        exclude("**/screenshots/**")
    }
}

roborazzi {
    // Golden screenshots live in the source tree so they get committed.
    // The plugin registers this dir as a test-task input/output, so
    // changed goldens correctly re-trigger verifyRoborazziDebug.
    outputDir.set(layout.projectDirectory.dir("src/test/roborazzi"))
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.material3.adaptive)
    implementation(libs.androidx.material3.adaptive.layout)
    implementation(libs.androidx.material3.adaptive.navigation)
    implementation(libs.androidx.material3.adaptive.navigation.suite)
    implementation(libs.androidx.navigation.compose)
    debugImplementation(libs.androidx.compose.ui.tooling)

    implementation(libs.material)

    implementation(libs.retrofit)
    implementation(libs.retrofit.converter.kotlinx.serialization)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)

    implementation(libs.coil.compose)
    implementation(libs.androidx.datastore.preferences)

    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.androidx.arch.core.testing)

    // JVM screenshot tests (Roborazzi + Robolectric, no emulator required)
    testImplementation(platform(libs.androidx.compose.bom))
    testImplementation(libs.androidx.compose.ui.test.junit4)
    testImplementation(libs.robolectric)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
    // Provides the ComponentActivity used by createComposeRule()
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}

// Unit tests and debug builds need no upload key. Public release artifacts do.
val missingUploadVariables = uploadSigning.filterValues { it.isNullOrBlank() }.keys.toList()
abstract class ValidateCookbookUploadSigning : DefaultTask() {
    @get:Input
    abstract val missingVariables: ListProperty<String>

    @TaskAction
    fun validate() {
        val missing = missingVariables.get()
        check(missing.isEmpty()) {
            "Release signing is not configured. Set: ${missing.joinToString()}. See docs/ANDROID_RELEASE.md."
        }
    }
}
val validateUploadSigning = tasks.register<ValidateCookbookUploadSigning>("validateUploadSigning") {
    missingVariables.set(missingUploadVariables)
}
tasks.matching { it.name == "bundleRelease" || it.name == "assembleRelease" }.configureEach {
    dependsOn(validateUploadSigning)
}
