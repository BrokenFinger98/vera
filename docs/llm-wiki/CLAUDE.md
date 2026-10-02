# Vera LLM Wiki — Schema

Karpathy-style LLM wiki, repo-local. `raw/` is immutable source (session excerpts, decisions as recorded);
`wiki/` is owned by the agent and rewritten as knowledge integrates; this file is the schema.
The owner's cross-project wiki (`~/Desktop/llm-wiki`) is a different wiki — never ingest there from here.

```
docs/llm-wiki/
├── CLAUDE.md            this schema
├── index.md             catalogue; read first; every page registered here (no orphans)
├── log.md               append-only: ingest/query/lint history
├── raw/sessions/        YYYY-MM-DD-<slug>.md — immutable
├── raw/inbox/           transcript snapshots from the global hooks (gitignored, consumed by /wiki-ingest)
└── wiki/
    ├── decisions/       ADRs: YYYY-MM-DD-<slug>.md, one decision per file
    ├── concepts/        patterns, traps, lessons.md (counted)
    └── sources/         one stub per raw file: 3–5 claims + pages updated
```

## Page rules
- kebab-case file names, English, frontmatter:
  `type: decision|concept|source` · `project: vera` · `tags: [...]` · `created` · `updated` · `sources: [raw/sessions/...]`
- ADR sections: **Context / Options considered / Decision / Rationale / Accepted costs / Outcome**. Add `author:`.
- Cite evidence: `(raw/sessions/2026-09-30-foo.md)`. Distinguish measured from believed.
- Link pages with `[[decisions/...]]`; new pages get an index line **starting with the date** and ≥1 inbound link.
- Contradictions: mark the old statement `⚠️ (superseded)` and keep it; newest is canonical.

## lessons.md format (feeds the self-improvement loop)
```
### <lesson slug>
count: <n> · tickets: #12, #15 · first: 2026-10-02 · last: 2026-10-09 · status: open|proposed|promoted|dropped
what: <one line: what was slow / wrong / missing>
fix: <what a rule, hook, test or lint would look like>
```
`count` ≥ 3 → the weekly routine proposes a promotion (a PR, or an issue for `.claude/rules|hooks`) and marks the entry `status: proposed` with the link; once the owner merges it, the entry becomes `status: promoted` and moves to the bottom.

## Workflows
- **ingest** — `/wiki-ingest`: read index → save raw → source stub → integrate into pages (merge, never overwrite) → index + links → log line.
- **query** — `/wiki-query <question>`: index → pages → answer with citations; new findings are ingested.
- **lint** — `/wiki-lint`: contradictions, stale `updated:`, orphans, index mismatches, lessons past due.
