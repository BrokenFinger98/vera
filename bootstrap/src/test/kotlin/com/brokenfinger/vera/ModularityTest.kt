package com.brokenfinger.vera

import java.io.File
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatCode
import org.junit.jupiter.api.Test
import org.springframework.modulith.core.ApplicationModules
import org.springframework.modulith.docs.Documenter

/** The auto-configuration that acts on `spring.modulith.runtime.verification-enabled`. */
private const val RUNTIME_VERIFIER =
    "org.springframework.modulith.runtime.autoconfigure.SpringModulithRuntimeAutoConfiguration"

class ModularityTest {

    private val modules = ApplicationModules.of(VeraApplication::class.java)

    @Test
    fun `module boundaries hold`() {
        modules.verify()
    }

    @Test
    fun `all six modules are detected`() {
        // ApplicationModule exposes identifier and displayName; there is no name() in Modulith 2.1
        val identifiers = modules.map { it.identifier.toString() }.toSet()
        assertThat(identifiers)
            .containsExactlyInAnyOrder("metadata", "query", "rule", "layering", "itam", "ingestion")
    }

    @Test
    fun `runtime verifier is on the classpath so the verification property has effect`() {
        assertThatCode { Class.forName(RUNTIME_VERIFIER) }.doesNotThrowAnyException()
    }

    @Test
    fun `documentation snippets are generated for agents to read`() {
        val out = System.getProperty("vera.modulith.docs") ?: "build/spring-modulith-docs"
        Documenter(modules, Documenter.Options.defaults().withOutputFolder(out))
            .writeModulesAsPlantUml()
            .writeIndividualModulesAsPlantUml()
        assertThat(File(out).list()).hasSize(7)
    }
}
