// Top-level build file where you can add configuration options common to all sub-projects/modules.

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin
        classpath("com.android.tools.build:gradle:8.12.0")
        // Google Services plugin for Firebase
        classpath("com.google.gms:google-services:4.4.2")
        // Kotlin Gradle Plugin
        classpath(kotlin("gradle-plugin", version = "1.8.20")) // Or a newer compatible version like "1.9.22"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Enforce Java 11 for Java compilation tasks
    // tasks.withType<JavaCompile>().configureEach {
    //     options.release.set(11) // Removed this problematic line
    // }

    // Enforce Java 11 for Kotlin compilation tasks
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "11"
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
