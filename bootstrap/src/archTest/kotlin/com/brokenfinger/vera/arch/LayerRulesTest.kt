package com.brokenfinger.vera.arch

import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses
import org.junit.jupiter.api.Test

// A string literal cannot be broken across lines, so the two reasons that carry a document
// reference live here; inline, ktfmt would wrap them past the 120-column detekt limit.
private const val PURE_DOMAIN =
    "domain objects are pure Kotlin (docs/development-rules.md, package layout)"

private const val EXCEPTION_BASE_TYPES =
    "bad input is IllegalArgumentException, bad state is IllegalStateException " +
        "(docs/development-rules.md, naming)"

/** Hexagonal layering: a module's domain package is framework-free and persistence-free. */
class LayerRulesTest {

    @Test
    fun `domain packages depend on neither Spring nor jOOQ nor Jakarta`() {
        noClasses()
            .that()
            .resideInAPackage("..domain..")
            .and()
            // package-info holds the Modulith @NamedInterface descriptor, the one Spring import
            // a domain package is allowed to carry.
            .doNotHaveSimpleName("package-info")
            .should()
            .dependOnClassesThat()
            .resideInAnyPackage("org.springframework..", "org.jooq..", "jakarta..")
            .because(PURE_DOMAIN)
            .check(ProductionClasses.all)
    }

    @Test
    fun `domain exceptions extend IllegalArgumentException or IllegalStateException`() {
        // Rests on one class today. allowEmptyShould stops the rule failing if that class moves;
        // ImportScopeTest is what catches an import gone empty for the wrong reason.
        classes()
            .that()
            .resideInAPackage("..domain..")
            .and()
            .haveSimpleNameEndingWith("Exception")
            .should()
            .beAssignableTo(IllegalArgumentException::class.java)
            .orShould()
            .beAssignableTo(IllegalStateException::class.java)
            .because(EXCEPTION_BASE_TYPES)
            .allowEmptyShould(true)
            .check(ProductionClasses.all)
    }
}
