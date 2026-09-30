package com.brokenfinger.vera.arch

import com.tngtech.archunit.core.domain.JavaClass
import com.tngtech.archunit.lang.ArchCondition
import com.tngtech.archunit.lang.ConditionEvents
import com.tngtech.archunit.lang.SimpleConditionEvent.violated
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes
import org.junit.jupiter.api.Test

/** Naming and placement rules that detekt cannot see, because they span modules. */
class NamingRulesTest {

    @Test
    fun `repository implementations live in an internal package of their module`() {
        // No repository exists before Phase 1, and ArchUnit 1.5 fails an empty rule by default.
        classes()
            .that()
            .haveSimpleNameEndingWith("Repository")
            .and()
            .areNotInterfaces()
            .should()
            .resideInAPackage("..internal..")
            .because("adapters stay hidden: Modulith exposes only the module root package")
            .allowEmptyShould(true)
            .check(ProductionClasses.all)
    }

    @Test
    fun `module marker objects live in a direct sub-package of the root`() {
        classes()
            .that()
            .haveSimpleNameEndingWith("Module")
            .should(resideInADirectSubPackageOf(ProductionClasses.ROOT_PACKAGE))
            .check(ProductionClasses.all)
    }

    private fun resideInADirectSubPackageOf(root: String): ArchCondition<JavaClass> =
        object : ArchCondition<JavaClass>("reside in a direct sub-package of $root") {
            override fun check(item: JavaClass, events: ConditionEvents) {
                val pkg = item.packageName
                if (pkg.startsWith("$root.") && !pkg.removePrefix("$root.").contains('.')) return
                val where = item.sourceCodeLocation
                events.add(violated(item, "${item.description} is in $pkg, in $where"))
            }
        }
}
