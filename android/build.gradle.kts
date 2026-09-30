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
// Some Flutter plugins in the current dependency lockfile still hard-code
// compileSdk 33. Keep their Android library modules aligned with the app SDK.
subprojects {
    plugins.withId("com.android.library") {
        val androidComponents = extensions.findByName("androidComponents")
        val finalizeDsl = androidComponents?.javaClass?.methods?.firstOrNull {
            it.name == "finalizeDsl" &&
                it.parameterCount == 1 &&
                it.parameterTypes[0].name == "kotlin.jvm.functions.Function1"
        }
        val configureAndroidDsl: (Any) -> Unit = { androidDsl ->
            val compileSdkSetter = androidDsl.javaClass.methods.firstOrNull {
                it.name in setOf("setCompileSdk", "setCompileSdkVersion") &&
                    it.parameterCount == 1 &&
                    it.parameterTypes[0] in setOf(Integer.TYPE, Integer::class.java)
            }
            compileSdkSetter?.invoke(androidDsl, 36)
        }
        finalizeDsl?.invoke(androidComponents, configureAndroidDsl)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
