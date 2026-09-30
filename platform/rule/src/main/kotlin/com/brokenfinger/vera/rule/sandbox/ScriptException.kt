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
