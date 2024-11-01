settingsEvaluated {
    pluginManagement {
        repositories {
            mavenLocal()
            maven {
                url = uri("https://maven.aliyun.com/repository/gradle-plugin")
            }
            gradlePluginPortal()
        }
    }
}

allprojects {
    repositories {
        mavenLocal()
        maven {
            url = uri("https://maven.aliyun.com/repository/public/")
        }
        maven {
            url = uri("https://maven.aliyun.com/repository/jcenter")
        }
        maven {
            url = uri("https://maven.aliyun.com/repository/spring")
        }
        mavenCentral()
    }

}
