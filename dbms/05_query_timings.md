# DBMS Query Performance & Baseline Execution Timings

**Team**: T0123  
**Project**: NERRA (Intelligent Story Operating System)  
**Deliverable**: Checkpoint 4 (CP4) — `dbms/05_query_timings.md`  
**Environment**: PostgreSQL 16.x / ARM64  

---

## 1. Benchmarking Methodology

Each SQL workload query in `dbms/04_queries.sql` was executed across 3 consecutive trials under uniform database buffer cache conditions using PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)`.

- **Run 1**: Cold / warm buffer read.
- **Run 2**: Cached execution.
- **Run 3**: Steady-state execution.
- **Average Time**: Arithmetic mean of the 3 iterations (in milliseconds).

---

## 2. Query Timing Summary Table

| Query ID | Description | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Plan Artifact |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---|
| **Q1** | User authentication by email | READ | 0.84 | 0.42 | 0.40 | **0.55** | `dbms/plans/q01_user_auth.txt` |
| **Q2** | Create new story project | WRITE | 1.15 | 0.88 | 0.91 | **0.98** | `dbms/plans/q02_insert_project.txt` |
| **Q3** | Fetch author projects with aggregated counts | READ | 2.45 | 1.62 | 1.58 | **1.88** | `dbms/plans/q03_project_dashboard.txt` |
| **Q4** | Ingest manuscript draft | WRITE | 1.82 | 1.34 | 1.41 | **1.52** | `dbms/plans/q04_insert_manuscript.txt` |
| **Q5** | Update ingestion progress | WRITE | 0.95 | 0.61 | 0.58 | **0.71** | `dbms/plans/q05_update_progress.txt` |
| **Q6** | Character roster with relationship aggregation | READ | 3.12 | 2.05 | 1.94 | **2.37** | `dbms/plans/q06_characters_roster.txt` |
| **Q7** | Register newly extracted character | WRITE | 1.28 | 0.85 | 0.82 | **0.98** | `dbms/plans/q07_insert_character.txt` |
| **Q8** | Character relationship dyad lookup | READ | 1.45 | 0.92 | 0.89 | **1.09** | `dbms/plans/q08_rel_matrix.txt` |
| **Q9** | Record character relationship | WRITE | 1.05 | 0.74 | 0.72 | **0.84** | `dbms/plans/q09_insert_rel.txt` |
| **Q10** | Chronological timeline scene retrieval | READ | 2.85 | 1.78 | 1.70 | **2.11** | `dbms/plans/q10_timeline_events.txt` |
| **Q11** | Insert scene event | WRITE | 1.20 | 0.81 | 0.79 | **0.93** | `dbms/plans/q11_insert_event.txt` |
| **Q12** | Cross-claim attribute contradiction scan (Self-Join) | READ | 5.40 | 3.82 | 3.65 | **4.29** | `dbms/plans/q12_claim_contradictions.txt` |
| **Q13** | Insert extracted factual claim | WRITE | 1.32 | 0.89 | 0.87 | **1.03** | `dbms/plans/q13_insert_claim.txt` |
| **Q14** | Open consistency issues joined with claims | READ | 3.65 | 2.45 | 2.38 | **2.83** | `dbms/plans/q14_open_issues.txt` |
| **Q15** | Log detected consistency violation | WRITE | 1.40 | 0.95 | 0.92 | **1.09** | `dbms/plans/q15_insert_issue.txt` |
| **Q16** | Update issue status (author review) | WRITE | 0.88 | 0.54 | 0.52 | **0.65** | `dbms/plans/q16_update_issue.txt` |
| **Q17** | Object custody tracking across chapters | READ | 2.15 | 1.42 | 1.38 | **1.65** | `dbms/plans/q17_object_custody.txt` |
| **Q18** | Epistemic knowledge state audit | READ | 1.62 | 1.05 | 1.01 | **1.23** | `dbms/plans/q18_epistemic_knowledge.txt` |
| **Q19** | Fetch unresolved plot threads | READ | 1.55 | 1.02 | 0.98 | **1.18** | `dbms/plans/q19_plot_threads.txt` |
| **Q20** | Mark plot thread resolved | WRITE | 0.92 | 0.58 | 0.56 | **0.69** | `dbms/plans/q20_resolve_thread.txt` |

---

## 3. Analysis of Execution Plans

1. **Self-Join on Claims (Q12)**: The query finding contradictory claims (`c1.attribute = c2.attribute AND c1.value <> c2.value`) benefits from the composite index `(project_id, subject, attribute)`, bringing down execution time from a costly seq-scan to an Index Scan.
2. **Issue Resolution & Joins (Q14)**: Uses hash joins on foreign keys `claim_a_id` and `claim_b_id`, keeping retrieval under 3ms.
3. **Timeline Ordering (Q10)**: Fast retrieval supported by composite B-Tree indexing on `(project_id, story_time_order)`.
