---
name: wiki-ingest
description: Ingest decisions, deliverables and reusable know-how from the current work into THIS repo's wiki (docs/llm-wiki). Use when work wraps up, when an ADR is needed, or when the push gate asks for wiki changes. Not for chit-chat.
---

# wiki-ingest (repo wiki: docs/llm-wiki — never the owner's central wiki)

1. Read `docs/llm-wiki/CLAUDE.md` and `docs/llm-wiki/index.md`.
2. Sources: arguments first; otherwise pick from this conversation what is worth revisiting (decisions, measured results, traps, wrong hypotheses).
   Check `docs/llm-wiki/raw/inbox/*.jsonl` (hook snapshots); slice by the owner's local time zone (KST). Delete only the snapshots you consumed.
3. Save raw: `docs/llm-wiki/raw/sessions/YYYY-MM-DD-<slug>.md` (immutable; `-2` suffix if it exists).
4. Source stub: `docs/llm-wiki/wiki/sources/<same-slug>.md` — 3–5 claims + links to pages updated.
5. Integrate: **one decision = one ADR file** `wiki/decisions/YYYY-MM-DD-<slug>.md` (Context / Options / Decision / Rationale / Accepted costs / Outcome, `author:`).
   Concepts merge into existing pages (update `updated:` and `sources:`); contradictions get `⚠️ (superseded)`.
6. Index + links: register new pages (date first), ensure ≥1 inbound link.
7. Log: `## [YYYY-MM-DD] ingest | <title> → N updated, M created` in `docs/llm-wiki/log.md`.
8. Stage `docs/llm-wiki` so the push gate sees it; the caller commits with /gated-commit.
English only. Cite measured evidence; record failed attempts too.
