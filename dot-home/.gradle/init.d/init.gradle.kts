allprojects{
    repositories {
        maven {
            url = uri("https://maven.aliyun.com/repository/public/")
        }
        maven {
            url = uri("https://maven.aliyun.com/repository/jcenter")
        }
        maven {
            url = uri("https://maven.aliyun.com/repository/spring")
        }
        mavenLocal()
        mavenCentral()
    }

}
