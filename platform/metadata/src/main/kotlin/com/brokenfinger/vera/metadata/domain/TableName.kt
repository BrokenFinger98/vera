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
