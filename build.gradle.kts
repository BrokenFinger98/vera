import dev.detekt.gradle.Detekt
import dev.detekt.gradle.extensions.DetektExtension
import dev.detekt.gradle.extensions.FailOnSeverity
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.spring) apply false
    alias(libs.plugins.spring.boot) apply false
    alias(libs.plugins.detekt) apply false
    alias(libs.plugins.spotless)
    alias(libs.plugins.kover)
}

group = "com.brokenfinger.vera"

version = "0.0.1-SNAPSHOT"

// ---------- Formatting: one deterministic formatter for the whole repo ----------
// .claude/** holds gitignored Claude Code worktrees (other sessions' checkouts): skip them.
spotless {
    kotlin {
        target("**/*.kt")
        targetExclude("**/build/**", ".claude/**")
        ktfmt().kotlinlangStyle()
    }
    kotlinGradle {
        target("**/*.gradle.kts")
        targetExclude("**/build/**", ".claude/**")
        ktfmt().kotlinlangStyle()
    }
}

// `:platform` and `:apps` only group other projects and hold no sources, so the code conventions
// below apply to leaf projects only.
val codeProjects = subprojects.filter { it.childProjects.isEmpty() }

// ---------- Shared conventions for every code module ----------
configure(codeProjects) {
    group = rootProject.group
    version = rootProject.version

    apply(plugin = "org.jetbrains.kotlin.jvm")
    apply(plugin = "org.jetbrains.kotlin.plugin.spring")
    apply(plugin = "java-library")
    apply(plugin = "dev.detekt")
    apply(plugin = "org.jetbrains.kotlinx.kover")

    extensions.configure<JavaPluginExtension> {
        toolchain { languageVersion.set(JavaLanguageVersion.of(25)) }
    }

    extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension> {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_25)
            allWarningsAsErrors.set(true)
            freeCompilerArgs.addAll("-Xjsr305=strict", "-Xannotation-default-target=param-property")
        }
    }

    val libs = rootProject.extensions.getByType<VersionCatalogsExtension>().named("libs")
    val springBootBom = libs.findLibrary("spring-boot-bom").get()
    val springModulithBom = libs.findLibrary("spring-modulith-bom").get()

    dependencies {
        "implementation"(platform(springBootBom))
        "implementation"(platform(springModulithBom))
        "implementation"(libs.findLibrary("kotlin-reflect").get())
    }

    // ---------- Test suites: test (fast), itest (Testcontainers), archTest (ArchUnit) ----------
    extensions.configure<TestingExtension> {
        suites {
            // `test` inherits the BOMs because testImplementation extends implementation;
            // the custom suites below have their own configurations and must declare them.
            val test =
                getByName<JvmTestSuite>("test") {
                    useJUnitJupiter()
                    dependencies {
                        implementation(libs.findLibrary("spring-boot-starter-test").get())
                    }
                }
            register<JvmTestSuite>("itest") {
                useJUnitJupiter()
                dependencies {
                    implementation(platform(springBootBom))
                    implementation(platform(springModulithBom))
                    implementation(project())
                    implementation(libs.findLibrary("spring-boot-starter-test").get())
                    implementation(libs.findLibrary("spring-boot-testcontainers").get())
                    implementation(libs.findLibrary("testcontainers-postgresql").get())
                    implementation(libs.findLibrary("testcontainers-junit-jupiter").get())
                }
                targets.all {
                    testTask.configure {
                        mustRunAfter(test)
                        systemProperty("spring.profiles.active", "itest")
                    }
                }
            }
            register<JvmTestSuite>("archTest") {
                useJUnitJupiter()
                dependencies {
                    implementation(platform(springBootBom))
                    implementation(platform(springModulithBom))
                    implementation(project())
                    implementation(libs.findLibrary("archunit-junit5").get())
                    implementation(libs.findLibrary("spring-boot-starter-test").get())
                }
                targets.all { testTask.configure { mustRunAfter(test) } }
            }
        }
    }

    tasks.withType<Test>().configureEach {
        // Deliberate: a single fork prints exactly one summary line per test task (below), and one
        // JVM per suite means one Testcontainers PostgreSQL per suite. Re-check both to raise it.
        maxParallelForks = 1
        // Configured on the quiet level so failures stay visible when agents and CI run with -q.
        testLogging.quiet {
            events("failed", "skipped")
            exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
            showStandardStreams = false
        }
        // Agents read this line: "<task path>: <n> tests, <f> failed" — see scripts/check.sh
        addTestListener(SuiteSummaryListener(path))
    }

    // ---------- detekt: the five core principles as machine rules ----------
    // One type-resolved task per source set. Each takes its classpath, language version and
    // jvmTarget (25) from the Kotlin compile task of the same source set.
    val detektSourceSetTasks = listOf("detektMain", "detektTest", "detektItest", "detektArchTest")
    extensions.configure<DetektExtension> {
        buildUponDefaultConfig.set(true)
        allRules.set(false)
        config.setFrom(rootProject.files("config/detekt/detekt.yml"))
        // Any finding fails the build, whatever severity a rule is given (1.23: maxIssues: 0).
        failOnSeverity.set(FailOnSeverity.Info)
        // Baselines are forbidden: they hide debt from the gates. Without this line the plugin
        // silently applies any detekt-baseline.xml that appears in a module.
        baseline.convention(null as RegularFile?)
        // The plain `detekt` task cannot resolve types, so it analyses nothing itself and only
        // runs the source-set tasks.
        source.setFrom()
    }
    tasks.named("detekt") { dependsOn(detektSourceSetTasks) }
    tasks.withType<Detekt>().configureEach {
        reports {
            markdown.required.set(true)
            checkstyle.required.set(true)
            html.required.set(false)
            sarif.required.set(false)
        }
        // Tamper evidence: a module override that weakens the gate fails before any analysis.
        doFirst(
            DetektGateGuard(path, baseline, ignoreFailures, failOnSeverity, disableDefaultRuleSets)
        )
    }

    // Coverage is aggregated at the root, so the per-module koverVerify must stay off `check`.
    // On `check` it would drag `itest`, which needs Docker, into the fast gate.
    extensions.configure<kotlinx.kover.gradle.plugin.dsl.KoverProjectExtension> {
        reports { total { verify { onCheck.set(false) } } }
    }

    // `check` = everything the Stop hook and CI run for a module. detektItest compiles and analyses
    // the itest sources without running them, so `check` still needs no Docker.
    tasks.named("check") { dependsOn(detektSourceSetTasks + "archTest") }
}

// ---------- Aggregated coverage across all modules ----------
dependencies { codeProjects.forEach { kover(project(it.path)) } }

kover {
    reports {
        total {
            xml { onCheck.set(false) }
            html { onCheck.set(false) }
            verify {
                // Off `check` on purpose: koverVerify depends on every Test task, `itest` included,
                // and `itest` needs Docker. The CI coverage job runs koverVerify explicitly, so
                // integration coverage still counts.
                onCheck.set(false)
                rule("line coverage of production code") { minBound(80) }
            }
        }
        filters {
            excludes {
                classes("com.brokenfinger.vera.VeraApplication*", "com.brokenfinger.vera.*.*Module")
            }
        }
    }
}

/**
 * Prints one machine-readable line per test task once its root suite finishes: `<task path>: <n>
 * tests, <f> failed, <s> skipped`. A named top-level class rather than an `afterSuite` closure: the
 * closure overloads of `AbstractTestTask` are removed in Gradle 10, and a class holding only a
 * String stays configuration-cache serialisable.
 */
class SuiteSummaryListener(private val taskPath: String) : TestListener {
    override fun beforeSuite(suite: TestDescriptor) = Unit

    override fun beforeTest(testDescriptor: TestDescriptor) = Unit

    override fun afterTest(testDescriptor: TestDescriptor, result: TestResult) = Unit

    override fun afterSuite(suite: TestDescriptor, result: TestResult) {
        if (suite.parent != null) return
        println(
            "$taskPath: ${result.testCount} tests, ${result.failedTestCount} failed, " +
                "${result.skippedTestCount} skipped"
        )
    }
}

/**
 * Fails a detekt task before it analyses anything when a module has weakened the gate: a baseline
 * that would hide findings, `ignoreFailures`, a `failOnSeverity` other than Info, or disabled
 * default rule sets. It holds only the task path and providers, so it stays configuration-cache
 * serialisable.
 */
class DetektGateGuard(
    private val taskPath: String,
    private val baseline: Provider<RegularFile>,
    private val ignoreFailures: Provider<Boolean>,
    private val failOnSeverity: Provider<FailOnSeverity>,
    private val disableDefaultRuleSets: Provider<Boolean>,
) : Action<Task> {
    override fun execute(task: Task) {
        check(!baseline.isPresent) {
            "$taskPath: detekt baselines are forbidden, they hide debt from the gates. Remove the " +
                "baseline setting, delete ${baseline.get().asFile} and fix the findings."
        }
        check(!ignoreFailures.get()) {
            "$taskPath: detekt ignoreFailures must stay false, or findings stop failing the build. " +
                "Remove the override and fix the findings."
        }
        check(failOnSeverity.orNull == FailOnSeverity.Info) {
            "$taskPath: detekt failOnSeverity must stay Info so any finding fails the build, not " +
                "${failOnSeverity.orNull}. Remove the override and fix the findings."
        }
        check(!disableDefaultRuleSets.get()) {
            "$taskPath: detekt default rule sets must stay enabled; " +
                "remove the override and fix the findings."
        }
    }
}
