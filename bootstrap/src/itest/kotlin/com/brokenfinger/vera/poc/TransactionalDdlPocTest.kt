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
