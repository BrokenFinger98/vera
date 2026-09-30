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
