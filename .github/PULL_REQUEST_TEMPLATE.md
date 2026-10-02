## What

## Why
Closes #

## Evidence (real output — not intentions)
<details><summary>./scripts/check.sh (last 30 lines)</summary>

```
```
</details>
<details><summary>./scripts/itest.sh (last 30 lines)</summary>

```
```
</details>

```
git diff --stat origin/main...HEAD
```

Reviewer / critic findings and disposition:
-

## Definition of Done
- [ ] Every acceptance criterion in the issue has a test
- [ ] `check.sh` and `itest.sh` output above, exit 0
- [ ] Only the owned module changed, plus the always-allowed files in CLAUDE.md (or split rationale below)
- [ ] ≤ 400 changed lines, one behaviour change
- [ ] `Test-Change:` trailer if tests were deleted or assertions reduced; label `test-change` if `src/test|itest|archTest` touched
- [ ] ADR / module spec updated, or "no decision made"
- [ ] `.harness/state/progress.md` updated in this branch (issue `#<n>`)
- [ ] Rollback: <migration reversal or "plain revert suffices">
- [ ] Owner design review: module boundaries · domain language · ADR needed? · migration reversible · no PII in logs
