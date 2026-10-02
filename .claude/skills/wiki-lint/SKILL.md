---
name: wiki-lint
description: Health-check THIS repo's wiki (docs/llm-wiki) — contradictions, stale pages, orphans, index mismatches, lessons past their promotion threshold. Use monthly (harness-improve routine) or when the index feels wrong.
---

# wiki-lint

Report, then fix what is mechanical:
1. Index ↔ files: every `wiki/**/*.md` registered? every index line has a file?
2. Orphans: pages with no inbound `[[link]]`.
3. Contradictions: same topic, different claims → newest canonical, old marked `⚠️ (superseded)`.
4. Stale: `updated:` older than 90 days on a page whose subject changed in git since.
5. Lessons: entries with `count ≥ 3` and `status: open` → list them as "due for promotion".
6. Raw inbox: snapshots older than 14 days → list for deletion.
Write `## [YYYY-MM-DD] lint | <n> issues, <m> fixed` to `docs/llm-wiki/log.md`.
