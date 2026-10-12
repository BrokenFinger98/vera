# Harness metrics (weekly line appended by the harness-improve routine)

| week | merged PRs | avg changed lines/PR | gate firings (rule:count) | critic blocking/PR | CI failure rate | regressions | time-to-green (median) |
|---|---|---|---|---|---|---|---|
| 2026-W40 (to 2026-10-02) | 3 | 558 | none counted (4 probe events, `"probe":true`, are skipped: stop-gate/check.sh-failed, block-danger/git-discard-all, pre-push-guard/deleted-test-file and assertion-decrease) | – | 11% (1 of 9 completed runs; 1 cancelled run not counted) | 0 | – |
| 2026-W40 (2026-10-02 to 2026-10-04) | 1 | 3122 (#4, gross; events.jsonl not excluded) | none counted (no non-probe events) | – | 6% (1 of 18 completed runs; 1 cancelled run not counted) | 0 | – |
| 2026-W41 (2026-10-04 to 2026-10-12) | 3 (#6, #7, #9) | 136 (gross: 367, 1, 39; events.jsonl not excluded) | none fired in the window; 6 non-probe events fired 2026-10-02 and were published 2026-10-06, none with a repeated cause: stop-gate/check.sh-failed:1, pre-push-guard/assertion-decrease:1, wiki-gate/blocked-no-wiki-change:1, ci/label-required-when-tests-change:1, critic:2 | 0.67 (2 blocking critic events, both on #6, over 3 PRs) | 0% (0 of 15 completed runs) | 0 | – |
