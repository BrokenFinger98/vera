package com.brokenfinger.vera.arch

import com.tngtech.archunit.core.domain.JavaClasses
import com.tngtech.archunit.core.importer.ClassFileImporter
import com.tngtech.archunit.core.importer.ImportOption
import java.util.regex.Pattern

/**
 * Production classes of every Vera module, imported once per archTest JVM. ArchUnit excludes the
 * `test` and `archTest` suites; `itest` is excluded by the pattern below.
 */
object ProductionClasses {
    const val ROOT_PACKAGE = "com.brokenfinger.vera"

    // DoNotIncludeTests already covers `test` and `archTest`. Its Gradle pattern is
    // `.*/build/classes/([^/]+/)?(test|[^/]+Test)s?/.*`, whose second branch matches any output
    // directory ending in `Test`. `itest` matches neither branch, so it is named here — anchored
    // on the output directory rather than a bare substring any path could happen to contain.
    private val ITEST_OUTPUT = Pattern.compile(".*/build/classes/[^/]+/itest/.*")

    val all: JavaClasses by lazy {
        ClassFileImporter()
            .withImportOption(ImportOption.DoNotIncludeTests())
            .withImportOption(ImportOption { !it.matches(ITEST_OUTPUT) })
            .importPackages(ROOT_PACKAGE)
    }
}
