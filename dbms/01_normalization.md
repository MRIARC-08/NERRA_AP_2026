# NERRA — Relational Database Normalization

**Team:** T0123  
**Project:** NERRA — Intelligent Story Operating System for Novelists & Narrative Designers  
**Deliverable:** CP1 — Normalization  
**Scope:** PostgreSQL relational source of truth. Neo4j is a derived graph projection and is not included in the relational normal-form proof.

## 1. Purpose and scope

NERRA stores users, projects, manuscripts, extracted story entities, evidence, validation decisions, and consistency issues. The application uses PostgreSQL as its transactional source of truth and Neo4j as a graph-oriented projection.

This report is based on the application's SQLAlchemy models and the AP DDL. The physical PostgreSQL schema contains **22 tables**:

| Area | Tables |
|---|---|
| Identity | `users`, `user_sessions`, `user_settings` |
| Projects and manuscripts | `projects`, `manuscripts`, `manuscript_versions`, `chapter_analyses`, `chunks` |
| Story world | `characters`, `relationships`, `locations`, `objects`, `object_custody_events`, `events` |
| Claims and validation | `claims`, `validation_candidates`, `knowledge_updates`, `world_rules`, `issues`, `correction_rules`, `plot_threads`, `project_customizations` |

The physical implementation uses PostgreSQL `JSONB` for selected flexible payloads and `VECTOR(384)` for embeddings. This is an intentional implementation choice, but it must not be confused with a fully decomposed relational representation of every nested collection. The distinction is explained in Section 7.

## 2. Unnormalized form (UNF)

A naïve design could store an entire project and its extracted story state in one large record:

```text
PROJECT_SESSION(
  project_id, project_title, owner_id, owner_email,
  manuscripts: [
    { manuscript_id, title, raw_text,
      chapters: [
        { chapter_number, analysis, chunks: [...],
          characters: [...], events: [...], claims: [...] }
      ]
    }
  ],
  issues: [...], plot_threads: [...], world_rules: [...]
)
```

This structure contains repeating groups and nested collections. It causes:

- **Update anomalies:** changing an author's email or a character's canonical name may require changing repeated copies.
- **Insertion anomalies:** a project owner or world rule cannot be independently represented without creating a larger session document.
- **Deletion anomalies:** deleting one manuscript could accidentally remove project-level story information if all data is embedded in one record.
- **Query anomalies:** filtering, joining, constraining, and indexing nested elements becomes harder than querying independent relations.

## 3. First Normal Form (1NF)

### 3.1 Rule

A relation is in 1NF when each row-column intersection contains one value from the attribute's domain, there are no repeating groups, and rows are uniquely identifiable.

### 3.2 Relational decomposition

The repeating entities are separated into independently identifiable relations. The 22 physical relations listed in Section 1 provide the core decomposition:

- `users` stores account identity; `user_sessions` stores individual sessions; `user_settings` stores per-user configuration.
- `projects` stores project ownership and metadata.
- `manuscripts` stores manuscript content and processing state; `manuscript_versions` stores snapshots; `chapter_analyses` stores chapter-level extraction results; `chunks` stores chunk content and embeddings.
- `characters`, `relationships`, `locations`, `objects`, `object_custody_events`, and `events` represent story-world entities and occurrences.
- `claims` stores atomic narrative assertions; `issues` refers to claims by foreign key rather than copying their full values.
- `validation_candidates`, `knowledge_updates`, `world_rules`, `correction_rules`, `plot_threads`, and `project_customizations` represent workflow and project-level state.

Every physical table has a primary key. The schema also declares alternate uniqueness constraints for `users.email`, `user_settings.user_id`, `project_customizations.project_id`, and `(chapter_analyses.manuscript_id, chapter_number, content_hash)`.

### 3.3 Multi-valued attributes and the JSONB boundary

The current application schema deliberately stores some variable-shaped data as a single `JSONB` value, including:

- `characters.aliases` and `characters.physical_traits`
- `objects.mention_chapters`
- `events.participants`
- `chunks.paragraph_hashes`
- `chapter_analyses.result`
- `validation_candidates.payload`
- `issues.evidence` and `issues.related_entities`
- flexible configuration fields in `user_settings` and `project_customizations`
- `plot_threads.related_entities`

At the SQL type level, each JSONB column is one column value. At the conceptual data-model level, arrays such as aliases, participants, and mention chapters are collections. If the course expects strict relational 1NF at the element level, those collections should be decomposed into child relations (for example, `character_aliases(character_id, alias)`, `event_participants(event_id, character_id)`, and `object_mentions(object_id, chapter_number)`). The current application keeps them as JSONB for flexible extraction payloads and simpler writes; this is a documented denormalization/implementation trade-off, not proof that every nested element is a separate relational tuple.

The embedding `chunks.embedding VECTOR(384)` is one fixed-length vector value and is not a repeating relational group.

## 4. Second Normal Form (2NF)

### 4.1 Rule

A relation is in 2NF if it is in 1NF and every non-prime attribute is fully functionally dependent on every candidate key; no non-key attribute may depend on only part of a composite candidate key.

### 4.2 Application to NERRA

Most tables use a single-column UUID primary key. A single-attribute candidate key cannot have a proper non-empty subset, so partial dependency is not possible with respect to that key.

The important declared alternate/composite keys are:

| Relation | Candidate key / unique constraint | 2NF reasoning |
|---|---|---|
| `users` | `id`; `email` | Each identifies one account row. Account attributes depend on the selected key. |
| `user_settings` | `id`; `user_id` | `user_id` is unique, so one settings row belongs to one user. |
| `project_customizations` | `id`; `project_id` | `project_id` is unique, so one customization row belongs to one project. |
| `chapter_analyses` | `id`; `(manuscript_id, chapter_number, content_hash)` | The analysis result is for that manuscript chapter at that content hash; it is not determined by manuscript ID alone. |

The junction-style relationships are represented by separate rows. In a stricter bridge-table design, a pair such as `(event_id, character_id)` would be the composite key for event participation; no descriptive attribute should depend on only one side of that pair.

## 5. Third Normal Form (3NF)

### 5.1 Rule

A relation is in 3NF if it is in 2NF and, for every non-trivial functional dependency `X → A`, either `X` is a superkey or `A` is a prime attribute. Informally, non-key attributes should not depend transitively on another non-key attribute.

### 5.2 Dependencies separated by the schema

**Author and project metadata**

A denormalized design might store:

```text
PROJECT(project_id, title, owner_id, owner_email, owner_display_name)
```

with:

```text
project_id → owner_id
owner_id   → owner_email, owner_display_name
```

This creates a transitive dependency from `project_id` to author details. NERRA separates the data:

```text
users(id, email, password_hash, display_name, ...)
projects(id, owner_id, title, genre, ...)
```

`projects.owner_id` references `users.id`; user details are obtained by a join.

**Manuscript and chapter analysis**

Manuscript-level attributes belong in `manuscripts`. A chapter analysis stores `manuscript_id`, `chapter_number`, and `content_hash`, with its result in `chapter_analyses`. Manuscript title and project-owner details are not copied into each analysis row.

**Claims and issues**

A denormalized issue record might copy the subject, attribute, and values of both claims. Instead, `issues.claim_a_id` and `issues.claim_b_id` reference `claims.id`. Claim facts remain in `claims`; issue metadata remains in `issues`. This avoids updating the same claim description in multiple issue rows.

**Project customization**

Project-specific configuration is stored in `project_customizations`, keyed uniquely by `project_id`, rather than duplicated across every manuscript, chapter, or story entity.

### 5.3 Redundant project identifiers

Some child tables contain both a parent identifier and `project_id` (for example, `manuscript_versions`, `relationships`, and `object_custody_events`). This can be useful for tenant-scoped queries, but it introduces a consistency rule: the child row's `project_id` must agree with the project of its referenced parent row(s). The current simple foreign keys do not enforce every such cross-table equality. A production hardening step is to add composite unique keys and composite foreign keys, or derive the project through the parent join where query performance permits.

## 6. Key and integrity summary

| Relation | Primary key | Important alternate key / reference |
|---|---|---|
| `users` | `id` | `email` UNIQUE |
| `user_sessions` | `id` | `user_id` → `users.id` |
| `user_settings` | `id` | `user_id` UNIQUE → `users.id` |
| `projects` | `id` | `owner_id` → `users.id` |
| `manuscripts` | `id` | `project_id` → `projects.id` |
| `manuscript_versions` | `id` | `manuscript_id` → `manuscripts.id` |
| `chapter_analyses` | `id` | `(manuscript_id, chapter_number, content_hash)` UNIQUE |
| `chunks` | `id` | `manuscript_id` → `manuscripts.id` |
| `characters` | `id` | `project_id` → `projects.id` |
| `relationships` | `id` | `character_a_id`, `character_b_id` → `characters.id` |
| `locations` | `id` | `project_id` → `projects.id` |
| `objects` | `id` | `project_id` → `projects.id` |
| `object_custody_events` | `id` | `object_id` → `objects.id` |
| `events` | `id` | `project_id` → `projects.id` |
| `claims` | `id` | `project_id` → `projects.id` |
| `validation_candidates` | `id` | `project_id`, optional `manuscript_id` references |
| `knowledge_updates` | `id` | `project_id` → `projects.id` |
| `world_rules` | `id` | `project_id` → `projects.id` |
| `issues` | `id` | optional `claim_a_id`, `claim_b_id` → `claims.id` |
| `correction_rules` | `id` | `project_id` → `projects.id` |
| `plot_threads` | `id` | `project_id` → `projects.id` |
| `project_customizations` | `id` | `project_id` UNIQUE → `projects.id` |

## 7. Conclusion and limitations

The schema separates major entities and avoids copying user, manuscript, and claim attributes into dependent records. The declared keys and foreign keys provide the basis for 2NF/3NF analysis.

The current physical design is a **hybrid relational model**: canonical entities and workflow records are relational, while selected variable-shaped extraction/configuration payloads are JSONB and embeddings are vectors. Therefore, do not claim that every nested JSON array has been decomposed into a strict 1NF child relation. If the instructor requires strict element-level 1NF, the JSONB arrays listed in Section 3.3 should be converted to bridge/child tables and the ERD/DDL updated together.

Neo4j is a downstream graph projection. It does not replace PostgreSQL constraints or become part of this relational normalization proof.
