rootProject.name = "vera"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}

include(
    ":platform:metadata",
    ":platform:query",
    ":platform:rule",
    ":platform:layering",
    ":apps:itam",
    ":ingestion",
    ":bootstrap",
)
