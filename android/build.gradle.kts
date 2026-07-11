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
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureAndroid = { p: Project ->
        if (p.extensions.findByName("android") != null) {
            val android = p.extensions.getByName("android") as? com.android.build.gradle.BaseExtension
            android?.compileSdkVersion(36)
        }
    }
    if (state.executed) {
        configureAndroid(this)
    } else {
        afterEvaluate {
            configureAndroid(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
