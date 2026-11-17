# NERRA — Query Performance and Execution Timings

**Team:** T0123  
**Deliverable:** CP4 — `dbms/05_query_timings.md`  
**Status:** Pending actual measurements  
**Database:** PostgreSQL (record the exact server version)  
**Important:** No benchmark values are pre-filled. Enter numbers only after running the workload on the documented test database.

## 1. Why the previous timing table was removed

The earlier draft contained exact millisecond values for 20 queries, but the repository did not contain corresponding execution-plan artifacts or a reproducible test dataset. The Q12 plan also did not match the submitted SQL's `LOWER(...)` predicates. Those values are therefore not retained as verified measurements.

## 2. Environment record

| Field | Actual value |
|---|---|
| PostgreSQL version | _record_ |
| OS / architecture | _record_ |
| CPU | _record_ |
| RAM | _record_ |
| Storage | _record_ |
| Dataset size (rows per table) | _record_ |
| `shared_buffers` | _record_ |
| `work_mem` | _record_ |
| Indexes present | _record_ |
| Test date/time | _record_ |

## 3. Measurement method

1. Use a dedicated test database with a documented, repeatable dataset. Do not benchmark against production/user manuscripts.
2. Run schema creation and seed data once; record row counts for the tables involved in each query.
3. Run `ANALYZE` after loading data.
4. For each read query, capture `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)`.
5. Run at least three timed trials per query. Record each execution time and compute the arithmetic mean:

   `average_ms = (run1_ms + run2_ms + run3_ms) / 3`
6. Keep cache conditions consistent and state whether trials are warm-cache or cold-cache. Do not label sequential runs “cold” unless the PostgreSQL/OS cache was actually controlled.
7. For write queries, use a resettable test fixture or a transaction that is rolled back. Ensure inserts do not fail due to duplicate or missing foreign-key IDs. Record planning and execution times separately where available.
8. Save actual plan output under `dbms/plans/`. Do not type a plan by hand.

## 4. Timing table

| Query | Description | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Mean (ms) | Plan file |
|---|---|---|---:|---:|---:|---:|---|
| Q1 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q01_...txt` |
| Q2 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q02_...txt` |
| Q3 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q03_...txt` |
| Q4 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q04_...txt` |
| Q5 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q05_...txt` |
| Q6 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q06_...txt` |
| Q7 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q07_...txt` |
| Q8 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q08_...txt` |
| Q9 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q09_...txt` |
| Q10 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q10_...txt` |
| Q11 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q11_...txt` |
| Q12 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q12_...txt` |
| Q13 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q13_...txt` |
| Q14 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q14_...txt` |
| Q15 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q15_...txt` |
| Q16 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q16_...txt` |
| Q17 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q17_...txt` |
| Q18 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q18_...txt` |
| Q19 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q19_...txt` |
| Q20 | _description_ | _READ/WRITE_ | — | — | — | — | `plans/q20_...txt` |

## 5. Interpretation

For each query, discuss:

- whether PostgreSQL used a sequential scan, index scan, bitmap scan, nested-loop join, hash join, or sort;
- whether estimated row counts were close to actual row counts;
- shared buffer hits/reads and any disk reads;
- whether an index materially improved the query;
- how dataset size and selectivity affected the result.

A query running in a few milliseconds on a tiny dataset does not establish that it scales to large manuscripts. Include row counts and machine/database configuration alongside every performance conclusion.
