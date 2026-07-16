plugins {
    id("com.google.gms.google-services") version "4.5.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // Force plugin subprojects (file_picker, package_info_plus, etc.) to
    // compile against SDK 36. Flutter 3.44's flutter.compileSdkVersion is 34,
    // but some transitive plugins now require 36 or later. Registered before
    // evaluationDependsOn(":app") below, which eagerly evaluates projects.
    val forceCompileSdk: Project.() -> Unit = {
        extensions.findByType(com.android.build.api.dsl.CommonExtension::class.java)?.let { ext ->
            if ((ext.compileSdk ?: 0) < 36) {
                ext.compileSdk = 36
            }
            if (ext.namespace == null) {
                ext.namespace = project.group.toString()
            }
        }
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
