description =
    "Vera ingestion: discovery, monitoring and CSV observations feeding the ITAM reconciliation engine"

dependencies {
    implementation(project(":apps:itam"))
    implementation(libs.spring.boot.starter)
    implementation(libs.spring.modulith.api)
}
