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
