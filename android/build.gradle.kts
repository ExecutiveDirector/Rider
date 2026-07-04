allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ── Firebase / google-services plugin ──────────────────────────────────────
// FIX: this block was entirely missing. Without it, google-services.json
// (even once present) is never read, com.google.gms.google-services can't
// be applied in app/build.gradle.kts, and Firebase.initializeApp() in
// main.dart fails silently (it's wrapped in try/catch — see the comment
// there: "push notifications disabled"). That means FCM has never
// actually been able to start on Android, regardless of anything on the
// Dart side. google-services.json (downloaded from Firebase Console) must
// be placed at android/app/google-services.json.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
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