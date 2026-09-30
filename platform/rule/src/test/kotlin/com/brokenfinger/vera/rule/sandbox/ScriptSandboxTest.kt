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
