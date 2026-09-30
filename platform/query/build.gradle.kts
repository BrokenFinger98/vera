description =
    "Vera platform: query engine — jOOQ-based dynamic queries over metadata-defined tables"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(libs.spring.boot.starter.jooq)
    implementation(libs.spring.modulith.api)
}
