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
    tasks.withType<JavaCompile> {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
}

subprojects {
    plugins.withId("com.android.library") {
        configureAndroidNamespace(project)
    }
    plugins.withId("com.android.application") {
        configureAndroidNamespace(project)
    }
}

fun configureAndroidNamespace(project: Project) {
    val android = project.extensions.findByName("android")
    if (android != null) {
        try {
            val getNamespace = android.javaClass.getMethod("getNamespace")
            val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
            if (getNamespace.invoke(android) == null) {
                setNamespace.invoke(android, "dev.isar.${project.name.replace("-", "_")}")
            }
        } catch (e: Exception) {
            // Ignore
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
