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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    // Solo aplicamos la medicina al paciente enfermo: 'flutter_vibrate'
    if (project.name == "flutter_vibrate") {
        project.configurations.all {
            resolutionStrategy {
                eachDependency {
                    // Le forzamos la versión 1.6.0 que es segura y NO tiene lStar
                    if (requested.group == "androidx.core" && requested.name == "core") {
                        useVersion("1.6.0")
                        because("La versión 1.6.0 es compatible con plugins antiguos sin lStar")
                    }
                }
            }
        }
    }
}