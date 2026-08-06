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
    fun configureJavaCompile(p: Project) {
        p.tasks.withType<JavaCompile> {
            sourceCompatibility = "17"
            targetCompatibility = "17"
            options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation"))
        }
    }

    if (state.executed) {
        configureJavaCompile(this)
    } else {
        afterEvaluate {
            configureJavaCompile(this)
        }
    }
}

subprojects {
    plugins.withId("com.android.library") {
        configureAndroidNamespace(project)
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                setCompileSdk.invoke(android, 36)
            } catch (e: Exception) {
                try {
                    val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    setCompileSdkVersion.invoke(android, 36)
                } catch (e2: Exception) {
                    // Ignore
                }
            }
        }
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

subprojects {
    fun configureProject(p: Project) {
        val android = p.extensions.findByName("android")
        if (android != null) {
            try {
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                setCompileSdk.invoke(android, 36)
            } catch (e: Exception) {
                try {
                    val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    setCompileSdkVersion.invoke(android, 36)
                } catch (e2: Exception) {
                    // Ignore
                }
            }
        }
    }

    if (state.executed) {
        configureProject(this)
    } else {
        afterEvaluate {
            configureProject(this)
        }
    }
}
