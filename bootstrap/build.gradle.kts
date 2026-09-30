plugins {
    alias(libs.plugins.spring.boot)
}

description = "Vera bootstrap: assembles all modules into one Spring Boot application"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(project(":platform:query"))
    implementation(project(":platform:rule"))
    implementation(project(":platform:layering"))
    implementation(project(":apps:itam"))
    implementation(project(":ingestion"))

    implementation(libs.spring.boot.starter.webmvc)
    implementation(libs.spring.boot.starter.actuator)
    implementation(libs.spring.boot.starter.validation)
    implementation(libs.spring.boot.starter.jooq)
    implementation(libs.spring.boot.starter.flyway)
    // starter-core also pulls spring-modulith-apt, which is inert here: Gradle ignores annotation
    // processors that arrive on the compile classpath instead of the annotationProcessor one.
    implementation(libs.spring.modulith.starter.core)
    // starter-core stops at the core model. The verifier that reads
    // `spring.modulith.runtime.verification-enabled` ships separately, and without it the property
    // is read by nothing.
    implementation(libs.spring.modulith.runtime)
    runtimeOnly(libs.flyway.postgresql)
    runtimeOnly(libs.postgresql)

    // `testAndDevelopmentOnly` extends nothing, so the BOM the root convention puts on
    // `implementation` does not reach it and bootJar fails to resolve a versionless alias.
    testAndDevelopmentOnly(platform(libs.spring.boot.bom))
    testAndDevelopmentOnly(libs.spring.boot.docker.compose)
    testImplementation(libs.spring.modulith.starter.test)
    // The itest suite has its own configurations and inherits nothing from `implementation`, so the
    // jOOQ and transaction types an integration test touches must be declared again.
    "itestImplementation"(libs.spring.boot.starter.jooq)
}

// Documenter writes relative to the working directory unless told otherwise, and Gradle cannot know
// the result is a task output, so it would disappear on a build-cache hit. Declaring both fixes the
// location and lets Gradle restore the diagrams agents read. The property stays relative: a system
// property is part of the task's cache key, so an absolute path would miss the cache in every other
// worktree or clone. A test task's working directory is the project directory.
val modulithDocs = layout.buildDirectory.dir("spring-modulith-docs")

tasks.named<Test>("test") {
    systemProperty("vera.modulith.docs", "build/spring-modulith-docs")
    outputs.dir(modulithDocs).withPropertyName("modulithDocs")
}

tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {
    archiveFileName.set("vera.jar")
}

// application-dev.yaml names `compose.yml`, which lives in the repository root. bootRun otherwise
// starts in bootstrap/ and Boot fails with "'files' content [compose.yml] must exist".
tasks.named<org.springframework.boot.gradle.tasks.run.BootRun>("bootRun") {
    workingDir = rootDir
}

// bootJar resolves testAndDevelopmentOnly — the only place a missing BOM shows up (Task 5 review)
tasks.named("check") { dependsOn("bootJar") }
