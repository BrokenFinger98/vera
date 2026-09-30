package com.brokenfinger.vera.arch

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

/**
 * The rules are only as wide as bootstrap's dependency list: a module missing from it contributes
 * no classes, and every rule then passes over it in silence.
 */
private val EXPECTED_MODULES = setOf("metadata", "query", "rule", "layering", "itam", "ingestion")

class ImportScopeTest {

    @Test
    fun `every module reaches the importer`() {
        val root = ProductionClasses.ROOT_PACKAGE
        val seen =
            ProductionClasses.all
                .map { it.packageName.removePrefix(root).removePrefix(".").substringBefore('.') }
                .filter { it.isNotEmpty() }
                .toSet()
        assertThat(seen).containsAll(EXPECTED_MODULES)
    }
}
