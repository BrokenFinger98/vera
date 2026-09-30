description = "Vera platform: layering engine — base vs customer-modified metadata, upgrade merge"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(libs.spring.boot.starter)
    implementation(libs.spring.modulith.api)
}
