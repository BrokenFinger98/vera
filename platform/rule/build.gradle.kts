description = "Vera platform: rule engine — business rules, ACL, sandboxed customer scripts"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(project(":platform:query"))
    implementation(libs.spring.boot.starter)
    implementation(libs.spring.modulith.api)
    implementation(libs.graalvm.polyglot)
    runtimeOnly(libs.graalvm.js.community)
}
