# NERRA AP deliverables — technical review

**Team:** T0123  
**Project:** NERRA  
**Scope:** AP deliverables only (CP1–CP4). DE is explicitly out of scope.  
**Reviewed against:** `MRiARC/NERRA/backend/app/models.py` and the AP repository's SQL/Markdown files.

## Executive assessment

Gemini's submission is a useful draft, but it should not be submitted unchanged. The most important problems are consistency and evidence, not prose quality.

### Findings

1. **The physical schema contains 22 tables.** The submitted normalization report lists 23 logical relations, including `character_aliases`, `object_mentions`, and `event_participants`, which are not physical tables in `03_schema.sql`. Conversely, it omits `correction_rules` and `project_customizations`, which are in the DDL and application models.
2. **The ER diagram is stale/incomplete.** It omits `project_customizations`, does not show all columns, and does not accurately represent several JSONB attributes and relationships. Use the regenerated diagram in this patch.
3. **The CP3 query set has 20 queries, but Q12's claimed plan is inconsistent with the SQL.** The query compares `LOWER(subject)` and `LOWER(attribute)`, while the submitted plan reports ordinary equality index conditions on un-lowered columns. The plan cannot be treated as evidence for that exact query.
4. **The CP4 timings are not verifiable from the repository.** `05_query_timings.md` contains exact millisecond measurements for all 20 queries, but only one plan artifact exists. The Q12 plan itself appears inconsistent with the query. These measurements must be treated as unverified and replaced with real measurements before submission.
5. **The normalization report overclaims BCNF.** Its table-by-table proof covers only a subset of the schema and assumes functional dependencies without consistently grounding them in declared constraints.

## Recommended handling

- Use `01_normalization.md` from this patch for a transparent normalization discussion. It distinguishes the logical relational design from the application's pragmatic JSONB storage.
- Use `02_er_diagram.png` and retain `02_er_diagram.dot` as its editable Graphviz source.
- Use `03_schema.sql` as the reviewed DDL. It preserves the application's 22-table model and adds the functional expression index required by Q12.
- Use `04_queries.sql` for the corrected query set. Q12 and its supporting index now agree.
- Replace the fabricated-looking CP4 numbers with `05_query_timings.md` from this patch. It is intentionally a measurement template; no timings are claimed until measured.
- Do not submit a synthetic execution plan. `plans/q12_claim_contradictions.txt` now contains the exact query and capture instructions, not invented plan output.

## Important academic integrity note

Do not attribute individual commits or measurements to teammates who did not perform/review them. Each teammate should review their assigned artifact and make their own genuine commit. Do not report benchmark numbers until they have actually been collected.
