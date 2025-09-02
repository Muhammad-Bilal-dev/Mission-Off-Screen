// Top-level build file where you can add configuration options common to all sub-projects/modules.
import org.gradle.api.JavaVersion // Ensure this import is at the very top

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin
        classpath("com.android.tools.build:gradle:8.2.2")
        // Google Services plugin for Firebase
        classpath("com.google.gms:google-services:4.4.2")
        // Kotlin Gradle Plugin
        classpath(kotlin("gradle-plugin", version = "1.8.20"))
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    afterEvaluate {
        // Attempt to configure Android library subprojects directly
        project.plugins.withId("com.android.library") {
            project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11 // CORRECTED: Was VERSION_1_11
                    targetCompatibility = JavaVersion.VERSION_11 // CORRECTED: Was VERSION_1_11
                }
            }
        }

        // Fallback: Also configure JavaCompile tasks directly.
        // This ensures if a module has Java code but isn't an Android library (less common for Flutter plugins)
        // or if the above doesn't catch it, we still try to set it.
        project.tasks.withType(JavaCompile::class.java).configureEach {
            sourceCompatibility = "11"
            targetCompatibility = "11"
        }

        // Configure Kotlin for all subprojects
        project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            kotlinOptions {
                jvmTarget = "11"
            }
        }
    }
}

// Your existing project structure configurations:
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDirValue: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDirValue)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

