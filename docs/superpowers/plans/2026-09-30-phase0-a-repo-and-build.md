# Phase 0-A: Repository, Build Toolchain and PoCs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the empty `vera` directory into a building, testing, CI-green Kotlin/Spring Boot 4.1 modular monolith skeleton with the quality toolchain and the four Phase 0 proofs of concept, ready for the harness plan (Phase 0-B) and the first metadata-engine ticket.

**Architecture:** One Gradle multi-project (`platform/*`, `apps/itam`, `ingestion`, `bootstrap`) sharing root package `com.brokenfinger.vera`; Spring Modulith treats each direct sub-package as a module and `verify()` enforces boundaries. Three test suites per module (`test`, `itest` with Testcontainers PostgreSQL 18, `archTest` with ArchUnit). Formatting and linting are deterministic (ktfmt via Spotless, detekt with the five core principles encoded, `maxIssues=0`). `scripts/*.sh` are the only entry points agents use.

**Tech Stack (verified on Maven Central / services.gradle.org, 2026-09-30):** Java 25 (Temurin, installed), Gradle 9.7.1, Kotlin 2.3.21 (Boot 4.1.1 BOM-managed), Spring Boot 4.1.1 (Framework 7.0.9), Spring Modulith 2.1.1, jOOQ 3.21.7 (BOM), Flyway 12.4.0 (BOM) + `flyway-database-postgresql`, PostgreSQL 18 (`postgres:18-alpine`), Testcontainers 2.0.5 (`testcontainers-postgresql`, `testcontainers-junit-jupiter`), JUnit 6.0.3 + AssertJ 3.27.7 (BOM), GraalVM Polyglot 25.4.4.1.1 (`polyglot`, `js-community`), Spotless 8.10.3 + ktfmt, detekt 1.23.8, ArchUnit 1.5.1, Kover 0.9.11, springdoc 3.1.1 (added later, not in this plan), Gradle daemon on JDK 21 (detekt 1.23 cannot run on 25).

**Spec:** `docs/superpowers/specs/2026-09-30-vera-dev-environment-design.md` §4, §8, §11, §12 steps 2–3 and 6.

**Conventions for every task:** commit messages in English, Conventional Commits, no AI trailers. Run commands from the repository root with absolute paths or `./gradlew`; never `cd` inside a compound Bash command (see spec §5). Every Gradle step below records the last line and exit code as evidence.

---

## File structure this plan creates

```
vera/
├── .gitignore  .editorconfig  .gitattributes  LICENSE  README.md  README.ko.md
├── gradle/wrapper/{gradle-wrapper.jar,gradle-wrapper.properties}  gradlew  gradlew.bat
├── gradle/libs.versions.toml           # single source of versions
├── gradle.properties                   # configuration cache, build cache, parallel, JVM args
├── gradle/gradle-daemon-jvm.properties # daemon JVM 21 (detekt 1.23); compile/test on the 25 toolchain
├── settings.gradle.kts                 # project names and paths
├── build.gradle.kts                    # shared conventions for all subprojects (Kotlin, Boot BOM, test suites, detekt, spotless, kover)
├── config/detekt/detekt.yml            # five core principles as rules
├── platform/metadata/  platform/query/  platform/rule/  platform/layering/
├── apps/itam/  ingestion/  bootstrap/   # each: build.gradle.kts + src/{main,test,itest,archTest}
├── scripts/{check,test,itest,build}.sh  # agent entry points
├── compose.yml                          # human demo stack; PG default, others under profile "full"
└── .github/workflows/ci.yml             # build · test · archTest · itest · kover
```

Module packages (Modulith modules are the direct sub-packages of `com.brokenfinger.vera`):

| Gradle project | Package | Depends on (Modulith `allowedDependencies`) |
|---|---|---|
| `:platform:metadata` | `com.brokenfinger.vera.metadata` | — |
| `:platform:query` | `com.brokenfinger.vera.query` | metadata |
| `:platform:rule` | `com.brokenfinger.vera.rule` | metadata, query |
| `:platform:layering` | `com.brokenfinger.vera.layering` | metadata |
| `:apps:itam` | `com.brokenfinger.vera.itam` | metadata, query, rule |
| `:ingestion` | `com.brokenfinger.vera.ingestion` | itam |
| `:bootstrap` | `com.brokenfinger.vera` (application class) | all |

`—` means `allowedDependencies = {}`; omitting the attribute would mean unrestricted.

---

### Task 1: Repository hygiene files

**Files:**
- Create: `.gitignore`, `.editorconfig`, `.gitattributes`, `LICENSE`, `README.md`, `README.ko.md`

- [ ] **Step 1: Write `.gitignore`**

```gitignore
# Gradle
.gradle/
build/
!gradle/wrapper/gradle-wrapper.jar
.kotlin/

# IDE
.idea/
*.iml
.vscode/

# OS
.DS_Store

# Local env and secrets
.env
.env.local
*.local.yaml

# Personal harness state (committed twin: goal.md.example)
.harness/state/goal.md

# LLM wiki raw transcripts (copies of ~/.claude/projects; never commit)
docs/llm-wiki/raw/inbox/

# Claude Code personal files
.claude/settings.local.json
CLAUDE.local.md
.claude/worktrees/

# Korean-only research notes live in the owner's central wiki, not here
docs/research/
```

- [ ] **Step 2: Write `.editorconfig`**

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 4
max_line_length = 120

[*.{yml,yaml,json,toml,md}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[*.sh]
indent_size = 2

[*.bat]
end_of_line = crlf
```

- [ ] **Step 3: Write `.gitattributes`**

```gitattributes
* text=auto eol=lf
*.jar binary
*.png binary
gradlew text eol=lf
*.bat text eol=crlf
```

- [ ] **Step 4: Write `LICENSE` (MIT)**

```text
MIT License

Copyright (c) 2026 BrokenFinger98

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 5: Write `README.md`**

```markdown
# Vera

> *vera* — Latin, "true". A metadata-driven enterprise platform engine, built to understand how
> systems of record like ServiceNow keep one platform binary while every customer customises.

Vera is a learning and portfolio project. It implements the platform layer first — a metadata
engine (tables and fields defined at runtime), a rule engine with sandboxed scripts, a
layering/upgrade engine that keeps customer changes apart from the standard, and later
multi-instance provisioning — and puts an IT Asset Management (ITAM) application on top of it.

**Every line of code in this repository is written by AI coding agents.** The owner writes
specs, tickets and reviews. How that works is documented in `CLAUDE.md` and
`docs/superpowers/specs/`.

## Status

Phase 0 — repository, toolchain and harness. See `.harness/state/progress.md`.

## Build

Requires JDK 25 (compile/test toolchain), JDK 21 (Gradle daemon — detekt 1.23 cannot run on 25) and Docker (integration tests).

```bash
./scripts/check.sh   # format check, detekt, unit tests, architecture tests
./scripts/itest.sh   # integration tests (Testcontainers PostgreSQL 18)
./scripts/build.sh   # assemble
```

Run the demo stack: `docker compose up -d` then `SPRING_PROFILES_ACTIVE=dev ./gradlew :bootstrap:bootRun`.
Run from the repository root; IDE run configurations must use the root as working directory so `compose.yml` is found.

## Stack

Kotlin 2.3 · Java 25 · Spring Boot 4.1 · Spring Modulith 2.1 · PostgreSQL 18 · jOOQ 3.21 ·
Flyway · GraalJS (rule sandbox) · Testcontainers 2 · Gradle 9.7.

## License

MIT. Korean readers: see `README.ko.md`.
```

- [ ] **Step 6: Write `README.ko.md`**

```markdown
<!-- translated-from: README.md@initial -->
# Vera

> *vera* — 라틴어로 "진실한". ServiceNow 같은 기록 시스템이 어떻게 하나의 플랫폼 바이너리를 유지하면서
> 고객마다 커스터마이징을 허용하는지 이해하기 위해 직접 만드는 메타데이터 기반 엔터프라이즈 플랫폼 엔진.

Vera는 학습·포트폴리오 프로젝트입니다. 플랫폼 층(런타임에 정의되는 테이블/필드의 메타데이터 엔진, 샌드박스
스크립트 룰 엔진, 표준과 고객 수정분을 분리하는 레이어링/업그레이드 엔진, 나중에 멀티 인스턴스 프로비저닝)을
먼저 만들고, 그 위에 IT 자산관리(ITAM) 앱을 올립니다.

**이 저장소의 모든 코드는 AI 코딩 에이전트가 작성합니다.** 소유자는 스펙·티켓·리뷰만 합니다. 방식은
`CLAUDE.md`와 `docs/superpowers/specs/`에 있습니다.

## 상태

Phase 0 — 저장소·툴체인·하네스 구축 단계. `.harness/state/progress.md` 참고.

## 빌드

JDK 25(컴파일·테스트 툴체인), JDK 21(Gradle 데몬 — detekt 1.23이 25에서 실행되지 않음), Docker(통합 테스트)가 필요합니다.

```bash
./scripts/check.sh   # 포맷 검사, detekt, 유닛 테스트, 아키텍처 테스트
./scripts/itest.sh   # 통합 테스트 (Testcontainers PostgreSQL 18)
./scripts/build.sh   # 빌드(assemble)
```

데모 스택: `docker compose up -d` 후 `SPRING_PROFILES_ACTIVE=dev ./gradlew :bootstrap:bootRun`.
저장소 루트에서 실행하세요. IDE 실행 구성도 작업 디렉터리를 루트로 두어야 `compose.yml`을 찾습니다.

## 스택

Kotlin 2.3 · Java 25 · Spring Boot 4.1 · Spring Modulith 2.1 · PostgreSQL 18 · jOOQ 3.21 ·
Flyway · GraalJS(룰 샌드박스) · Testcontainers 2 · Gradle 9.7.

## 라이선스

MIT. 커밋되는 산출물(코드·커밋·문서)은 영어입니다. 이 파일만 한국어 쌍입니다.
```

- [ ] **Step 7: Commit**

```bash
git add .gitignore .editorconfig .gitattributes LICENSE README.md README.ko.md
git commit -m "chore: add repository hygiene files and README"
```

---

### Task 2: Gradle 9.7.1 wrapper

There is no global `gradle` binary on this machine. Download the official Gradle 9.7.1 distribution into the session scratchpad and use its `bin/gradle` once, only to generate the wrapper; afterwards everything uses `./gradlew`. (Homebrew is not used for this — the formula pulls in a second OpenJDK.)

**Files:**
- Create: `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, `gradle/wrapper/gradle-wrapper.properties`

- [ ] **Step 1: Download and unpack Gradle 9.7.1 into the scratchpad**

```bash
SCRATCH=/private/tmp/claude-501/-Users-yu-sun00-Desktop-vera/69966e7b-9af3-49c9-9a4e-6ab9e75c933c/scratchpad
mkdir -p "$SCRATCH/gradle-dist"
curl -fsSL -o "$SCRATCH/gradle-dist/gradle-9.7.1-bin.zip" https://services.gradle.org/distributions/gradle-9.7.1-bin.zip
curl -fsSL -o "$SCRATCH/gradle-dist/gradle-9.7.1-bin.zip.sha256" https://services.gradle.org/distributions/gradle-9.7.1-bin.zip.sha256
echo "$(cat "$SCRATCH/gradle-dist/gradle-9.7.1-bin.zip.sha256")  $SCRATCH/gradle-dist/gradle-9.7.1-bin.zip" | shasum -a 256 -c -
unzip -q -o "$SCRATCH/gradle-dist/gradle-9.7.1-bin.zip" -d "$SCRATCH/gradle-dist"
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home "$SCRATCH/gradle-dist/gradle-9.7.1/bin/gradle" --version
```
Expected: `OK` from shasum, then a version banner with `Gradle 9.7.1` and `JVM: 25.0.3 (Eclipse Adoptium ...)`.

- [ ] **Step 2: Generate the wrapper pinned to 9.7.1**

```bash
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home "$SCRATCH/gradle-dist/gradle-9.7.1/bin/gradle" wrapper --gradle-version 9.7.1 --distribution-type bin --project-dir /Users/yu-sun00/Desktop/vera --console=plain
```
Expected: `BUILD SUCCESSFUL`, and `gradle/wrapper/gradle-wrapper.properties` contains `distributionUrl=https\://services.gradle.org/distributions/gradle-9.7.1-bin.zip`.
If Gradle refuses with "Directory ... does not contain a Gradle build", first create `settings.gradle.kts` containing exactly one line `rootProject.name = "vera"` (Task 3 will overwrite it), rerun the command, and include that file in the commit.

- [ ] **Step 3: Verify the wrapper itself**

```bash
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home ./gradlew --version
```
Expected: `Gradle 9.7.1` and `JVM: 25.0.3 (Eclipse Adoptium ...)`. Also confirm `git check-ignore gradle/wrapper/gradle-wrapper.jar` prints nothing (exit 1) — the jar must be trackable — and that `gradlew` is executable (`ls -l`).

- [ ] **Step 3b: Pin the distribution checksum**

Add one line to `gradle/wrapper/gradle-wrapper.properties` so an unattended run verifies what it downloads: `distributionSha256Sum=acd53f1edaf02f1a8ff99879f8a34b302661a057d9b063ae9e35b552f804d20a`, the official SHA-256 of `gradle-9.7.1-bin.zip` as published at `https://services.gradle.org/distributions/gradle-9.7.1-bin.zip.sha256`. Gradle writes this key alphabetically, directly after `distributionPath`. It is committed with Task 3. `retries` is raised from `0` to `3` in the same file at the same time, so a CI runner with a flaky network retries the distribution download instead of failing the job.

- [ ] **Step 4: Commit**

```bash
git add gradlew gradlew.bat gradle/wrapper/gradle-wrapper.jar gradle/wrapper/gradle-wrapper.properties
git commit -m "build: add Gradle 9.7.1 wrapper"
```

---

### Task 3: Version catalog, settings and shared build conventions

**Files:**
- Create: `gradle/libs.versions.toml`, `gradle.properties`, `build.gradle.kts`, `config/detekt/detekt.yml`
- Replace: `settings.gradle.kts` (the one-line placeholder Task 2 left behind)
- Modify: `gradle/wrapper/gradle-wrapper.properties` — adds `distributionSha256Sum`, see Task 2 Step 3b
- Create: an empty tracked `.gitkeep` in every directory named by `include(...)`. Gradle 9.7.1 refuses to configure a project whose directory does not exist, and Task 4 replaces these placeholders with real sources.

- [ ] **Step 1: Write `gradle/libs.versions.toml`**

```toml
[versions]
kotlin = "2.3.21"            # matches Spring Boot 4.1.1 BOM (kotlin.version)
spring-boot = "4.1.1"
spring-modulith = "2.1.1"
graalvm-polyglot = "25.4.4.1.1"
archunit = "1.5.1"
detekt = "1.23.8"
spotless = "8.10.3"
kover = "0.9.11"

[libraries]
spring-boot-bom = { module = "org.springframework.boot:spring-boot-dependencies", version.ref = "spring-boot" }
spring-modulith-bom = { module = "org.springframework.modulith:spring-modulith-bom", version.ref = "spring-modulith" }

# Versions below come from the two BOMs above — never pin them here.
spring-boot-starter = { module = "org.springframework.boot:spring-boot-starter" }
spring-boot-starter-webmvc = { module = "org.springframework.boot:spring-boot-starter-webmvc" }
spring-boot-starter-actuator = { module = "org.springframework.boot:spring-boot-starter-actuator" }
spring-boot-starter-validation = { module = "org.springframework.boot:spring-boot-starter-validation" }
spring-boot-starter-jooq = { module = "org.springframework.boot:spring-boot-starter-jooq" }
spring-boot-starter-flyway = { module = "org.springframework.boot:spring-boot-starter-flyway" }
spring-boot-docker-compose = { module = "org.springframework.boot:spring-boot-docker-compose" }
spring-boot-starter-test = { module = "org.springframework.boot:spring-boot-starter-test" }
spring-boot-testcontainers = { module = "org.springframework.boot:spring-boot-testcontainers" }
flyway-postgresql = { module = "org.flywaydb:flyway-database-postgresql" }
postgresql = { module = "org.postgresql:postgresql" }
kotlin-reflect = { module = "org.jetbrains.kotlin:kotlin-reflect" }
testcontainers-postgresql = { module = "org.testcontainers:testcontainers-postgresql" }
testcontainers-junit-jupiter = { module = "org.testcontainers:testcontainers-junit-jupiter" }
spring-modulith-api = { module = "org.springframework.modulith:spring-modulith-api" }
spring-modulith-runtime = { module = "org.springframework.modulith:spring-modulith-runtime" }
spring-modulith-starter-core = { module = "org.springframework.modulith:spring-modulith-starter-core" }
spring-modulith-starter-test = { module = "org.springframework.modulith:spring-modulith-starter-test" }

graalvm-polyglot = { module = "org.graalvm.polyglot:polyglot", version.ref = "graalvm-polyglot" }
graalvm-js-community = { module = "org.graalvm.polyglot:js-community", version.ref = "graalvm-polyglot" }
archunit-junit5 = { module = "com.tngtech.archunit:archunit-junit5", version.ref = "archunit" }

[plugins]
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
kotlin-spring = { id = "org.jetbrains.kotlin.plugin.spring", version.ref = "kotlin" }
spring-boot = { id = "org.springframework.boot", version.ref = "spring-boot" }
detekt = { id = "io.gitlab.arturbosch.detekt", version.ref = "detekt" }
spotless = { id = "com.diffplug.spotless", version.ref = "spotless" }
kover = { id = "org.jetbrains.kotlinx.kover", version.ref = "kover" }
```

- [ ] **Step 2: Write `gradle.properties`**

```properties
org.gradle.jvmargs=-Xmx3g -XX:+UseParallelGC -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configuration-cache=true
org.gradle.console=plain
kotlin.code.style=official
kotlin.daemon.jvmargs=-Xmx2g
# GraalJS on a stock JDK runs the interpreter only; silence the warning in tests (spec D6).
systemProp.polyglot.engine.WarnInterpreterOnly=false
# detekt 1.23 bundles Kotlin 2.0.21, whose JavaVersion parser rejects JDK 25, so the daemon runs on
# JDK 21 (gradle/gradle-daemon-jvm.properties) while compilation and tests use the 25 toolchain.
org.gradle.java.installations.fromEnv=JAVA_HOME_21_X64,JAVA_HOME_25_X64,JAVA_HOME_21_ARM64,JAVA_HOME_25_ARM64
# Without this a machine that has no JDK 21 fails with "download from 'null'"; with it Gradle
# says plainly that no matching Java 21 installation was found.
org.gradle.java.installations.auto-download=false
```

- [ ] **Step 3: Write `settings.gradle.kts`**

```kotlin
rootProject.name = "vera"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}

include(
    ":platform:metadata",
    ":platform:query",
    ":platform:rule",
    ":platform:layering",
    ":apps:itam",
    ":ingestion",
    ":bootstrap",
)
```

- [ ] **Step 4: Write `build.gradle.kts` (root)**

```kotlin
import io.gitlab.arturbosch.detekt.Detekt
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
spotless {
    kotlin {
        target("**/*.kt")
        targetExclude("**/build/**")
        ktfmt().kotlinlangStyle()
    }
    kotlinGradle {
        target("**/*.gradle.kts")
        targetExclude("**/build/**")
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
    apply(plugin = "io.gitlab.arturbosch.detekt")
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
    extensions.configure<io.gitlab.arturbosch.detekt.extensions.DetektExtension> {
        buildUponDefaultConfig = true
        allRules = false
        config.setFrom(rootProject.files("config/detekt/detekt.yml"))
        baseline = null // baselines are forbidden: they hide debt from the gates
        source.setFrom(
            "src/main/kotlin",
            "src/test/kotlin",
            "src/itest/kotlin",
            "src/archTest/kotlin",
        )
    }
    tasks.withType<Detekt>().configureEach {
        // detekt 1.23.x embeds a Kotlin 2.0 compiler; 21 is its highest known JVM target.
        jvmTarget = "21"
        reports {
            md.required.set(true)
            xml.required.set(true)
            html.required.set(false)
            sarif.required.set(false)
        }
    }

    // Coverage is aggregated at the root, so the per-module koverVerify must stay off `check`.
    // On `check` it would drag `itest`, which needs Docker, into the fast gate.
    extensions.configure<kotlinx.kover.gradle.plugin.dsl.KoverProjectExtension> {
        reports { total { verify { onCheck.set(false) } } }
    }

    // `check` = everything the Stop hook and CI run for a module. detektMain adds type resolution
    // for declared nullability only (parameters, declared locals, same-file returns); `!!` on
    // inferred types is missed because detekt 1.23's Kotlin 2.0.21 compiler cannot read Kotlin 2.3
    // stdlib metadata. Full resolution awaits detekt 2.x GA.
    tasks.named("check") { dependsOn("detektMain", "archTest") }
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
```

- [ ] **Step 5: Write `config/detekt/detekt.yml`**

```yaml
# Vera detekt configuration — the five core principles as rules.
# 1 one method = one job (≤10 lines)   2 no else / early return   3 wrap primitives
# 4 behaviour over getters             5 composition over inheritance
# Rules that cannot be expressed here are covered by ArchUnit (archTest) or review.
build:
  maxIssues: 0
  weights:
    complexity: 2
    style: 1

config:
  validation: true
  warningsAsErrors: true

complexity:
  active: true
  LongMethod:
    active: true
    # principle 1: a function declaration longer than 10 lines (signature to closing brace) is a smell
    threshold: 11
    ignoreAnnotated:
      - 'Test'
      - 'ParameterizedTest'
      - 'RepeatedTest'
      - 'TestFactory'
      - 'BeforeEach'
      - 'AfterEach'
      - 'BeforeAll'
      - 'AfterAll'
      - 'Bean'
  LongParameterList:
    active: true
    functionThreshold: 5
    constructorThreshold: 6
    ignoreDefaultParameters: true
  NestedBlockDepth:
    active: true
    threshold: 3             # principle 2: early return instead of nesting
  TooManyFunctions:
    active: true
    # detekt's inherited test excludes only know src/test; the custom suites need naming too.
    excludes: &testSuites ['**/test/**', '**/itest/**', '**/archTest/**', '**/*.kts']
    thresholdInClasses: 12
    thresholdInInterfaces: 12
    thresholdInObjects: 12
    thresholdInFiles: 20
    ignoreDeprecated: true
    ignorePrivate: true
  CyclomaticComplexMethod:
    active: true
    threshold: 8
  LargeClass:
    active: true
    threshold: 300

style:
  active: true
  ReturnCount:
    active: false            # early returns are the rule, not the exception
  MaxLineLength:
    active: true
    maxLineLength: 120
  ForbiddenComment:
    active: true
    comments:
      - reason: 'Track work in GitHub issues, not in code comments.'
        value: 'TODO'
      - reason: 'Track work in GitHub issues, not in code comments.'
        value: 'FIXME'
  MagicNumber:
    active: true
    excludes: *testSuites
    ignoreNumbers: ['-1', '0', '1', '2']
    ignoreAnnotation: true
    ignorePropertyDeclaration: true
    ignoreCompanionObjectPropertyDeclaration: true
  UnusedPrivateMember:
    active: true
  UseDataClass:
    active: true
  WildcardImport:
    active: true
    excludeImports: []
  ThrowsCount:
    active: true
    max: 3
    excludeGuardClauses: true   # principle 2: leading `if (...) throw` guards are the house style
  UnnecessaryAbstractClass:
    active: true             # principle 5: composition over inheritance
  UnnecessaryInheritance:
    active: true

exceptions:
  active: true
  TooGenericExceptionCaught:
    active: true
    excludes: *testSuites
  SwallowedException:
    active: true             # GitClear 2026: error-masking +47% in AI code — never swallow
  PrintStackTrace:
    active: true
  InstanceOfCheckForException:
    active: true
    excludes: *testSuites

potential-bugs:
  active: true
  # type resolution via detektMain — declared nullability only; inferred nulls are not caught until detekt 2.x
  UnsafeCallOnNullableType:
    active: true
  # type resolution via detektMain — declared nullability only; inferred nulls are not caught until detekt 2.x
  ImplicitDefaultLocale:
    active: true

naming:
  active: true
  FunctionNaming:
    active: true
    ignoreAnnotated: ['Test', 'ParameterizedTest']
  ClassNaming:
    active: true

performance:
  active: true
  SpreadOperator:
    active: false            # forwarding vararg needs *; one startup copy is not a cost (same shape as ReturnCount)

# No `formatting:` section here on purpose. ktfmt via Spotless owns formatting, so the
# detekt-formatting ruleset is not on the detekt classpath, and its config keys would then fail
# `config.validation` as unknown properties.

coroutines:
  active: true
```

- [ ] **Step 6: Verify the build configures (no modules yet)**

Run each of these from the repository root with `JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home`:

```bash
./gradlew help --console=plain -q; echo exit=$?
./gradlew spotlessCheck --console=plain -q; echo exit=$?
./gradlew :bootstrap:tasks --group=verification --console=plain -q
```
Expected: the Gradle help banner then `exit=0`; `spotlessCheck` silent with `exit=0` (if it fails, run `spotlessApply` and inspect the diff); the task list containing `detekt`, `test`, `itest`, `archTest` and `koverVerify`. If plugin resolution fails, the error names the plugin id and version — fix the catalog, do not change versions elsewhere.

Decision (2026-09-30): detekt 1.23.8 bundles Kotlin 2.0.21, whose shaded IntelliJ `JavaVersion` parser rejects any feature version above 24, so on a Java 25 daemon the task dies with `> 25.0.3` before analysis starts. detekt 2.0 exists only as `dev.detekt:detekt-gradle-plugin:2.0.0-alpha.6`, and an alpha is not an acceptable gate. Konsist 0.17.3 depends on the same `kotlin-compiler-embeddable:2.0.21` and would crash the same way inside a Java 25 `archTest` JVM. Therefore the Gradle daemon runs on JDK 21 via `gradle/gradle-daemon-jvm.properties`, with `org.gradle.java.installations.fromEnv` so CI finds both JDKs; compilation and tests keep the Java 25 toolchain; and Konsist is replaced by ArchUnit 1.5.1, which embeds no compiler and is what Spring Modulith uses internally. detekt 1.23.8 also blocks the Gradle 10 upgrade (it calls `ReportingExtension.file(String)`, removed in Gradle 10); both constraints lift together with detekt 2.x GA. detektMain's type resolution is partial for the same reason (declared nullability only). See Step 6b.

- [ ] **Step 6b: Put the daemon on JDK 21**

`./gradlew updateDaemonJvm --jvm-version=21` fails on Gradle 9.7.1 with "Toolchain download repositories have not been configured", so write `gradle/gradle-daemon-jvm.properties` by hand with exactly:

```properties
#This file is generated by updateDaemonJvm
toolchainVersion=21
```

Append to `gradle.properties`, naming the variables `actions/setup-java` exports on both x64 and arm64 runners and switching auto-provisioning off so a machine without JDK 21 gets a clear message instead of a download attempt:

```properties
# detekt 1.23 bundles Kotlin 2.0.21, whose JavaVersion parser rejects JDK 25, so the daemon runs on
# JDK 21 (gradle/gradle-daemon-jvm.properties) while compilation and tests use the 25 toolchain.
org.gradle.java.installations.fromEnv=JAVA_HOME_21_X64,JAVA_HOME_25_X64,JAVA_HOME_21_ARM64,JAVA_HOME_25_ARM64
# Without this a machine that has no JDK 21 fails with "download from 'null'"; with it Gradle
# says plainly that no matching Java 21 installation was found.
org.gradle.java.installations.auto-download=false
```

Verify, keeping `JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home` as the launcher:

```bash
./gradlew --version
./gradlew help -q; echo exit=$?
mkdir -p bootstrap/src/main/kotlin/com/brokenfinger/vera
printf 'package com.brokenfinger.vera\n\nobject Tmp { const val X: Int = 1 }\n' > bootstrap/src/main/kotlin/com/brokenfinger/vera/Tmp.kt
./gradlew :bootstrap:detekt -q; echo exit=$?
./gradlew :bootstrap:compileKotlin -q
javap -v bootstrap/build/classes/kotlin/main/com/brokenfinger/vera/Tmp.class | grep 'major version'
rm bootstrap/src/main/kotlin/com/brokenfinger/vera/Tmp.kt && ./gradlew clean -q
```
Expected: `Launcher JVM: 25.0.3` with `Daemon JVM: Compatible with Java 21, any vendor, nativeImageCapable=false (from gradle/gradle-daemon-jvm.properties)`; `exit=0` from `help`; `exit=0` from `:bootstrap:detekt`, which is the proof detekt now executes; and `major version: 69`, which is Java 25 bytecode from the toolchain. Delete the throwaway file and leave the tree clean. Committed separately as `build: run the Gradle daemon on JDK 21 so detekt 1.23 executes; compile and test on 25`.

- [ ] **Step 7: Commit**

```bash
git add gradle/libs.versions.toml gradle.properties settings.gradle.kts build.gradle.kts config/detekt/detekt.yml gradle/wrapper/gradle-wrapper.properties platform apps ingestion bootstrap
git commit -m "build: add version catalog, shared conventions, test suites and detekt rules"
```

---

### Task 4: Module skeletons with one real value object

Every module gets a `build.gradle.kts`, a `package-info.java` declaring its Modulith module and allowed dependencies, and a Kotlin marker object. The metadata module also gets a real value object, `TableName`, with tests, so that detekt, ArchUnit and Kover run against real code from day one (spec §8).

Identifier policy, verified against PostgreSQL 18 and fixed in review: `TableName` is a structural gate only — pattern and physical length. DDL and jOOQ always render identifiers through `DSL.name()` (quoted); because the pattern guarantees lowercase ASCII, quoting is semantically a no-op and costs nothing. There is therefore no SQL keyword list: a physical name always starts with `u_`, so a keyword can never reach the database unquoted, and extending such a list later would be a breaking change. The 63-byte limit binds the *physical* name, so a value is capped at 61 characters; capping the value at 63 instead let two distinct names truncate to one physical table.

**Files:**
- Create: `platform/metadata/build.gradle.kts`
- Create: `platform/metadata/src/main/java/com/brokenfinger/vera/metadata/package-info.java`
- Create: `platform/metadata/src/main/java/com/brokenfinger/vera/metadata/domain/package-info.java` — the `domain` named interface, without which `metadata.domain` stays internal to the CLOSED module and the first `query` import of `TableName` fails `ApplicationModules.verify()`
- Create: `platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/MetadataModule.kt`
- Create: `platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/domain/TableName.kt`
- Create: `platform/metadata/src/test/kotlin/com/brokenfinger/vera/metadata/domain/TableNameTest.kt`
- Create: `platform/query/build.gradle.kts`, `platform/query/src/main/java/com/brokenfinger/vera/query/package-info.java`, `platform/query/src/main/kotlin/com/brokenfinger/vera/query/QueryModule.kt`
- Create: `platform/rule/build.gradle.kts`, `platform/rule/src/main/java/com/brokenfinger/vera/rule/package-info.java`, `platform/rule/src/main/kotlin/com/brokenfinger/vera/rule/RuleModule.kt`
- Create: `platform/layering/build.gradle.kts`, `platform/layering/src/main/java/com/brokenfinger/vera/layering/package-info.java`, `platform/layering/src/main/kotlin/com/brokenfinger/vera/layering/LayeringModule.kt`
- Create: `apps/itam/build.gradle.kts`, `apps/itam/src/main/java/com/brokenfinger/vera/itam/package-info.java`, `apps/itam/src/main/kotlin/com/brokenfinger/vera/itam/ItamModule.kt`
- Create: `ingestion/build.gradle.kts`, `ingestion/src/main/java/com/brokenfinger/vera/ingestion/package-info.java`, `ingestion/src/main/kotlin/com/brokenfinger/vera/ingestion/IngestionModule.kt`
- Delete: the `.gitkeep` Task 3 left in each of these six directories (`git rm`). `bootstrap/.gitkeep` stays; Task 5 replaces it.
- Modify: `gradle/libs.versions.toml` — adds `spring-modulith-api` (BOM-managed, no version). `@ApplicationModule` lives in `spring-modulith-api`, so every module needs it on the compile classpath.
- Modify: `config/detekt/detekt.yml` — adds `style.ThrowsCount.excludeGuardClauses: true`, see Step 7

- [ ] **Step 1: Write the failing test for `TableName`**

`platform/metadata/src/test/kotlin/com/brokenfinger/vera/metadata/domain/TableNameTest.kt`:

```kotlin
package com.brokenfinger.vera.metadata.domain

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

class TableNameTest {

    @ParameterizedTest(name = "accepts {0}")
    @ValueSource(strings = ["cmdb_ci", "asset", "x", "a1_b2", "cmdb_ci_server_v2"])
    fun `accepts lower snake_case identifiers starting with a letter`(raw: String) {
        assertThat(TableName.of(raw).value).isEqualTo(raw)
    }

    @ParameterizedTest(name = "rejects {0}")
    @ValueSource(strings = ["", "1abc", "Cmdb", "cmdb-ci", "cmdb ci", "sys_table", "u_asset"])
    fun `rejects empty, capitalised, hyphenated and reserved-prefix names`(raw: String) {
        assertThatThrownBy { TableName.of(raw) }
            .isInstanceOf(InvalidTableNameException::class.java)
            .hasMessageContaining("'$raw'")
    }

    @Test
    fun `physical name never exceeds the PostgreSQL identifier limit`() {
        assertThat(TableName.of("a".repeat(61)).physicalName()).hasSize(63)
        assertThatThrownBy { TableName.of("a".repeat(62)) }
            .isInstanceOf(InvalidTableNameException::class.java)
    }

    @Test
    fun `empty name reports the empty string in its message`() {
        val thrown = assertThrows<InvalidTableNameException> { TableName.of("") }
        assertThat(thrown).hasMessage("Invalid table name '': must not be empty")
        assertThat(thrown.raw).isEmpty()
        assertThat(thrown.reason).isEqualTo("must not be empty")
    }

    @Test
    fun `accepts a lowercase SQL keyword because the physical name is prefixed`() {
        assertThat(TableName.of("select").physicalName()).isEqualTo("u_select")
    }

    @Test
    fun `physical name is prefixed so customer tables never collide with system tables`() {
        assertThat(TableName.of("asset").physicalName()).isEqualTo("u_asset")
    }
}
```

- [ ] **Step 2: Write `platform/metadata/build.gradle.kts`**

```kotlin
description = "Vera platform: metadata engine — table and field definitions, the system catalog"

dependencies {
    implementation(libs.spring.boot.starter)
    implementation(libs.spring.modulith.api)
}
```

- [ ] **Step 3: Write the Modulith package descriptors for metadata**

`platform/metadata/src/main/java/com/brokenfinger/vera/metadata/package-info.java`:

```java
/** Metadata engine: table and field definitions stored as data. Has no dependencies on other modules. */
@org.springframework.modulith.ApplicationModule(displayName = "metadata", allowedDependencies = {})
package com.brokenfinger.vera.metadata;
```

`platform/metadata/src/main/java/com/brokenfinger/vera/metadata/domain/package-info.java`:

```java
/** Named interface "domain": value objects other modules may depend on via `metadata :: domain`. */
@org.springframework.modulith.NamedInterface("domain")
package com.brokenfinger.vera.metadata.domain;
```

- [ ] **Step 4: Write the marker object and the value object**

`platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/MetadataModule.kt`:

```kotlin
package com.brokenfinger.vera.metadata

/** Public entry point of the metadata module; real API arrives with the first Phase 1 ticket. */
object MetadataModule {
    const val NAME: String = "metadata"
}
```

`platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/domain/TableName.kt`:

```kotlin
package com.brokenfinger.vera.metadata.domain

/**
 * A customer-defined table name. Lower snake_case, starts with a letter, and short enough that
 * [physicalName] fits PostgreSQL's 63-byte identifier limit.
 *
 * Structural gate only — pattern and physical length. DDL and jOOQ always render identifiers
 * through `DSL.name()` (quoted); because the pattern guarantees lowercase ASCII, quoting is
 * semantically a no-op and costs nothing.
 */
@JvmInline
value class TableName private constructor(val value: String) {

    /** Physical PostgreSQL table name. The prefix keeps customer tables apart from `sys_*`. */
    fun physicalName(): String = "$PHYSICAL_PREFIX$value"

    companion object {
        private const val PHYSICAL_PREFIX = "u_"
        private const val MAX_PHYSICAL_LENGTH = 63 // PostgreSQL NAMEDATALEN - 1
        private const val MAX_LENGTH = MAX_PHYSICAL_LENGTH - PHYSICAL_PREFIX.length
        private const val TOO_LONG_REASON =
            "longer than $MAX_LENGTH characters (physical name limit $MAX_PHYSICAL_LENGTH)"
        private val PATTERN = Regex("""\A[a-z][a-z0-9_]*\z""")
        private val RESERVED_PREFIXES = listOf("sys_", PHYSICAL_PREFIX)

        fun of(raw: String): TableName {
            if (raw.isEmpty()) reject(raw, "must not be empty")
            if (raw.length > MAX_LENGTH) reject(raw, TOO_LONG_REASON)
            if (!PATTERN.matches(raw)) reject(raw, "must match ${PATTERN.pattern}")
            if (RESERVED_PREFIXES.any(raw::startsWith)) reject(raw, "uses a reserved prefix")
            return TableName(raw)
        }

        private fun reject(raw: String, reason: String): Nothing =
            throw InvalidTableNameException(raw, reason)
    }
}

class InvalidTableNameException(val raw: String, val reason: String) :
    IllegalArgumentException("Invalid table name '$raw': $reason")
```

- [ ] **Step 5: Write the other five modules (build file, descriptor, marker)**

`platform/query/build.gradle.kts`:

```kotlin
description =
    "Vera platform: query engine — jOOQ-based dynamic queries over metadata-defined tables"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(libs.spring.boot.starter.jooq)
    implementation(libs.spring.modulith.api)
}
```

`platform/query/src/main/java/com/brokenfinger/vera/query/package-info.java`:

```java
@org.springframework.modulith.ApplicationModule(displayName = "query", allowedDependencies = {"metadata"})
package com.brokenfinger.vera.query;
```

`platform/query/src/main/kotlin/com/brokenfinger/vera/query/QueryModule.kt`:

```kotlin
package com.brokenfinger.vera.query

object QueryModule {
    const val NAME: String = "query"
}
```

`platform/rule/build.gradle.kts`:

```kotlin
description = "Vera platform: rule engine — business rules, ACL, sandboxed customer scripts"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(project(":platform:query"))
    implementation(libs.spring.boot.starter)
    implementation(libs.spring.modulith.api)
    implementation(libs.graalvm.polyglot)
    runtimeOnly(libs.graalvm.js.community)
}
```

`platform/rule/src/main/java/com/brokenfinger/vera/rule/package-info.java`:

```java
@org.springframework.modulith.ApplicationModule(displayName = "rule", allowedDependencies = {"metadata", "query"})
package com.brokenfinger.vera.rule;
```

`platform/rule/src/main/kotlin/com/brokenfinger/vera/rule/RuleModule.kt`:

```kotlin
package com.brokenfinger.vera.rule

object RuleModule {
    const val NAME: String = "rule"
}
```

`platform/layering/build.gradle.kts`:

```kotlin
description = "Vera platform: layering engine — base vs customer-modified metadata, upgrade merge"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(libs.spring.boot.starter)
    implementation(libs.spring.modulith.api)
}
```

`platform/layering/src/main/java/com/brokenfinger/vera/layering/package-info.java`:

```java
@org.springframework.modulith.ApplicationModule(displayName = "layering", allowedDependencies = {"metadata"})
package com.brokenfinger.vera.layering;
```

`platform/layering/src/main/kotlin/com/brokenfinger/vera/layering/LayeringModule.kt`:

```kotlin
package com.brokenfinger.vera.layering

object LayeringModule {
    const val NAME: String = "layering"
}
```

`apps/itam/build.gradle.kts`:

```kotlin
description =
    "Vera app: IT Asset Management — assets, CIs, lifecycle, identification and reconciliation"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(project(":platform:query"))
    implementation(project(":platform:rule"))
    implementation(libs.spring.boot.starter)
    implementation(libs.spring.modulith.api)
}
```

`apps/itam/src/main/java/com/brokenfinger/vera/itam/package-info.java`:

```java
@org.springframework.modulith.ApplicationModule(displayName = "itam", allowedDependencies = {"metadata", "query", "rule"})
package com.brokenfinger.vera.itam;
```

`apps/itam/src/main/kotlin/com/brokenfinger/vera/itam/ItamModule.kt`:

```kotlin
package com.brokenfinger.vera.itam

object ItamModule {
    const val NAME: String = "itam"
}
```

`ingestion/build.gradle.kts`:

```kotlin
description =
    "Vera ingestion: discovery, monitoring and CSV observations feeding the ITAM reconciliation engine"

dependencies {
    implementation(project(":apps:itam"))
    implementation(libs.spring.boot.starter)
    implementation(libs.spring.modulith.api)
}
```

`ingestion/src/main/java/com/brokenfinger/vera/ingestion/package-info.java`:

```java
@org.springframework.modulith.ApplicationModule(displayName = "ingestion", allowedDependencies = {"itam"})
package com.brokenfinger.vera.ingestion;
```

`ingestion/src/main/kotlin/com/brokenfinger/vera/ingestion/IngestionModule.kt`:

```kotlin
package com.brokenfinger.vera.ingestion

object IngestionModule {
    const val NAME: String = "ingestion"
}
```

- [ ] **Step 6: Format, then run the metadata unit tests**

Run `./gradlew spotlessApply --console=plain -q` first; ktfmt reflows the Kotlin above, and Step 7's line-length verdicts depend on the reflowed shape. Then run `./gradlew :platform:metadata:test --console=plain -q; echo exit=$?`.
Expected: a line `:platform:metadata:test: 16 tests, 0 failed, 0 skipped` (5 accept + 7 reject parameterised cases + 4 named tests) and `exit=0`. If the count differs, read the JUnit XML under `platform/metadata/build/test-results/test/` before changing anything.

- [ ] **Step 7: Run the fast gate for the whole build**

Run: `./gradlew detekt detektMain test archTest --console=plain -q; echo exit=$?` (archTest has no tests yet; it must still configure and pass — every module reports `NO-SOURCE`).
Expected: `exit=0`. Both detekt findings below fired on the first draft of `TableName.of`, which had five inline guard-clause throws; the code above is the settled version.
- `ThrowsCount` (max 3) flagged the guard-clause throws. The fix is configuration, not code: `style.ThrowsCount.excludeGuardClauses: true` in `config/detekt/detekt.yml`, because guard clauses are the early-return style principle 2 asks for. `max` stays 3 and `of` is not restructured into a lookup table.
- `LongMethod` (threshold 11, reported at `>=`) flagged `of` at exactly 11 lines, because ktfmt wraps any guard longer than 100 columns over two lines. The threshold stays 11. Two changes keep `of` short: the throw moved into a private `reject(raw, reason): Nothing` helper, and the one long reason string became the `TOO_LONG_REASON` constant. Every guard then fits on one line and `of` is 7 lines long. `of` holds no `throw` at all now, so `excludeGuardClauses` above is policy for the next guard clause rather than a workaround for this one.
- Any other detekt finding: fix the code to satisfy the rule; report if a rule seems wrong instead of suppressing it.

- [ ] **Step 8: Commit**

```bash
git add platform apps ingestion gradle/libs.versions.toml config/detekt/detekt.yml
git commit -m "feat: add Modulith module skeletons and TableName value object"
```

The `git rm` of the six `.gitkeep` files is part of this commit.

---

### Task 5: Bootstrap application, Flyway baseline, Modulith verification test

**Files:**
- Create: `bootstrap/build.gradle.kts`
- Create: `bootstrap/src/main/kotlin/com/brokenfinger/vera/VeraApplication.kt`
- Create: `bootstrap/src/main/resources/application.yaml`
- Create: `bootstrap/src/main/resources/application-dev.yaml`
- Create: `bootstrap/src/main/resources/db/migration/V20260930_0001__baseline.sql`
- Create: `bootstrap/src/test/kotlin/com/brokenfinger/vera/ModularityTest.kt`
- Delete: `bootstrap/.gitkeep` (`git rm`) — the placeholder that kept the empty directory in git

- [ ] **Step 1: Write the failing modularity test**

`bootstrap/src/test/kotlin/com/brokenfinger/vera/ModularityTest.kt`:

```kotlin
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
```

The block above is ktfmt's output, so `spotlessCheck` passes on it unchanged: ktfmt wrapped the
`containsExactlyInAnyOrder` call onto a line of its own, and the verifier class name sits in a
top-level constant because a string literal cannot be broken and the inline call would have run past
the 120-column detekt limit.

- [ ] **Step 2: Write `bootstrap/build.gradle.kts`**

```kotlin
plugins {
    alias(libs.plugins.spring.boot)
}

description = "Vera bootstrap: assembles all modules into one Spring Boot application"

dependencies {
    implementation(project(":platform:metadata"))
    implementation(project(":platform:query"))
    implementation(project(":platform:rule"))
    implementation(project(":platform:layering"))
    implementation(project(":apps:itam"))
    implementation(project(":ingestion"))

    implementation(libs.spring.boot.starter.webmvc)
    implementation(libs.spring.boot.starter.actuator)
    implementation(libs.spring.boot.starter.validation)
    implementation(libs.spring.boot.starter.jooq)
    implementation(libs.spring.boot.starter.flyway)
    // starter-core also pulls spring-modulith-apt, which is inert here: Gradle ignores annotation
    // processors that arrive on the compile classpath instead of the annotationProcessor one.
    implementation(libs.spring.modulith.starter.core)
    // starter-core stops at the core model. The verifier that reads
    // `spring.modulith.runtime.verification-enabled` ships separately, and without it the property
    // is read by nothing.
    implementation(libs.spring.modulith.runtime)
    runtimeOnly(libs.flyway.postgresql)
    runtimeOnly(libs.postgresql)

    // `testAndDevelopmentOnly` extends nothing, so the BOM the root convention puts on
    // `implementation` does not reach it and bootJar fails to resolve a versionless alias.
    testAndDevelopmentOnly(platform(libs.spring.boot.bom))
    testAndDevelopmentOnly(libs.spring.boot.docker.compose)
    testImplementation(libs.spring.modulith.starter.test)
    // The itest suite has its own configurations and inherits nothing from `implementation`, so the
    // jOOQ and transaction types an integration test touches must be declared again.
    "itestImplementation"(libs.spring.boot.starter.jooq)
}

// Documenter writes relative to the working directory unless told otherwise, and Gradle cannot know
// the result is a task output, so it would disappear on a build-cache hit. Declaring both fixes the
// location and lets Gradle restore the diagrams agents read. The property stays relative: a system
// property is part of the task's cache key, so an absolute path would miss the cache in every other
// worktree or clone. A test task's working directory is the project directory.
val modulithDocs = layout.buildDirectory.dir("spring-modulith-docs")

tasks.named<Test>("test") {
    systemProperty("vera.modulith.docs", "build/spring-modulith-docs")
    outputs.dir(modulithDocs).withPropertyName("modulithDocs")
}

tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {
    archiveFileName.set("vera.jar")
}

// bootJar resolves testAndDevelopmentOnly — the only place a missing BOM shows up (Task 5 review)
tasks.named("check") { dependsOn("bootJar") }
```

Deviation from the original block: `testAndDevelopmentOnly(platform(libs.spring.boot.bom))` was
added. That configuration extends nothing, so the BOM the root convention puts on `implementation`
never reaches it, and the catalog alias is deliberately versionless. `:bootstrap:test` still passed,
because `testRuntimeClasspath` inherits the BOM through `testImplementation`, but `:bootstrap:bootJar`
resolves `testAndDevelopmentOnly` on its own to subtract those files from the jar, and failed with:

```text
Could not resolve all files for configuration ':bootstrap:testAndDevelopmentOnly'.
> Could not find org.springframework.boot:spring-boot-docker-compose:.
```

Handing that one configuration the BOM fixes it and keeps versions out of the catalog. The fast
gate never resolves `testAndDevelopmentOnly`, so `tasks.named("check") { dependsOn("bootJar") }` at
the foot of the file wires the one task that does into `:bootstrap:check`.

- [ ] **Step 3: Write the application class and configuration**

`bootstrap/src/main/kotlin/com/brokenfinger/vera/VeraApplication.kt`:

```kotlin
package com.brokenfinger.vera

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.modulith.Modulithic

@SpringBootApplication @Modulithic(systemName = "Vera") class VeraApplication

fun main(args: Array<String>) {
    runApplication<VeraApplication>(*args)
}
```

One deviation from the original block: ktfmt collapses both annotations onto the class line, because
`class VeraApplication` has no body and the joined line fits in 100 columns. That is the formatter's
output, so `spotlessCheck` requires it. The canonical `runApplication<VeraApplication>(*args)` stands
because Task 3 Step 5 deactivates detekt's `performance > SpreadOperator`.

`bootstrap/src/main/resources/application.yaml`:

```yaml
spring:
  application:
    name: vera
  threads:
    virtual:
      enabled: true
  flyway:
    enabled: true
    locations: classpath:db/migration
    default-schema: vera
    create-schemas: true
  jooq:
    sql-dialect: POSTGRES
  modulith:
    runtime:
      verification-enabled: true   # abort startup if a module boundary is violated
  docker:
    compose:
      enabled: false               # turned on by the dev profile only

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      probes:
        enabled: true

server:
  port: 8080
```

`bootstrap/src/main/resources/application-dev.yaml`:

```yaml
spring:
  docker:
    compose:
      enabled: true
      file: compose.yml
      lifecycle-management: start-only
      profiles:
        active: []                 # add "full" to also start Valkey, Kafka and Keycloak

management:
  endpoint:
    health:
      show-details: always         # dev only: never widen this on the default profile
```

- [ ] **Step 4: Write the Flyway baseline**

`bootstrap/src/main/resources/db/migration/V20260930_0001__baseline.sql`:

```sql
-- Vera baseline. Timestamp versions avoid collisions between parallel worktrees (spec §9).
-- Merged migrations are immutable: never edit this file, add a new V<timestamp>__*.sql instead.

comment on schema vera is 'Vera platform schema: sys_* system catalog tables, u_* customer tables';
```

The original block also ran `create schema if not exists vera;`. Flyway creates the schema itself
from `default-schema` plus `create-schemas`, so that statement only logged `schema "vera" already
exists, skipping` on every boot. Do not add it back.

- [ ] **Step 5: Run the modularity test and see it pass**

Run: `./gradlew :bootstrap:test --console=plain -q; echo exit=$?`
Expected: `:bootstrap:test: 4 tests, 0 failed, 0 skipped`, `exit=0`, and PlantUML files under `bootstrap/build/spring-modulith-docs/`. A failure like `Module 'query' depends on non-exposed type` means a module imported another module's `internal` package — fix the import, never the test.

`spring-modulith-starter-core` pulls api, apt, core and moments but not `spring-modulith-runtime`,
so `spring.modulith.runtime.verification-enabled` in `application.yaml` was read by nothing and a
boundary violation would never have aborted startup. `implementation(libs.spring.modulith.runtime)`
fixes that, and a boot against PostgreSQL 18 then logs `Spring Modulith application module
verification completed successfully.`

`Documenter` reaches the test classpath through `spring-modulith-starter-test`, so the catalog needs
no `spring-modulith-docs` alias, but its output folder has to be declared. Left alone it writes
relative to the working directory and Gradle does not know the directory is a task output, so the
diagrams disappear on a build-cache hit. Step 2 passes the folder in as the `vera.modulith.docs`
system property and registers it with `outputs.dir`. That property value is *relative*
(`build/spring-modulith-docs`), because a system property is part of the test task's build-cache key
and an absolute path would miss the cache in every other worktree or clone; the test reads it with
the same string as its default so an IDE run without the property still works. The test asserts the
seven files
(`components.puml` plus one `module-<name>.puml` per module) are there, and deleting the directory
and re-running `:bootstrap:test` restores it `FROM-CACHE`. `components.puml` holds only the title
until the modules gain Spring beans.

- [ ] **Step 6: Commit**

```bash
git rm bootstrap/.gitkeep
git add bootstrap
git commit -m "feat: add bootstrap application, Flyway baseline and Modulith verification test"
```

---

### Task 6: Architecture tests with ArchUnit (archTest suite)

Konsist was replaced by ArchUnit 1.5.1 in Task 3: Konsist 0.17.3 depends on `kotlin-compiler-embeddable` 2.0.21, which cannot run on the Java 25 test JVM (the same `JavaVersion.parse` crash detekt hit). ArchUnit works on bytecode and embeds no compiler. ArchUnit imports the classes from the archTest runtime classpath, so the rules live once, in `bootstrap` (which depends on every module). Plain JUnit 5 tests are used instead of ArchUnit's `@ArchTest` field style — no reflection on static fields, and the summary listener from Task 3 counts them like any other test.

**Files:**
- Create: `bootstrap/src/archTest/kotlin/com/brokenfinger/vera/arch/ProductionClasses.kt`
- Create: `bootstrap/src/archTest/kotlin/com/brokenfinger/vera/arch/ImportScopeTest.kt`
- Create: `bootstrap/src/archTest/kotlin/com/brokenfinger/vera/arch/LayerRulesTest.kt`
- Create: `bootstrap/src/archTest/kotlin/com/brokenfinger/vera/arch/NamingRulesTest.kt`

Value-class rule removed (2026-09-30): the Kotlin compiler enforces one primary-constructor
parameter on a `value class`, so a rule asserting one instance field can never fire from Kotlin
source. Principle 3, wrapping primitives in domain objects, stays a review item in REVIEW.md and
Plan B rather than a machine rule.

- [ ] **Step 1: Write the shared class import (production classes only)**

`bootstrap/src/archTest/kotlin/com/brokenfinger/vera/arch/ProductionClasses.kt`:

```kotlin
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
```

`ImportOption.DoNotIncludeTests()` carries three patterns, read out of `archunit-1.5.1.jar` with
`javap`: `.*/target/test-classes/.*`, `.*/out/test/.*`, and for Gradle
`.*/build/classes/([^/]+/)?(test|[^/]+Test)s?/.*`. The `[^/]+Test` branch of that last one already
matches `build/classes/kotlin/archTest`, so the archTest suite excludes itself. `itest` matches no
branch — it is neither `test` nor a name ending in `Test` — so it is the one suite that needs
naming, and the pattern is anchored on the output directory rather than testing the path for a bare
`/itest/` substring that an unrelated source path could contain.

`ROOT_PACKAGE` is public because `ImportScopeTest` and `NamingRulesTest` both need the root and
three copies of the same string would drift.

- [ ] **Step 2: Assert the import reaches every module**

`bootstrap/src/archTest/kotlin/com/brokenfinger/vera/arch/ImportScopeTest.kt`:

```kotlin
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
```

This is the test that keeps the other four honest. ArchUnit imports from the archTest runtime
classpath, which is exactly bootstrap's dependency list, so a seventh module added to
`settings.gradle.kts` but not to `bootstrap/build.gradle.kts` contributes no classes and every rule
passes over it without a word. The proof is in Step 5.

- [ ] **Step 3: Write the failing layer-rules test**

`bootstrap/src/archTest/kotlin/com/brokenfinger/vera/arch/LayerRulesTest.kt`:

```kotlin
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
```

Both `because` reasons sit in top-level private constants, the same move `ModularityTest` makes for
`RUNTIME_VERIFIER` and for the same reason: a string literal cannot be broken across lines, and
inline these two wrap past the 120-column `MaxLineLength` detekt enforces. The
`// the Modulith @NamedInterface descriptor …` comment moved above `.doNotHaveSimpleName(…)` because
ktfmt pushed the argument onto its own line and left a trailing comment dangling after the closing
paren.

`.allowEmptyShould(true)` on the exception rule is deliberate: `InvalidTableNameException` is the
only class it matches today, and the rule should not start failing the build if that class moves.
The silent-empty risk that guard opens up is covered by `ImportScopeTest`, not by leaving the rule
brittle.

The `package-info` exclusion is load-bearing, not defensive. Running the same rule without it fails
with exactly one violation:

```text
Architecture Violation [Priority: MEDIUM] - Rule 'no classes that reside in a package '..domain..' should depend on classes that reside in any package ['org.springframework..', 'org.jooq..', 'jakarta..']' was violated (1 times):
Class <com.brokenfinger.vera.metadata.domain.package-info> is annotated with <org.springframework.modulith.NamedInterface> in (package-info.java:0)
```

- [ ] **Step 4: Write the failing naming-rules test**

`bootstrap/src/archTest/kotlin/com/brokenfinger/vera/arch/NamingRulesTest.kt`:

```kotlin
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
```

No API adaptation was needed: `doNotHaveSimpleName`, `areNotInterfaces()` and
`allowEmptyShould(true)` all exist in ArchUnit 1.5.1 with the shapes above.

The custom condition reports through `item.description` and `item.sourceCodeLocation` rather than
`item.name`, so its violations read like the built-in rules and name a file and line an agent can
jump to. Forcing one by adding an `object NestedModule` under `metadata.domain` gives:

```text
NamingRulesTest > module marker objects live in a direct sub-package of the root() FAILED
    java.lang.AssertionError: Architecture Violation [Priority: MEDIUM] - Rule 'classes that have simple name ending with 'Module' should reside in a direct sub-package of com.brokenfinger.vera' was violated (1 times):
    Class <com.brokenfinger.vera.metadata.domain.NestedModule> is in com.brokenfinger.vera.metadata.domain, in (NestedModule.kt:0)
```

The condition and the test are named for a *direct sub-package* because that is what the check
measures: `com.brokenfinger.vera.metadata` passes and `com.brokenfinger.vera.metadata.domain` does
not. "Directly under the root" read as though the root package itself qualified.

`SimpleConditionEvent.violated` is statically imported to keep the `events.add(…)` line under
ktfmt's 100 columns; qualified, ktfmt split it across five lines.

- [ ] **Step 5: Run the archTest suite and prove the rules fire**

Run: `JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home ./gradlew :bootstrap:archTest --rerun-tasks --console=plain -q; echo exit=$?`
Observed: `:bootstrap:archTest: 5 tests, 0 failed, 0 skipped`, `exit=0` — two layer rules, two naming
rules, one import-scope test.

A probe listing every imported class confirmed the two import options: 18 production classes, no
class whose name ends in `Test`, and nothing from `com.brokenfinger.vera.arch`. The list is
`VeraApplication`, `VeraApplicationKt`, the six `XxxModule` markers, the six `package-info`
descriptors, and `metadata.domain`'s `TableName`, `TableName$Companion` and
`InvalidTableNameException`. The count is unchanged from the version that tested the path for an
`/archTest/` substring, which is what proves `DoNotIncludeTests()` was already covering that suite.

Commenting out `implementation(project(":ingestion"))` in `bootstrap/build.gradle.kts` fails
`ImportScopeTest` and nothing else, which is the whole point — the four architecture rules stayed
green over a module that had vanished:

```text
ImportScopeTest > every module reaches the importer() FAILED
    java.lang.AssertionError:
    Expecting LinkedHashSet:
      ["layering", "rule", "metadata", "query", "itam"]
    to contain:
      ["metadata", "query", "rule", "layering", "itam", "ingestion"]
    but could not find the following element(s):
      ["ingestion"]
```

A throwaway `platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/domain/Bad.kt` holding
`class BadException(msg: String) : RuntimeException(msg)` fires the exception rule with `exit=1`:

```text
LayerRulesTest > domain exceptions extend IllegalArgumentException or IllegalStateException() FAILED
    java.lang.AssertionError: Architecture Violation [Priority: MEDIUM] - Rule 'classes that reside in a package '..domain..' and have simple name ending with 'Exception' should be assignable to java.lang.IllegalArgumentException or should be assignable to java.lang.IllegalStateException, because bad input is IllegalArgumentException, bad state is IllegalStateException (docs/development-rules.md, naming)' was violated (1 times):
    Class <com.brokenfinger.vera.metadata.domain.BadException> is not assignable to java.lang.IllegalArgumentException in (Bad.kt:0) and Class <com.brokenfinger.vera.metadata.domain.BadException> is not assignable to java.lang.IllegalStateException in (Bad.kt:0)
```

Each proof ends with the file or the edit reverted, `exit=0` and a clean `git status --short`.

- [ ] **Step 6: Run the fast gate and commit**

```bash
./gradlew spotlessCheck detekt detektMain test archTest -q; echo exit=$?
git -C /Users/yu-sun00/Desktop/vera add bootstrap/src/archTest
git -C /Users/yu-sun00/Desktop/vera commit -m "test: add ArchUnit architecture rules for layering and naming"
```

The gate exits 0. detekt does read the new sources — its `bootstrap` report counts 6 Kotlin files
(`VeraApplication.kt`, `ModularityTest.kt` and the four archTest files) and 0 code smells — so the
`**/archTest/**` entries Task 3 added to the `MagicNumber` and `TooManyFunctions` excludes are what
keep the suite quiet; no rule was suppressed to get there.

---

### Task 7: Agent entry-point scripts

Agents never call Gradle directly in CLAUDE.md flows; they call these. Each script prints a final `RESULT <name> exit=<code> seconds=<n>` line so a subagent can quote it as evidence.

**Files:**
- Create: `scripts/lib.sh`, `scripts/check.sh`, `scripts/test.sh`, `scripts/itest.sh`, `scripts/build.sh`

Project-directory fix (2026-09-30): the version of `run_gradle` first drafted called
`"$ROOT/gradlew" --console=plain -q "$@"` with no project-dir flag. Gradle's wrapper resolves the
build root from the *caller's current directory*, not from the location of the `gradlew` script it
runs, so every script failed immediately when invoked by absolute path from outside the repository:

```text
FAILURE: Build failed with an exception.
* What went wrong:
Directory '/private/tmp' does not contain a Gradle build.
```

Found while proving the Step 4 CWD-independence requirement below. Fixed by adding `-p "$ROOT"` so
the project directory is always `$ROOT`, regardless of where the script is invoked from. The fenced
block below is the version actually committed.

- [x] **Step 1: Write the shared helper**

`scripts/lib.sh`:

```bash
#!/usr/bin/env bash
[ -n "${BASH_VERSION:-}" ] || { echo "scripts/*.sh require bash, not sh." >&2; exit 2; }
# Shared helpers. Source only from scripts/*.sh (bash).
# Exit codes across the scripts: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
set -uo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || ROOT=""
if [ -z "$ROOT" ] || [ ! -x "$ROOT/gradlew" ]; then
  echo "lib.sh: repository root not found from $(dirname "${BASH_SOURCE[0]}") (not a git checkout, or gradlew missing)." >&2
  echo "RESULT bootstrap exit=2 seconds=0"
  exit 2
fi
export JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home}"

# run_gradle <label> <gradle args...> — runs Gradle, prints the result line, returns its exit code.
run_gradle() {
  local label="$1"; shift
  local start=$SECONDS
  "$ROOT/gradlew" -p "$ROOT" --console=plain -q "$@"
  local code=$?
  echo "RESULT ${label} exit=${code} seconds=$((SECONDS - start))"
  return $code
}
```

- [x] **Step 2: Write `scripts/check.sh` (fast gate, target < 60 s)**

```bash
#!/usr/bin/env bash
# Fast quality gate: formatting, detekt, unit tests, architecture tests. No Docker.
# Callers: Stop hook (.claude/hooks/stop-gate.sh), pre-push gate, CI. Exit 0 means "safe to stop".
# Exit codes: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
. "$(dirname "$0")/lib.sh"
[ $# -eq 0 ] || { echo "check.sh takes no arguments; use ./scripts/test.sh :module:path to scope tests." >&2; exit 2; }

# Spotless invalidates the configuration cache on every .kt edit, so it runs in its own invocation
# and the detekt/test cache entry stays warm (Task 3 quality review).
run_gradle format spotlessCheck || { code=$?; echo "check.sh: formatting failed — run ./gradlew spotlessApply, then rerun." >&2; exit $code; }

# detekt = every source set without type resolution; detektMain = production sources with type
# resolution (UnsafeCallOnNullableType and ImplicitDefaultLocale only fire here). Both are on `check`.
run_gradle check detekt detektMain test archTest
code=$?
if [ $code -ne 0 ]; then
  echo "check.sh failed. detekt: build/reports/detekt/*.md · tests: build/test-results/<suite>/ (assertion printed above) · archTest: fix the code, not the rule." >&2
fi
exit $code
```

- [x] **Step 3: Write `scripts/test.sh`, `scripts/itest.sh`, `scripts/build.sh`**

`scripts/test.sh`:

```bash
#!/usr/bin/env bash
# Unit tests only. Pass a module path to scope: ./scripts/test.sh :platform:metadata
# Callers: agents scoping a module.
# Exit codes: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
. "$(dirname "$0")/lib.sh"
if [ $# -gt 0 ]; then run_gradle test "$1:test"; else run_gradle test test; fi
```

`scripts/itest.sh`:

```bash
#!/usr/bin/env bash
# Integration tests with Testcontainers (needs Docker). Pass a module path to scope.
# Callers: agents, CI itest job.
# Exit codes: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
. "$(dirname "$0")/lib.sh"
if ! docker info >/dev/null 2>&1; then
  echo "RESULT itest exit=3 seconds=0"
  echo "Docker unavailable (daemon down or CLI missing). Start Docker, then rerun. Integration tests never fall back to H2." >&2
  exit 3
fi
if [ $# -gt 0 ]; then run_gradle itest "$1:itest"; else run_gradle itest itest; fi
```

`scripts/build.sh`:

```bash
#!/usr/bin/env bash
# Assemble the application jar without running tests (tests are check.sh / itest.sh).
# Callers: agents, CI build job.
# Exit codes: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
. "$(dirname "$0")/lib.sh"
[ $# -eq 0 ] || { echo "build.sh takes no arguments." >&2; exit 2; }
run_gradle build :bootstrap:bootJar
```

- [x] **Step 4: Make executable and run everything end to end**

Run: `chmod +x scripts/check.sh scripts/test.sh scripts/itest.sh scripts/build.sh && ./scripts/check.sh; echo exit=$?` (`lib.sh` is sourced, never executed, so it stays 100644), twice in a row (cold, then warm).

Observed (cold): `RESULT format exit=0 seconds=1`, `RESULT check exit=0 seconds=1`, `exit=0`.
Observed (warm): `RESULT format exit=0 seconds=0`, `RESULT check exit=0 seconds=1`, `exit=0`.
Both `<n>` readings are far under the 60 s target, so no progress.md risk entry is needed for the
Stop hook (spec §6 row 1). The Gradle daemon was already warm from the Task 1–6 runs, so every task
in the `check` graph was `UP-TO-DATE`; a genuinely cold daemon would run longer. The daemon is JDK 21
(see Task 3 Step 6b); the launcher JVM is whatever `JAVA_HOME` in `lib.sh` points at.

`./scripts/test.sh :platform:metadata`, `./scripts/itest.sh` and `./scripts/build.sh` each ran clean:

```text
RESULT test exit=0 seconds=1
RESULT itest exit=0 seconds=1
RESULT build exit=0 seconds=0
```

`itest` is NO-SOURCE today — Task 8 adds the Testcontainers sources. Docker Desktop was running, so
this exercised the exit-0 path, not the exit-3 Docker-not-running path.

CWD-independence: ran `test.sh`, `check.sh` and `build.sh` by absolute path from three directories
outside the repository (the agent's scratch directory, `/tmp`, `$HOME`). All three passed with
`exit=0` after the project-directory fix above; before the fix, all three failed with the `does not
contain a Gradle build` error shown above, because `ROOT` was resolved correctly but never passed to
`gradlew` as the project directory.

`JAVA_HOME` default: with `JAVA_HOME` unset (`env -u JAVA_HOME`), sourcing `lib.sh` set it to
`/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home`, and `./gradlew --version` under
that same env printed `Launcher JVM:  25.0.3 (Eclipse Adoptium 25.0.3+9-LTS)`. `env -u JAVA_HOME
./scripts/check.sh` passed with `exit=0`. The ambient shell's own `JAVA_HOME` (a JDK 21 build,
unrelated to this default) was unchanged afterward, confirming the default only fills a gap and
never overrides an already-set `JAVA_HOME`.

Negative proof: appended two trailing spaces to the `object MetadataModule {` line in
`platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/MetadataModule.kt`, then ran
`check.sh`:

```text
RESULT format exit=1 seconds=1
check.sh: formatting failed — run ./gradlew spotlessApply, then rerun.
exit=1
```

`git checkout -- platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/MetadataModule.kt`
restored the file (`git status --short` clean before and after), and the rerun passed:

```text
RESULT format exit=0 seconds=0
RESULT check exit=0 seconds=1
exit=0
```

`shellcheck` is not installed in this environment (`command -v shellcheck` exits 1, no Homebrew keg
either); noted rather than run.

**Hardening (review fixes, 2026-09-30).** `lib.sh` now refuses non-bash shells (exit 2), validates the
repository root and `gradlew` (prints `RESULT bootstrap exit=2 seconds=0`, exit 2), and is not executable.
`check.sh` propagates Gradle's own exit code from the format step, prints one compact failure hint and
rejects arguments; `build.sh` rejects arguments; `itest.sh` prints `RESULT itest exit=3 seconds=0` to stdout
when Docker is unavailable. Exit codes: 0 ok, 1 Gradle failure, 2 environment, 3 Docker unavailable.
Proofs:

- From `/tmp` by absolute path: `RESULT format exit=0`, `RESULT check exit=0`; `test.sh :platform:metadata` -> `RESULT test exit=0`; `itest.sh` -> `RESULT itest exit=0`; `build.sh` -> `RESULT build exit=0`.
- Bash guard: macOS `/bin/sh` is bash 3.2 in POSIX mode, so `BASH_VERSION` is set and it never triggers the guard; `dash` (Ubuntu's `sh`) is the real test. `/bin/dash scripts/check.sh` -> `scripts/*.sh require bash, not sh.`, `exit=2`.
- Copy of `scripts/` outside any git checkout: `lib.sh: repository root not found ...`, `RESULT bootstrap exit=2 seconds=0`, `exit=2`.
- `DOCKER_HOST=tcp://127.0.0.1:9 scripts/itest.sh 2>/dev/null` -> stdout `RESULT itest exit=3 seconds=0`, `exit=3`.
- `scripts/check.sh :platform:metadata` -> `check.sh takes no arguments; ...`, `exit=2`.
- Temporary failing test (`assertEquals(1, 2)`): output contains `ProbeFailTest > probeFails() FAILED` and `expected: <1> but was: <2>` and ends with `RESULT check exit=1 seconds=1` plus the hint; Gradle's failure boilerplate is about 12 lines, so `tail -n 5` shows only the RESULT line and hint, and the test name needs a longer tail (about 30 lines). Probe deleted, tree clean.
- `git ls-files -s scripts`: `lib.sh` 100644, the other four 100755.

- [x] **Step 5: Commit**

```bash
git add scripts
git commit -m "build: add agent entry-point scripts with result lines"
```

---

### Task 8: Docker Compose demo stack and Testcontainers base

**Files:**
- Create: `compose.yml`
- Create: `bootstrap/src/itest/kotlin/com/brokenfinger/vera/TestcontainersConfiguration.kt`
- Create: `bootstrap/src/itest/kotlin/com/brokenfinger/vera/ApplicationBootsTest.kt`
- Create: `bootstrap/src/itest/resources/application-itest.yaml`
- Modify: `bootstrap/build.gradle.kts` (bootRun working directory)

- [ ] **Step 1: Write `compose.yml`**

Every tag was checked with `docker manifest inspect <image> >/dev/null && echo ok` on 2026-09-30: `postgres:18-alpine`, `valkey/valkey:9-alpine`, `apache/kafka:4.2.1` and `quay.io/keycloak/keycloak:26.7` all resolve, so no substitution was needed.

```yaml
# Human demo stack. Tests never use this file (Testcontainers only, spec §8).
# `docker compose up -d` starts PostgreSQL only; `docker compose --profile full up -d` adds the rest.
name: vera

services:
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_DB: vera
      POSTGRES_USER: vera
      POSTGRES_PASSWORD: vera
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vera -d vera"]
      interval: 5s
      timeout: 3s
      retries: 10
    volumes:
      - pgdata:/var/lib/postgresql

  valkey:
    image: valkey/valkey:9-alpine
    profiles: ["full"]
    labels:
      org.springframework.boot.service-connection: redis   # image name is not "redis"; tell Boot what it is
    ports:
      - "6379:6379"

  kafka:
    # no data volume: topics are demo-only and vanish on recreate
    image: apache/kafka:4.2.1
    profiles: ["full"]
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      CLUSTER_ID: vera-local-kraft-cluster-000
    ports:
      - "9092:9092"

  keycloak:
    image: quay.io/keycloak/keycloak:26.7
    profiles: ["full"]
    command: ["start-dev", "--http-port=8081"]
    environment:
      KC_BOOTSTRAP_ADMIN_USERNAME: admin
      KC_BOOTSTRAP_ADMIN_PASSWORD: admin
    ports:
      - "8081:8081"

volumes:
  pgdata:
```

- [ ] **Step 2: Write the Testcontainers configuration**

`bootstrap/src/itest/kotlin/com/brokenfinger/vera/TestcontainersConfiguration.kt`:

```kotlin
package com.brokenfinger.vera

import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.springframework.context.annotation.Bean
import org.testcontainers.postgresql.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName

/** One PostgreSQL 18 container per JVM, wired into the datasource by @ServiceConnection. */
@TestConfiguration(proxyBeanMethods = false)
class TestcontainersConfiguration {

    @Bean
    @ServiceConnection
    fun postgres(): PostgreSQLContainer =
        PostgreSQLContainer(DockerImageName.parse("postgres:18-alpine"))
            .withDatabaseName("vera")
            .withUsername("vera")
            .withPassword("vera")
}
```

`bootstrap/src/itest/resources/application-itest.yaml` (health details are otherwise shown only in the dev profile; no HTTP assertions use them yet):

```yaml
spring:
  docker:
    compose:
      enabled: false

management:
  endpoint:
    health:
      show-details: always
```

- [ ] **Step 3: Write the failing boot test**

`bootstrap/src/itest/kotlin/com/brokenfinger/vera/ApplicationBootsTest.kt`:

```kotlin
package com.brokenfinger.vera

import org.assertj.core.api.Assertions.assertThat
import org.jooq.DSLContext
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.ApplicationContext
import org.springframework.context.annotation.Import

@SpringBootTest
@Import(TestcontainersConfiguration::class)
class ApplicationBootsTest(
    @Autowired private val dsl: DSLContext,
    @Autowired private val context: ApplicationContext,
) {

    @Test
    fun `context starts, Flyway ran and the vera schema exists in PostgreSQL 18`() {
        val version =
            dsl.fetchSingle("select current_setting('server_version_num')::int")
                .get(0, Int::class.java)
        assertThat(version).isGreaterThanOrEqualTo(180000)

        val schemaExists =
            dsl.fetchSingle(
                    "select exists (select 1 from information_schema.schemata where schema_name = 'vera')"
                )
                .get(0, Boolean::class.java)
        assertThat(schemaExists).isTrue()

        // Flyway writes a versionless "schema creation" row plus one row per migration;
        // count migrations only.
        val applied =
            dsl.fetchSingle(
                    "select count(*) from vera.flyway_schema_history where success and version is not null"
                )
                .get(0, Int::class.java)
        assertThat(applied).isEqualTo(1)
    }

    @Test
    fun `Modulith runtime verification is active, not just configured`() {
        // Task 5 review: starter-core does not ship spring-modulith-runtime; without it the
        // property is read by nothing. The verifier type is package-private, so assert on the bean
        // name its @Bean method registers. That bean is conditional on
        // spring.modulith.runtime.verification-enabled, so this proves the jar and the property.
        assertThat(context.containsBean("applicationModuleVerifier")).isTrue()
    }
}
```

`fetchSingle` instead of `fetchOne(...)!!`: `detektItest` (type resolution) reports `UnsafeCallOnNullableType` on `!!`, and `fetchSingle` already throws when the row is missing.

The verifier is `SpringModulithRuntimeAutoConfiguration$RuntimeApplicationModuleVerifier` in `spring-modulith-runtime-2.1.1.jar`: a package-private nested class, so Kotlin cannot name it. Its `@Bean` method is `applicationModuleVerifier` and is `@ConditionalOnProperty("spring.modulith.runtime.verification-enabled", matchIfMissing = false)`, so the test asserts `context.containsBean("applicationModuleVerifier")`. Proof the assertion bites: with `implementation(libs.spring.modulith.runtime)` removed from `bootstrap/build.gradle.kts`, `./scripts/itest.sh :bootstrap` reports `Modulith runtime verification is active, not just configured() FAILED` / `Expecting value to be true but was false` / `:bootstrap:itest: 2 tests, 1 failed, 0 skipped` / `RESULT itest exit=1`.

- [ ] **Step 4: Run the integration test**

Run: `./scripts/itest.sh :bootstrap; echo exit=$?`
Expected: `:bootstrap:itest: 2 tests, 0 failed, 0 skipped`, `RESULT itest exit=0 ...`, `exit=0`. First run pulls `postgres:18-alpine` (about 40 s). If Flyway did not run (`flyway_schema_history` missing), the flyway starter or `flyway-database-postgresql` is missing from `bootstrap/build.gradle.kts` — Boot 4 fails silently here (spec §11 traps).

Reuse removed (2026-09-30): fresh container per test JVM (~0.9 s).

- [ ] **Step 5: Start the demo stack and boot the app in the dev profile**

`bootRun` runs in `bootstrap/`, so `spring.docker.compose.file: compose.yml` from `application-dev.yaml` fails with `'files' content [compose.yml] must exist`. Add to `bootstrap/build.gradle.kts`, before the `check` wiring:

```kotlin
// application-dev.yaml names `compose.yml`, which lives in the repository root. bootRun otherwise
// starts in bootstrap/ and Boot fails with "'files' content [compose.yml] must exist".
tasks.named<org.springframework.boot.gradle.tasks.run.BootRun>("bootRun") {
    workingDir = rootDir
}
```

Run:

```bash
docker compose up -d postgres
docker compose ps --format '{{.Name}} {{.Status}}'   # wait for "(healthy)"
SPRING_PROFILES_ACTIVE=dev ./gradlew :bootstrap:bootRun &   # stop it after the health check
curl -s localhost:8080/actuator/health
docker compose down
```

Expected: `vera-postgres-1 Up ... (healthy)`; the app logs `Successfully applied 1 migration to schema "vera"` and `Started VeraApplicationKt`; the health response (trimmed) is

```json
{"status": "UP", "components": {"db": {"status": "UP", "details": {"database": "PostgreSQL", "validationQuery": "isValid()"}}, "livenessState": {"status": "UP"}, "readinessState": {"status": "UP"}, ...}}
```

then containers removed. (No `-v`: volumes are kept; `compose down -v` is a blocked command in the harness.)

- [ ] **Step 6: Commit**

```bash
git add compose.yml bootstrap/src/itest bootstrap/build.gradle.kts
git commit -m "test: add Testcontainers PostgreSQL 18 base and compose demo stack"
```

---

### Task 9: PoC 1 — transactional DDL with jOOQ on PostgreSQL 18

Proves the design premise from the origin chat: "metadata record + real table creation in one transaction, both or neither."

**Files:**
- Create: `bootstrap/src/itest/kotlin/com/brokenfinger/vera/poc/TransactionalDdlPocTest.kt`

- [ ] **Step 1: Write the failing test**

```kotlin
package com.brokenfinger.vera.poc

import com.brokenfinger.vera.TestcontainersConfiguration
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.jooq.DSLContext
import org.jooq.Field
import org.jooq.Table
import org.jooq.impl.DSL
import org.jooq.impl.SQLDataType
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import
import org.springframework.transaction.support.TransactionTemplate

/**
 * PoC 1: DDL and DML in one transaction, both or neither.
 *
 * A catalog-row insert into a pre-existing table rolling back with the DDL is verified by the first
 * Phase 1 metadata ticket.
 */
@SpringBootTest
@Import(TestcontainersConfiguration::class)
class TransactionalDdlPocTest(
    @Autowired private val dsl: DSLContext,
    @Autowired private val tx: TransactionTemplate,
) {

    @Test
    fun `create table inside a rolled-back transaction leaves no table behind`() {
        val table = uniqueTable("u_poc_rollback")

        assertThatThrownBy {
                tx.execute {
                    createTable(table)
                    dsl.insertInto(table).columns(ID).values(1L).execute()
                    error("simulated failure after DDL")
                }
            }
            .isInstanceOf(IllegalStateException::class.java)
            .hasMessage("simulated failure after DDL")

        assertThat(exists(table)).isFalse()
    }

    @Test
    fun `create table inside a committed transaction is visible afterwards`() {
        val table = uniqueTable("u_poc_commit")
        try {
            tx.execute { createTable(table) }

            assertThat(exists(table)).isTrue()
        } finally {
            dsl.dropTableIfExists(table).execute()
        }
    }

    private fun createTable(table: Table<*>) =
        dsl.createTable(table).column(ID).primaryKey(ID).execute()

    // to_regclass gets the rendered, quoted name as a bind value; no SQL is concatenated.
    private fun exists(table: Table<*>): Boolean =
        dsl.select(
                DSL.field("to_regclass({0}) is not null", Boolean::class.java, dsl.render(table))
            )
            .fetchSingle()
            .value1()

    private companion object {
        val ID: Field<Long> = DSL.field(DSL.name("id"), SQLDataType.BIGINT.notNull())

        // A unique name per run keeps the tests independent of order and of earlier failed runs.
        fun uniqueTable(prefix: String): Table<*> =
            DSL.table(DSL.name("vera", "${prefix}_${System.nanoTime()}"))
    }
}
```

Design notes:
- Every table name is unique per run (`<prefix>_<System.nanoTime()>`), so the tests do not depend on order or on leftovers from an earlier failed run; the committed table is dropped in `finally`.
- Identifiers go through `DSL.name(...)` / `DSL.table(...)` and DDL through `dsl.createTable(...)` / `dsl.dropTableIfExists(...)`, the same policy `TableName` documents (Task 4). The existence check passes the rendered, quoted name to `to_regclass` as a bind value.
- `fetchSingle` instead of `fetchOne(...)!!`, and `error(...)` instead of `throw IllegalStateException(...)`: `detektItest` reports `UnsafeCallOnNullableType` and `UseCheckOrError` otherwise.
- The annotations are exactly `ApplicationBootsTest`'s (`@SpringBootTest` + `@Import(TestcontainersConfiguration::class)`), so both classes share one cached context and one container. Do not add `@MockitoBean`, `@TestPropertySource`, `@DirtiesContext` or a different `@Import` here: each changes the context cache key and starts a second PostgreSQL.

- [ ] **Step 2: Run it**

Run: `./scripts/itest.sh :bootstrap; echo exit=$?`
Expected: `:bootstrap:itest: 4 tests, 0 failed, 0 skipped`, `exit=0`. A rollback test that finds the table means the datasource is in autocommit for DDL — check that `TransactionTemplate` is the Boot-provided bean and jOOQ's `DSLContext` uses the Spring transaction-aware datasource (it does with `spring-boot-starter-jooq`; do not create a second `DSLContext`).

Single-container proof (2026-09-30): `./gradlew :bootstrap:itest --rerun -i` logs `Container postgres:18-alpine started` exactly once and `Starting ... Test using` exactly once (only `ApplicationBootsTest` starts a context; `TransactionalDdlPocTest` reuses it).

Meaningfulness proof (2026-09-30), each change reverted afterwards:
- Moving `error(...)` out of `tx.execute { }` (the DDL commits, then the exception is thrown) → `create table inside a rolled-back transaction leaves no table behind() FAILED` / `Expecting value to be false but was true` / `:bootstrap:itest: 4 tests, 1 failed, 0 skipped`.
- Deleting the `error(...)` line → the same test fails with `Expecting code to raise a throwable.`

- [ ] **Step 3: Commit**

```bash
git add bootstrap/src/itest/kotlin/com/brokenfinger/vera/poc/TransactionalDdlPocTest.kt
git commit -m "test: PoC 1 transactional DDL rollback on PostgreSQL 18 via jOOQ"
```

---

### Task 10: PoC 2 — GraalJS sandbox on the stock JDK

**Files:**
- Create: `platform/rule/src/main/kotlin/com/brokenfinger/vera/rule/sandbox/ScriptSandbox.kt`
- Create: `platform/rule/src/main/kotlin/com/brokenfinger/vera/rule/sandbox/ScriptException.kt`
- Create: `platform/rule/src/test/kotlin/com/brokenfinger/vera/rule/sandbox/ScriptSandboxTest.kt`

- [ ] **Step 1: Write the failing tests**

```kotlin
package com.brokenfinger.vera.rule.sandbox

import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.time.Duration
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Assertions.assertTimeoutPreemptively
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

class ScriptSandboxTest {

    // A generous wall clock: interpreter-only GraalJS on a slow CI runner must not turn a size or
    // contract check into a timeout. Timing tests build their own sandbox with a short timeout.
    private val sandbox = ScriptSandbox(statementLimit = 200_000, timeout = SIZE_BUDGET)

    @Test
    fun `returns a JSON string produced by the script`() {
        val out = sandbox.run("""JSON.stringify({ ok: true, n: 1 + 1 })""")
        assertThat(out).isEqualTo("""{"ok":true,"n":2}""")
    }

    @Test
    fun `host access is blocked - Java is not defined`() {
        assertThatThrownBy { sandbox.run("Java.type('java.lang.System').exit(1)") }
            .isInstanceOf(ScriptFailedException::class.java)
            .hasMessageContaining("Java is not defined")
    }

    @Test
    fun `IO is blocked - no file or network access`() {
        assertThatThrownBy { sandbox.run("import('/etc/passwd'); 'unreached'") }
            .isInstanceOf(ScriptFailedException::class.java)
            .hasMessageContaining("Operation is not allowed for: /etc/passwd")
    }

    @Test
    fun `runaway loops are cut by the statement limit`() {
        assertTimeoutPreemptively(Duration.ofSeconds(5)) {
            assertThatThrownBy { sandbox.run("while (true) {}") }
                .isInstanceOf(ScriptLimitException::class.java)
                .hasMessageContaining("Statement count limit of 200000 exceeded")
        }
    }

    @Test
    fun `scripts past the wall-clock timeout are cancelled by the watchdog`() {
        val unbounded = ScriptSandbox(Long.MAX_VALUE, Duration.ofMillis(500))
        assertTimeoutPreemptively(Duration.ofSeconds(5)) {
            val started = System.nanoTime()
            assertThatThrownBy { unbounded.run("while (true) {}") }
                .isInstanceOf(ScriptTimeoutException::class.java)
                .hasMessageContaining("PT0.5S")
            val elapsed = Duration.ofNanos(System.nanoTime() - started)
            assertThat(elapsed).isLessThan(Duration.ofSeconds(1))
        }
    }

    @Test
    fun `an interrupted caller cancels the script and keeps its interrupt flag`() {
        val unbounded = ScriptSandbox(Long.MAX_VALUE, Duration.ofSeconds(10))
        assertTimeoutPreemptively(Duration.ofSeconds(5)) {
            val caller = Thread.currentThread()
            Thread.ofPlatform().start {
                Thread.sleep(200)
                caller.interrupt()
            }
            val started = System.nanoTime()
            assertThatThrownBy { unbounded.run("while (true) {}") }
                .isInstanceOf(ScriptInterruptedException::class.java)
            val elapsed = Duration.ofNanos(System.nanoTime() - started)
            assertThat(elapsed).isLessThan(Duration.ofSeconds(1))
            assertThat(Thread.interrupted()).isTrue()
            assertThat(unbounded.run("JSON.stringify(1)")).isEqualTo("1")
        }
    }

    @Test
    fun `scripts cannot write to the host stdout or stderr`() {
        val captured = ByteArrayOutputStream()
        val out = System.out
        val err = System.err
        System.setOut(PrintStream(captured, true))
        System.setErr(PrintStream(captured, true))
        try {
            sandbox.run(
                "if (typeof print === 'function') print('LEAK');" +
                    "if (typeof console === 'object') console.log('LEAK');" +
                    "JSON.stringify(1)"
            )
        } finally {
            System.setOut(out)
            System.setErr(err)
        }
        assertThat(captured.toString()).isEmpty()
    }

    @Test
    fun `sources over 64 KiB are rejected before evaluation`() {
        assertThatThrownBy { sandbox.run(" ".repeat(64 * 1024 + 1)) }
            .isInstanceOf(ScriptLimitException::class.java)
            .hasMessageContaining("Script source is 65537 characters; the limit is 65536")
    }

    @Test
    fun `results over 1 MiB are rejected`() {
        assertTimeoutPreemptively(SIZE_GUARD) {
            assertThatThrownBy { sandbox.run("'x'.repeat(1024 * 1024 + 1)") }
                .isInstanceOf(ScriptLimitException::class.java)
                .hasMessageContaining("Script result is 1048577 characters; the limit is 1048576")
        }
    }

    @ParameterizedTest
    @CsvSource(
        delimiter = '|',
        value = ["42|number", "undefined|undefined", "({a:1})|Object", "new String('x')|String"],
    )
    fun `non-string results break the contract`(script: String, jsType: String) {
        assertThatThrownBy { sandbox.run(script) }
            .isInstanceOf(ScriptContractException::class.java)
            .hasMessage("Script must return a string but returned $jsType")
    }

    @Test
    fun `errors thrown by the script surface as a sandbox exception`() {
        assertThatThrownBy { sandbox.run("throw new Error('boom')") }
            .isInstanceOf(ScriptFailedException::class.java)
            .hasMessage("Error: boom")
    }

    @Test
    fun `error messages are cut to 4 KiB and drop the oversized cause`() {
        assertTimeoutPreemptively(SIZE_GUARD) {
            assertThatThrownBy { sandbox.run("throw new Error('x'.repeat(100000))") }
                .isInstanceOf(ScriptFailedException::class.java)
                .hasMessageEndingWith("… [truncated 95911 chars]")
                .hasNoCause()
                .satisfies({ assertThat(it.message).hasSizeLessThan(4200) })
        }
    }

    @Test
    fun `host heap exhaustion is not reported as a script limit`() {
        assertTimeoutPreemptively(SIZE_GUARD) {
            assertThatThrownBy { sandbox.run("'x'.repeat(2 ** 29)") }
                .isInstanceOf(ScriptHostExhaustedException::class.java)
                .hasMessage("Java heap space")
            assertThat(sandbox.run("JSON.stringify(1)")).isEqualTo("1")
        }
    }

    @Test
    fun `engine-specific globals are removed`() {
        val types = sandbox.run("[typeof Graal, typeof load, typeof loadWithNewGlobal].join()")
        assertThat(types).isEqualTo("undefined,undefined,undefined")
    }

    private companion object {
        val SIZE_BUDGET: Duration = Duration.ofSeconds(20)
        val SIZE_GUARD: Duration = Duration.ofSeconds(30)
    }
}
```

- [ ] **Step 2: Write the sandbox**

```kotlin
package com.brokenfinger.vera.rule.sandbox

import java.io.OutputStream
import java.time.Duration
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import org.graalvm.polyglot.Context
import org.graalvm.polyglot.HostAccess
import org.graalvm.polyglot.ResourceLimits
import org.graalvm.polyglot.SandboxPolicy
import org.graalvm.polyglot.Value
import org.graalvm.polyglot.io.IOAccess

/**
 * Runs customer JavaScript under the CONSTRAINED sandbox policy with no host access, no IO, no
 * threads, no output, a statement budget, source and result caps and a wall-clock timeout. The
 * contract is "script returns a string"; every failure surfaces as a [ScriptException]. Host class
 * lookup is left at its default (off): installing any lookup predicate, even `{ false }`, makes
 * GraalJS define the `Java` global. The statement limit cuts runaway loops; the watchdog covers
 * time the limit does not count and cancels the context on every non-success path, before the
 * worker is joined. The globals `load`, `loadWithNewGlobal` and `Graal` are removed, and an
 * unhandled promise rejection fails the run instead of vanishing. The result length is read in the
 * guest before `asString()` copies it to the host. GraalJS 25.x on a stock JDK runs the interpreter
 * only (spec D6) — fine for rules, benchmark before scaling.
 *
 * Known limit: no per-script heap cap on CE/stock JDK (`sandbox.MaxHeapMemory` fails with "Heap
 * memory limit is not supported on the current Truffle runtime."); decide process isolation vs
 * GraalVM isolate in Phase 3. A host `OutOfMemoryError` surfaces as [ScriptHostExhaustedException].
 */
class ScriptSandbox(
    private val statementLimit: Long,
    private val timeout: Duration = Duration.ofSeconds(2),
) {

    fun run(script: String): String {
        requireWithinCap("source", script.length, MAX_SOURCE_CHARS)
        return newContext().use { context -> execute(context, script) }
    }

    private fun execute(context: Context, script: String): String =
        Executors.newSingleThreadExecutor(WORKERS).use { worker ->
            val result = worker.submit<String> { evaluate(context, script) }
            runCatching { result.get(timeout.toMillis(), TimeUnit.MILLISECONDS) }
                .getOrElse { failure ->
                    context.close(true)
                    throw waitFailure(failure)
                }
        }

    private fun evaluate(context: Context, script: String): String {
        val value = context.eval("js", script)
        if (!isPrimitiveString(value)) throw ScriptContractException(jsTypeOf(value))
        requireWithinCap("result", guestLength(context, value), MAX_RESULT_CHARS)
        return value.asString()
    }

    // A `new String(..)` wrapper is also `isString`; only the primitive has no members.
    private fun isPrimitiveString(value: Value): Boolean = value.isString && !value.hasMembers()

    private fun jsTypeOf(value: Value): String = value.metaObject?.metaSimpleName ?: "?"

    private fun guestLength(context: Context, value: Value): Int =
        context.eval("js", "(s) => s.length").execute(value).asInt()

    private fun waitFailure(failure: Throwable): ScriptException =
        when (failure) {
            is TimeoutException -> ScriptTimeoutException(timeout, failure)
            is InterruptedException -> interrupted(failure)
            is ExecutionException -> (failure.cause ?: failure).toScriptException()
            else -> failure.toScriptException()
        }

    private fun interrupted(failure: InterruptedException): ScriptException {
        Thread.currentThread().interrupt()
        return ScriptInterruptedException(failure)
    }

    private fun newContext(): Context =
        deniedBuilder()
            .out(OutputStream.nullOutputStream())
            .err(OutputStream.nullOutputStream())
            .options(OPTIONS)
            .resourceLimits(
                ResourceLimits.newBuilder().statementLimit(statementLimit, null).build()
            )
            .build()

    private fun deniedBuilder(): Context.Builder =
        Context.newBuilder("js")
            .sandbox(SandboxPolicy.CONSTRAINED)
            .allowHostAccess(NO_HOST_ACCESS)
            .allowIO(IOAccess.NONE)
            .allowCreateThread(false)
            .allowCreateProcess(false)
            .allowNativeAccess(false)

    private companion object {
        const val MAX_SOURCE_CHARS = 64 * 1024
        const val MAX_RESULT_CHARS = 1024 * 1024
        // SharedArrayBuffer/Atomics stay: their options are experimental and CONSTRAINED rejects
        // them.
        val OPTIONS: Map<String, String> =
            mapOf(
                "js.print" to "false",
                "js.console" to "false",
                "js.load" to "false",
                "js.graal-builtin" to "false",
                "js.unhandled-rejections" to "throw",
                "engine.WarnInterpreterOnly" to "false",
            )
        // HostAccess.NONE minus the mutable target mappings that CONSTRAINED rejects.
        val NO_HOST_ACCESS: HostAccess =
            HostAccess.newBuilder(HostAccess.NONE).allowMutableTargetMappings().build()
        val WORKERS: ThreadFactory =
            Thread.ofPlatform().name("vera-script-", 0).daemon(true).factory()

        fun requireWithinCap(what: String, length: Int, cap: Int) {
            if (length <= cap) return
            throw ScriptLimitException("Script $what is $length characters; the limit is $cap")
        }
    }
}
```

```kotlin
package com.brokenfinger.vera.rule.sandbox

import java.time.Duration
import org.graalvm.polyglot.PolyglotException

/** The one exception family a [ScriptSandbox] caller sees; nothing raw escapes `run`. */
sealed class ScriptException(message: String, cause: Throwable? = null) :
    IllegalStateException(message, cause)

/** The script ran past its wall-clock budget and its context was cancelled. */
class ScriptTimeoutException(timeout: Duration, cause: Throwable) :
    ScriptException("Script exceeded the wall-clock timeout of $timeout", cause)

/** The calling thread was interrupted; the script was cancelled and the interrupt flag restored. */
class ScriptInterruptedException(cause: Throwable) :
    ScriptException("Script caller was interrupted; the script was cancelled", cause)

/** The script did not return a string. */
class ScriptContractException(jsType: String) :
    ScriptException("Script must return a string but returned $jsType")

/** The source, the result or the statement budget exceeded its cap. */
class ScriptLimitException(message: String, cause: Throwable? = null) :
    ScriptException(message, cause)

/** The host ran out of a resource (e.g. `Java heap space`) while the script ran. */
class ScriptHostExhaustedException(message: String, cause: Throwable?) :
    ScriptException(message, cause)

/** The script threw, or the engine failed while running it. */
class ScriptFailedException(message: String, cause: Throwable?) : ScriptException(message, cause)

private const val MAX_MESSAGE_CHARS = 4 * 1024

/**
 * Maps any failure into the family. Messages are cut to [MAX_MESSAGE_CHARS]; a cause whose own
 * message was cut is dropped, so no guest-sized text reaches the caller through `cause` either. The
 * statement limit cancels the context (exhausted + cancelled); host exhaustion does not.
 */
internal fun Throwable.toScriptException(): ScriptException {
    if (this is ScriptException) return this
    val message = boundedMessage()
    val cause = takeIf { message.length == rawMessage().length }
    if (this !is PolyglotException || !isResourceExhausted)
        return ScriptFailedException(message, cause)
    if (isCancelled) return ScriptLimitException(message, cause)
    return ScriptHostExhaustedException(message, cause)
}

private fun Throwable.rawMessage(): String = message ?: javaClass.name

private fun Throwable.boundedMessage(): String {
    val raw = rawMessage()
    if (raw.length <= MAX_MESSAGE_CHARS) return raw
    return raw.take(MAX_MESSAGE_CHARS) + "… [truncated ${raw.length - MAX_MESSAGE_CHARS} chars]"
}
```

Design notes:
- **One exception family.** Callers see only the sealed `ScriptException` (`Timeout`, `Interrupted`, `Contract`, `Limit`, `HostExhausted`, `Failed`). A `PolyglotException` that is `isResourceExhausted` **and** `isCancelled` (the statement limit) maps to `ScriptLimitException`; exhausted but not cancelled (host `OutOfMemoryError`, observed as `Java heap space`) maps to `ScriptHostExhaustedException`; any other cause, guest or host, maps to `ScriptFailedException`. Every message is cut to 4 Ki chars with `… [truncated N chars]`, and a cause whose own message was cut is dropped, so guest-sized text cannot reach the caller through `getCause()` either. No raw `ExecutionException`, `PolyglotException` or `ClassCastException` escapes `run`.
- **Return contract.** A non-string result raises `ScriptContractException` naming the JS type from `Value.metaObject.metaSimpleName` (`number`, `undefined`, `Object`, `Promise`, …); `asString()` is never called on a non-string. A `new String('x')` wrapper is `isString() == true` but `hasMembers() == true`; only primitives pass (`isString && !hasMembers`).
- **Caps.** Sources over 64 Ki chars are rejected before a context is built; results over 1 Mi chars are rejected on the worker, inside the context. The result length is read in the guest with `(s) => s.length` before `asString()`, so an oversized result is never copied to the host; the Value API has no copy-free length for a primitive string (`getMember("length")` throws `UnsupportedOperationException` on a `TruffleString`).
- **No output.** `out`/`err` are null streams, and `js.print=false` / `js.console=false` (both accepted by GraalJS 25.4 without experimental options) remove `print` and `console`. Scripts that call `console.log` therefore fail with a `ReferenceError`; that is intended — rules return data, they do not log.
- **Removed globals.** `js.load=false` removes `load` and `loadWithNewGlobal`; `js.graal-builtin=false` removes `Graal` (both STABLE options in 25.4). `js.shared-array-buffer` and `js.atomics` exist but are EXPERIMENTAL, and CONSTRAINED rejects them even with `allowExperimentalOptions(true)` ("The option js.shared-array-buffer can only be used up to the TRUSTED sandbox policy"), so `SharedArrayBuffer`/`Atomics` stay — harmless without threads. `Polyglot`, `Packages` and `java` are already undefined under this configuration. `js.unhandled-rejections=throw` (STABLE) makes an unhandled promise rejection fail the run instead of vanishing.
- **CONSTRAINED policy.** `SandboxPolicy.CONSTRAINED` is supported on CE and makes the builder validate the configuration. It rejects `HostAccess.NONE` as is ("allows host object mappings of mutable target types"), so `NO_HOST_ACCESS` is `HostAccess.NONE` with `allowMutableTargetMappings()` emptied.
- **No `allowHostClassLookup` call.** Installing any lookup predicate, even `{ false }`, makes GraalJS define the `Java` global (`typeof Java` → `object`); the script then fails later with `TypeError: Access to host class java.lang.System is not allowed or does not exist.` Leaving lookup at its default (off) removes the global entirely, which is what the host-access test proves.
- **Wall-clock watchdog.** The owner's wiki (`concepts/graalvm-ce-script-sandbox`, GraalVM CE, 2026-09-07) records that the statement limit cuts runaway loops but a watchdog is still needed for wall-clock timeouts: time spent outside counted statements (a slow builtin, a huge regex, a large `JSON.stringify`) is not bounded by the budget. The eval runs on a single daemon worker thread (`vera-script-<n>`), the caller waits `future.get(timeout)`, and on **every** non-success path (timeout, interrupt, script failure) it calls `context.close(true)` before the executor is closed (joined). An interrupted caller gets `ScriptInterruptedException` with its interrupt flag restored. The context is created on the caller thread and entered only by the worker, never concurrently.
- The IO test uses dynamic `import('/etc/passwd')`, since `load` is removed; with `js.unhandled-rejections=throw` the rejected import fails the run with `Error: Operation is not allowed for: /etc/passwd`. Earlier probes (while `load` existed): `load('file:///etc/passwd')` fails with `TypeError: Cannot load script: file:///etc/passwd` even under `IOAccess.ALL`, so a `file://` URL proves nothing about IO; `load('/etc/passwd')` fails with `Operation is not allowed for: /etc/passwd` under `IOAccess.NONE` and with `SyntaxError: passwd:1:0 Expected an operand but found error` (the file was read) under `IOAccess.ALL`.
- **Known limit: no heap cap.** `sandbox.MaxHeapMemory=64MB` fails under both `CONSTRAINED` and `TRUSTED` on js-community 25.4.4.1.1 / stock JDK with `PolyglotException: Heap memory limit is not supported on the current Truffle runtime.`; without it `new Array(2e7).fill(1)` succeeds. A single oversized allocation such as `'x'.repeat(2 ** 29)` fails atomically with `Java heap space` (`ScriptHostExhaustedException`) and the next run succeeds; gradual heap growth across many small allocations is not bounded. A per-script heap cap needs process isolation or the GraalVM isolate (Step 4); decide in Phase 3.

- [ ] **Step 3: Run the tests**

Run: `./scripts/test.sh :platform:rule; echo exit=$?`
Expected: `:platform:rule:test: 17 tests, 0 failed, 0 skipped` (14 methods, the contract test parameterised four times), `exit=0`.

Observed failure messages (2026-09-30, Temurin 25, polyglot/js-community 25.4.4.1.1, interpreter only):
- Host access: `ReferenceError: Java is not defined`.
- IO: `Error: Operation is not allowed for: /etc/passwd`.
- Statement limit: `Statement count limit of 200000 exceeded. Statements executed 200001.`
- Wall clock: `Script exceeded the wall-clock timeout of PT0.5S`; the test took 0.506 s (limit `Long.MAX_VALUE`, timeout 500 ms), so the cancel is prompt.
- Interrupt: `Script caller was interrupted; the script was cancelled`; the test took 0.216 s (interrupt at 200 ms).
- Script error: `Error: boom`. Contract: `Script must return a string but returned number` / `undefined` / `Object` / `String` (wrapper).
- Oversized error: `throw new Error('x'.repeat(5e7))` → a 4096-char message ending `… [truncated 49995911 chars]`, no cause. The committed test uses `'x'.repeat(100000)` (`… [truncated 95911 chars]`): the smallest payload that still proves the cut.
- Host heap: `'x'.repeat(2 ** 29)` → `ScriptHostExhaustedException: Java heap space` (`isResourceExhausted=true`, `isCancelled=false`; the statement limit is `true`/`true`).

Timings (2026-09-30, three runs of a temporary probe test against the first version of the sandbox, since removed; each `run` builds a fresh context and executor): first `run` in a fresh JVM 748–766 ms (engine warm-up), then 2.0–3.2 ms per `run` of `JSON.stringify({ ok: true, n: 1 + 1 })`. For comparison the wiki measured ~1.7 s for the first GraalPy context.

Adversarial review (2026-09-30) of the first version:
- Held: host access (`Java` undefined), IO denial, statement limit, wall-clock timeout.
- Fixed — interrupted caller hung forever: `InterruptedException` escaped without `context.close(true)`, the flag was cleared, and `ExecutorService.close()` waited on a worker that never stops. Mutation proof: removing both `context.close(true)` and the flag restore → `execution timed out after 5000 ms` (the `assertTimeoutPreemptively` guard); removing only the flag restore → `Expecting value to be true but was false`. Removing only `close(true)` still passes: with the flag restored, `ExecutorService.close()` falls back to `shutdownNow()` and the worker's interrupt stops the script — `close(true)` is the primary guard, the interrupt a second one.
- Every test that runs an unbounded script (`while (true) {}`) is wrapped in `assertTimeoutPreemptively(5 s)`, so a sandbox regression fails the build instead of hanging the Stop hook or CI. Mutation proof: removing `context.close(true)` makes the wall-clock test fail with `execution timed out after 5000 ms` (before the guard, the same mutation hung the test JVM).
- Fixed — host stdout/stderr leak through `print`/`console.log`. Mutation proof: without null streams, `js.print`/`js.console` and CONSTRAINED → `Expecting empty but was: "LEAK\nLEAK"`.
- Fixed — non-string results (`ClassCastException`-style failures) now raise `ScriptContractException`; raw exceptions now map into `ScriptException`; source/result caps added.
- Deferred — heap exhaustion: no per-script heap cap on CE/stock JDK (see Known limit above).

Adversarial review, round 2 (2026-09-30), on `4303aab`:
- Held: the interrupt, output and contract fixes.
- Fixed — error-message size bypassed the output cap (`throw new Error('x'.repeat(5e7))` gave a 50M-char message): messages are cut to 4 Ki chars and the oversized cause dropped.
- Fixed — host OOM was reported as `ScriptLimitException`, indistinguishable from a statement-limit cut: now `ScriptHostExhaustedException`.
- Fixed — `new String('x')` passed the contract; `load`, `loadWithNewGlobal` and `Graal` removed; the result length is checked in the guest before the host copy.
- Skipped — `SharedArrayBuffer`/`Atomics`: their options are experimental and CONSTRAINED rejects them.

CI time budget (2026-09-30): on `ubuntu-latest` (interpreter-only GraalJS, slower runner) `results over 1 MiB are rejected` and the 5e7-char error test hit the then-default 2 s wall clock (`ScriptTimeoutException ... PT2S`) instead of their size exceptions. The tests, not the sandbox, were fixed: the shared test sandbox gets a 20 s wall clock and size-handling tests (result cap, message cut, host heap) a 30 s `assertTimeoutPreemptively` guard; the truncation payload shrank from 5e7 to 100 000 chars. Timing tests (wall clock, interrupt) keep their own short-timeout sandbox and the 5 s guard; the statement-limit test keeps the 5 s guard (the limit cuts it in ~50 ms, so the sandbox's wall clock is irrelevant there).

- [ ] **Step 4: Check whether the isolate artifact exists (spec §11 PoC 2, second half)**

Run: `curl -s -o /dev/null -w '%{http_code}\n' https://repo1.maven.org/maven2/org/graalvm/polyglot/js-isolate-community/25.4.4.1.1/`
Expected: `200` (artifact exists → stronger isolation is an option for Phase 3) or `404` (record "not available for CE" in the ADR). Either result is fine; the point is to know.

Observed (2026-09-30): `200`. The directory holds `js-isolate-community-25.4.4.1.1.pom` (plus signatures and checksums), so an isolate variant of the CE JS runtime is published for this version; evaluating it is Phase 3 work.

- [ ] **Step 5: Commit**

```bash
git add platform/rule
git commit -m "feat: PoC 2 GraalJS script sandbox with host, IO, statement and wall-clock limits"
# after the adversarial review:
git commit -m "fix: harden the script sandbox against interruption, output leaks and contract violations"
# after the second round:
git commit -m "fix: cap sandbox error messages, separate host exhaustion, close remaining contract gaps"
```

---

### Task 11: PoC 3 and PoC 4 — toolchain compatibility and code intelligence

**Files:**
- Create: `platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/poc/DetektSmokeSample.kt.disabled` (a deliberately bad sample kept out of compilation; renamed temporarily during the check). It lives in the `main` source set because the shared detekt config excludes `MagicNumber` and other rules for test source sets, so only `main` proves the production rules

- [ ] **Step 1: Prove detekt fires on the five principles**

Write `platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/poc/DetektSmokeSample.kt.disabled`:

```kotlin
package com.brokenfinger.vera.metadata.poc

// Deliberately violates LongMethod, NestedBlockDepth, MagicNumber and ForbiddenComment.
// Kept with a .disabled suffix so it never compiles; rename to .kt only for the smoke check.
class DetektSmokeSample {
    fun tooLongAndTooNested(input: Int): Int {
        var total = 0
        if (input > 0) {
            if (input > 10) {
                if (input > 100) {
                    total += 3 // TODO remove
                } else {
                    total += 2
                }
            } else {
                total += 1
            }
        }
        total += 7
        total += 8
        total += 9
        total += 10
        total += 11
        total += 12
        return total
    }
}
```

Run:

```bash
mv platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/poc/DetektSmokeSample.kt.disabled platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/poc/DetektSmokeSample.kt
./gradlew :platform:metadata:detekt --console=plain -q; echo exit=$?
mv platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/poc/DetektSmokeSample.kt platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/poc/DetektSmokeSample.kt.disabled
```

Result (executed): `exit=1`. The report `platform/metadata/build/reports/detekt/detekt.md` lists 12 findings: `complexity, LongMethod (1)`, `complexity, NestedBlockDepth (1)`, `style, ForbiddenComment (1)` and `style, MagicNumber (9)`. No parse error on Kotlin 2.3 syntax. The sample sits in `main`, so production rules apply. With the file back to `.disabled`, `./scripts/check.sh` exits 0 and `git status --short` shows only the new `.disabled` file.

- [ ] **Step 2: Prove the Kotlin LSP plugin resolves symbols across modules (PoC 4)**

In a Claude Code session in this repository, run `/plugin` and confirm `kotlin-lsp` is enabled, then ask: `Use the LSP to find all references to TableName.of across the repository`.
Expected: references in `TableNameTest.kt` are listed with file and line. If the plugin reports no Gradle project model, note "kotlin-lsp needs `./gradlew` import; falls back to grep" in the PoC ADR and in CLAUDE.md.

Result (executed 2026-09-30): **blocked on the machine, not on the project.** The Claude Code `kotlin-lsp` plugin is enabled but its CLI is not installed (`Executable not found in $PATH: "kotlin-lsp"`). `brew install JetBrains/utils/kotlin-lsp` (263.4702.0) refused with `Error: Your Command Line Tools are too outdated.` — the Xcode Command Line Tools must be updated for macOS 27 first (owner action: Software Update or `xcode-select --install`). Until then agents navigate with grep; CLAUDE.md (Plan B) states "LSP unavailable → grep". Re-run this step after the CLT update and record the reference list.

- [ ] **Step 3: Commit**

```bash
git add platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/poc/DetektSmokeSample.kt.disabled
git commit -m "test: PoC 3 detekt smoke sample kept disabled"
```

---

### Task 12: GitHub repository and CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  check:
    name: check (format, detekt, unit, arch)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: |
            21
            25
      - uses: gradle/actions/setup-gradle@v6
      - run: ./scripts/check.sh

  itest:
    name: itest (Testcontainers PostgreSQL 18)
    runs-on: ubuntu-latest
    needs: check
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: |
            21
            25
      - uses: gradle/actions/setup-gradle@v6
      - run: ./scripts/itest.sh
        env:
          CI: 'true'

  coverage:
    name: coverage (Kover ≥ 80% lines)
    runs-on: ubuntu-latest
    needs: check
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: |
            21
            25
      - uses: gradle/actions/setup-gradle@v6
      # koverVerify is detached from `check` (Task 3 review C1); it pulls every test task including itest,
      # so this job needs Docker (present on ubuntu-latest) and runs integration coverage too.
      - run: |
          ./gradlew koverXmlReport koverVerify --console=plain -q || {
            echo "::error::Line coverage below the 80% rule. Run ./gradlew koverHtmlReport locally and open build/reports/kover/html/index.html to see uncovered classes."
            exit 1
          }
        env:
          CI: 'true'
      - uses: actions/upload-artifact@v7
        if: always()
        with:
          name: kover-report
          path: build/reports/kover/report.xml

  build:
    name: build (bootJar)
    runs-on: ubuntu-latest
    needs: check
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: |
            21
            25
      - uses: gradle/actions/setup-gradle@v6
      - run: ./scripts/build.sh
```

- [ ] **Step 2: Run coverage locally first**

Run: `./gradlew koverXmlReport koverVerify --console=plain -q; echo exit=$?`
Expected: `exit=0`. If the rule fails, the uncovered lines are in `build/reports/kover/report.xml`; `TableName` and `ScriptSandbox` are fully covered by their tests, so a failure means a new untested class was added — add its test, do not lower `minBound`.

- [ ] **Step 3: Create the public repository and push**

Run:

```bash
gh repo create BrokenFinger98/vera --public --description "Metadata-driven enterprise platform engine (ServiceNow-style) built entirely by AI coding agents" --source=/Users/yu-sun00/Desktop/vera --remote=origin
git add .github/workflows/ci.yml
git commit -m "ci: add check, itest, coverage and build jobs"
git push -u origin main
```

Expected: repository URL printed, push succeeds. Then `gh run watch --exit-status` on the triggered run ends with all four jobs green.

- [ ] **Step 4: Labels and milestones**

```bash
for l in "phase-1:Metadata engine" "phase-2:Inheritance, references, cache" "phase-3:Rules, ACL, lifecycle" "phase-3.5:Ingestion and reconciliation" "phase-4:Layering and upgrade" "phase-5:Multi-instance"; do
  gh api repos/BrokenFinger98/vera/milestones -f title="${l%%:*}" -f description="${l#*:}" >/dev/null && echo "milestone ${l%%:*}"
done
for l in "epic:6f42c1" "task:0e8a16" "test-change:d93f0b" "harness:1d76db" "adr:fbca04" "poc:c5def5"; do
  gh label create "${l%%:*}" --color "${l#*:}" --force >/dev/null && echo "label ${l%%:*}"
done
```

Expected: six `milestone` lines and six `label` lines.

- [ ] **Step 5: Record Phase 0-A completion evidence**

Run: `./scripts/check.sh && ./scripts/itest.sh && git log --oneline | head -20`
Expected: both `RESULT ... exit=0` lines and the commit list. Paste all three outputs into `.harness/state/progress.md` when Phase 0-B creates that file (Plan B, Task 10 reads them from `git log`).

---

## Self-review against the spec

- §4 layout: every path under `vera/` that belongs to build and code is created here; harness paths (`CLAUDE.md`, `.claude/`, `.githooks/`, `.harness/`, `docs/llm-wiki`, other `.github` files) are Plan B.
- §8 testing policy: three suites ✓, real DB only ✓, detekt encodes principles 1, 2 (LongMethod, NestedBlockDepth) and 5 (UnnecessaryAbstractClass/Inheritance) ✓; principle 3 (wrap primitives) is a review item — the Kotlin compiler already enforces one-field value classes, so no machine rule adds anything ✓; ArchUnit rules (domain purity, exception bases, repository placement, module markers, import scope) ✓, Kover 80% ✓, Pitest is Phase 1 (spec says nightly on core modules, none exist yet) — documented gap, intentional.
- §11 versions: all pinned ones verified on Maven Central 2026-09-30; BOM-managed ones deliberately unpinned. PoC 1 (Task 9), PoC 2 (Task 10), PoC 3 (Task 6 + Task 11), PoC 4 (Task 11) ✓.
- §12 steps 2, 3, 6 ✓ (step 2's branch protection waits for Plan B, which adds the remaining required checks).
- Type consistency: `TableName.of`, `physicalName()`, `InvalidTableNameException`, `ScriptSandbox(statementLimit)`, `TestcontainersConfiguration`, module marker names match across tasks.
- No placeholders: every file has full content; the only deferred items (Pitest, springdoc, Kafka/Valkey dependencies) are named as later-phase work, not left as TODOs.
