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
