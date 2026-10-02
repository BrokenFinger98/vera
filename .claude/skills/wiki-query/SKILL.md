---
name: wiki-query
description: Answer a question from THIS repo's wiki (docs/llm-wiki) with citations — past decisions, traps, lessons. Use before re-deciding anything or when a request may conflict with an ADR.
---

# wiki-query

1. Read `docs/llm-wiki/index.md`; pick candidate pages by title/description (no embeddings).
2. Read only those pages. Answer with `[[page]]` citations and the ADR status (active / superseded).
3. If the answer required knowledge not in the wiki and it is durable, propose `/wiki-ingest`.
4. Append `## [YYYY-MM-DD] query | <question> → <pages>` to `docs/llm-wiki/log.md` only when the answer changed a decision.
