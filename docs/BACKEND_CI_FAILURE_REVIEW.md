# Backend CI Failure Review

Date: 2026-09-11. Baseline: `2145c08`.

## Findings

The same baseline failed three E2E checks in GitHub run `34585793561`
and one in run `34585783985`. Both runs passed all 69 unit tests.

| Check | Observed failure | Cause supported by investigation |
| --- | --- | --- |
| Outbox processing/replay | Expected PENDING, received PROCESSING | Another suite's real worker can claim this suite's event before the assertion. |
| Hidden achievement rebuild | Expected zero unfinished events, received one | A global drain does not wait for events claimed by another worker. |
| Journey unlocks | Not every JOURNEY achievement was unlocked yet | Five drain calls do not guarantee this family's final event has committed when another suite consumes the same queue. The 25-day fixture still satisfies all seven journey rules. |

The suites have separate Nest applications but share a database-wide outbox.
Jest ran them in parallel. The newly added V2 suite explicitly drains that global
queue and can process other suites' events. A failed claim also ends that drain;
its return value is not a global completion barrier.

In a newly created local database with all 27 migrations and seed data, the
unmodified parallel run reproduced three failures (including unfinished V2
events and an unexpected dead-letter state). This excludes missing tables as
the explanation for these CI failures. Earlier local missing-table failures
were a separate environment issue.

## Fix

- Set E2E `maxWorkers` to 1 while suites share one database.
- Set the initial achievement flag to false in E2E setup so an inherited local
  environment cannot start an automatic poller. Suites still enable evaluation
  and exercise the real worker explicitly.
- Retain every assertion and all concurrent HTTP/worker calls inside tests.
- Do not change production worker logic, achievement thresholds or rewards.

Parallel E2E execution requires separate databases per suite, not merely
separate HTTP servers. A production worker's drain should not be used as a
cross-process synchronization barrier either.

## Verification

The first fixed full E2E run passed all 42 tests, including all original failing
checks, with an inherited `ACHIEVEMENTS_ENABLED=true` to verify setup isolation.
The second fixed full run also passed all 42 tests (61.952s and 64.120s),
without database resets between runs. All 69 unit tests, backend build and
TypeScript test compilation passed. No tests or assertions were skipped.

These failures should be fixed, not ignored or marked skipped. This change
addresses the test isolation issue only; it does not resolve the separately
identified website deployment output-directory mismatch or deploy production.
