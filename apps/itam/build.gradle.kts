description =
    "Vera app: IT Asset Management — assets, CIs, lifecycle, identification and reconciliation"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(project(":platform:query"))
    implementation(project(":platform:rule"))
    implementation(libs.spring.boot.starter)
    implementation(libs.spring.modulith.api)
}
