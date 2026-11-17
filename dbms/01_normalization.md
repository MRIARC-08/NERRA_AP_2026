# DBMS Normalization & Dual-Database Architecture: NERRA

**Team**: T0123  
**Project**: NERRA (Intelligent Story Operating System for Novelists & Narrative Designers)  
**Deliverable**: Checkpoint 1 (CP1) — `dbms/01_normalization.md`  
**Course Tracker**: [DBMS Project Tracker (T0123)](https://edusatyaki.github.io/dbms-project-tracker/)

---

## 1. Executive Summary & Dual-Database Paradigm

NERRA addresses the problem of **Narrative Complexity Collapse**: as long-form manuscripts exceed 30,000+ words, human memory falters under exponential character interactions, chronological anchors, object custody transfers, and epistemic state changes (who knows what when).

To solve this, NERRA employs a hybrid **Dual-Database Architecture**:
1. **Primary Relational & Vector Store (PostgreSQL 16 + `pgvector`)**:
   - Acts as the ACID **Source of Truth (SoT)**.
   - Houses user accounts, sovereign AI settings, manuscript drafts, chapter hashes, verbatim quote evidence, factual claims, validation staging gates, world rules, and dense vector embeddings (384-dimensional `all-MiniLM-L6-v2`) for semantic fuzzy recall.
2. **Graph Projection & Traversal Engine (Neo4j 5 Community / Cypher)**:
   - Projects the curated story world into a high-performance property graph.
   - Handles multi-hop relationship evolution, epistemic knowledge propagation paths, and topological constellation visualization (via AntV G6).
   - Designed to **gracefully degrade** to relational graph projections if Neo4j is offline or in isolated CI test environments.

This document formally normalizes the **Relational Source of Truth** through **1NF, 2NF, 3NF, and BCNF**, articulates why certain multi-valued semi-structured attributes are housed in JSONB / vectors, and defines the synchronization boundary between PostgreSQL and the Neo4j graph projection.

---

## 2. Unnormalized Form (UNF)

In an unnormalized monolithic design, an author's complete manuscript extraction and analysis session would be stored as an unconstrained, deeply nested hierarchical document.

### Universal Relation: `UNF_MANUSCRIPT_SESSION`

```text
UNF_MANUSCRIPT_SESSION (
    user_id,
    user_email,
    user_password_hash,
    display_name,
    anthropic_api_key,
    primary_model,
    project_id,
    project_title,
    project_genre,
    manuscript_id,
    manuscript_title,
    raw_text,
    manuscript_status,
    chapters_done,
    chapters_total,
    chapter_analyses: [
        { chapter_number, content_hash, raw_extraction_json }
    ],
    chunks: [
        { chapter_number, content, content_hash, paragraph_hashes, embedding_vector }
    ],
    characters: [
        { character_name, aliases: [...], description, status, physical_traits: {...}, first_chapter, last_chapter }
    ],
    relationships: [
        { character_a_name, character_b_name, rel_type, sentiment, evidence_quote, chapter, until_chapter }
    ],
    locations: [
        { location_name, description, first_chapter }
    ],
    objects: [
        { object_name, description, first_chapter, mention_chapters: [...] }
    ],
    object_custody_events: [
        { object_name, chapter, holder_type, holder_name, action, evidence_quote }
    ],
    events: [
        { chapter_number, scene_order, story_time_order, temporal_anchor, is_flashback, summary, participants: [...], location }
    ],
    claims: [
        { subject, attribute, value, chapter, evidence_quote, confidence, validation_state, status }
    ],
    knowledge_updates: [
        { character, fact, chapter, how_learned, source_character }
    ],
    validation_candidates: [
        { candidate_type, chapter, payload, confidence, route, status }
    ],
    issues: [
        { issue_type, severity, description, ai_reasoning, intent_classification, claim_a_subject, claim_a_value, claim_b_value }
    ],
    plot_threads: [
        { thread_title, description, setup_chapter, payoff_chapter, thread_status, related_entities: [...] }
    ]
)
```

### Critical Anomalies in UNF:
1. **Repeating Groups & Non-Atomic Data**: Repeated arrays of chapters, characters, claims, and timeline scenes violate atomicity.
2. **Insertion Anomalies**: An author cannot register or save sovereign LLM API key overrides without creating a manuscript and extracting entities.
3. **Update Anomalies**: If a character's physical trait (e.g. hair color) is updated, every denormalized record referencing that chapter or event must be redundantly modified.
4. **Deletion Anomalies**: Deleting a discarded manuscript draft unintentionally erases the author's world-building rules or character profile registry.

---

## 3. First Normal Form (1NF)

### Formal Requirements for 1NF:
1. All attributes must be atomic (no non-scalar repeating groups or nested tables).
2. Every relation must possess a uniquely identifiable primary key.
3. No duplicate rows.

### Normalization Process (UNF &rarr; 1NF):
All nested collections (analyses, chunks, characters, relationships, claims, timeline events, custody records, and issues) are extracted into distinct relational tables with unique surrogate primary keys (`UUID` / `uuid-ossp`) and foreign keys referencing parent entities.

#### Relational Entities in 1NF:

1. **`users_1nf`**:
   - `(id, email, password_hash, display_name, created_at)`
   - **Primary Key**: `{id}`
   - **Candidate Key**: `{email}`

2. **`user_sessions_1nf`**:
   - `(id, user_id, refresh_token_hash, user_agent, ip_address, is_revoked, expires_at, created_at, last_active_at)`
   - **Primary Key**: `{id}`

3. **`user_settings_1nf`**:
   - `(id, user_id, anthropic_api_key, anthropic_base_url, primary_model, embedding_model, max_hop_depth, extra_config, updated_at)`
   - **Primary Key**: `{id}`

4. **`projects_1nf`**:
   - `(id, owner_id, title, genre, created_at)`
   - **Primary Key**: `{id}`

5. **`manuscripts_1nf`**:
   - `(id, project_id, title, raw_text, status, chapters_done, chapters_total, error_note, created_at)`
   - **Primary Key**: `{id}`

6. **`chapter_analyses_1nf`**:
   - `(id, manuscript_id, chapter_number, content_hash, result, created_at)`
   - **Primary Key**: `{id}`
   - **Candidate Key**: `{manuscript_id, chapter_number, content_hash}`

7. **`chunks_1nf`**:
   - `(id, manuscript_id, chapter_number, content, content_hash, paragraph_hashes, embedding, created_at)`
   - **Primary Key**: `{id}`

8. **`characters_1nf`**:
   - `(id, project_id, name, description, status, physical_traits, first_chapter, last_chapter, created_at)`
   - **Primary Key**: `{id}`

9. **`character_aliases_1nf`**:
   - `(id, character_id, alias_name)`
   - **Primary Key**: `{id}`

10. **`relationships_1nf`**:
    - `(id, project_id, character_a_id, character_b_id, type, sentiment, description, evidence_quote, chapter, until_chapter, created_at)`
    - **Primary Key**: `{id}`

11. **`locations_1nf`**:
    - `(id, project_id, name, description, first_chapter, created_at)`
    - **Primary Key**: `{id}`

12. **`objects_1nf`**:
    - `(id, project_id, name, description, first_chapter, created_at)`
    - **Primary Key**: `{id}`

13. **`object_mentions_1nf`**:
    - `(id, object_id, chapter_number)`
    - **Primary Key**: `{id}`

14. **`object_custody_events_1nf`**:
    - `(id, project_id, object_id, chapter, holder_type, holder_name, action, evidence_quote, created_at)`
    - **Primary Key**: `{id}`

15. **`events_1nf`**:
    - `(id, project_id, chapter_number, scene_order, story_time_order, temporal_anchor, is_flashback, is_flashforward, summary, location, created_at)`
    - **Primary Key**: `{id}`

16. **`event_participants_1nf`**:
    - `(id, event_id, character_id)`
    - **Primary Key**: `{id}`

17. **`claims_1nf`**:
    - `(id, project_id, subject, attribute, value, chapter, evidence_quote, source_paragraph_id, extraction_version, confidence, validation_state, status, created_at)`
    - **Primary Key**: `{id}`

18. **`knowledge_updates_1nf`**:
    - `(id, project_id, character, fact, chapter, how_learned, source_character, created_at)`
    - **Primary Key**: `{id}`

19. **`validation_candidates_1nf`**:
    - `(id, project_id, manuscript_id, chapter, candidate_type, payload, confidence, route, ambiguity_reason, source_paragraph_id, evidence_quote, status, created_at)`
    - **Primary Key**: `{id}`

20. **`world_rules_1nf`**:
    - `(id, project_id, category, rule_text, source_chapter, is_author_defined, status, created_at)`
    - **Primary Key**: `{id}`

21. **`issues_1nf`**:
    - `(id, project_id, type, severity, status, description, evidence, confidence, ai_reasoning, intent_classification, related_entities, claim_a_id, claim_b_id, created_at)`
    - **Primary Key**: `{id}`

22. **`plot_threads_1nf`**:
    - `(id, project_id, title, description, setup_chapter, payoff_chapter, status, related_entities, evidence_quote, updated_at)`
    - **Primary Key**: `{id}`

23. **`manuscript_versions_1nf`**:
    - `(id, project_id, manuscript_id, version_number, content_hash, raw_text, diff_summary, created_at)`
    - **Primary Key**: `{id}`

---

## 4. Second Normal Form (2NF)

### Formal Requirements for 2NF:
1. The relation must satisfy 1NF.
2. **No Partial Functional Dependencies**: Every non-prime attribute must be fully functionally dependent on the entire primary key. No non-prime attribute can depend on a proper subset of any candidate key.

### Analysis of Candidate Keys & Functional Dependencies:

In our 1NF relational schema, each table utilizes an explicit surrogate primary key `id: UUID`. Where natural composite keys exist (such as in junction tables or analysis cache lookup keys), we evaluate whether partial dependencies can emerge:

#### Case 1: `chapter_analyses`
- **Candidate Keys**:
  - Surrogate Key: `{id}`
  - Natural Composite Key: `{manuscript_id, chapter_number, content_hash}`
- **Functional Dependencies**:
  - `{id} -> {manuscript_id, chapter_number, content_hash, result, created_at}`
  - `{manuscript_id, chapter_number, content_hash} -> {result, created_at}`
- **Evaluation**: The payload `result` and timestamp `created_at` depend on the specific analyzed chapter text content hash. Neither `manuscript_id` alone nor `{manuscript_id, chapter_number}` determines `result` (since chapter content evolves across drafts). Hence, all non-prime attributes depend on the **whole** composite key. **No partial dependencies exist.**

#### Case 2: `event_participants` & `object_mentions`
- Composite Keys: `{event_id, character_id}` and `{object_id, chapter_number}`.
- Attributes are solely foreign key pairings linking distinct entities. There are no dangling non-prime attributes dependent on only one component of the key.

#### Case 3: Elimination of Hypothetical Partial Dependencies:
If the analysis cache had been modeled as:
`CHAPTER_CACHE(manuscript_id, chapter_number, manuscript_title, chapter_analysis)`
Here, `{manuscript_id, chapter_number}` would be the primary key, but:
`manuscript_id -> manuscript_title`
This would be a classic partial dependency violation. We resolved this by keeping `manuscript_title` strictly inside the `manuscripts` table.

**Conclusion**: All relations satisfy 2NF.

---

## 5. Third Normal Form (3NF)

### Formal Requirements for 3NF:
1. The relation must satisfy 2NF.
2. **No Transitive Dependencies**: For every non-trivial functional dependency $X \to Y$, either:
   - $X$ is a superkey, or
   - $Y$ is a prime attribute (part of a candidate key).
   In other words, non-prime attributes must not depend on other non-prime attributes ($A \to B \to C$).

### Identification & Elimination of Transitive Dependencies:

#### 1. Transitive Dependency: Author Profile in Project Records
- **Violation in Denormalized Schema**:
  - `PROJECTS(project_id, project_title, user_id, user_email, user_display_name)`
  - FDs: `project_id -> user_id`, `user_id -> {user_email, user_display_name}`
  - Here, `user_email` and `user_display_name` are transitively dependent on `project_id` via `user_id`.
- **3NF Decomposition**:
  - `users(id, email, password_hash, display_name, created_at)`
  - `projects(id, owner_id, title, genre, created_at)`
  - `projects.owner_id` references `users.id`. Author details are retrieved via relational joins.

#### 2. Transitive Dependency: Story Issue & Contradictory Claims
- **Violation in Denormalized Schema**:
  - `ISSUES(issue_id, project_id, claim_a_id, claim_a_subject, claim_a_attribute, claim_a_val, claim_b_id, claim_b_val)`
  - FDs: `issue_id -> {claim_a_id, claim_b_id}`, `claim_a_id -> {claim_a_subject, claim_a_attribute, claim_a_val}`
  - Claim values are transitively dependent on `issue_id` via `claim_a_id`.
- **3NF Decomposition**:
  - `claims(id, project_id, subject, attribute, value, chapter, evidence_quote, ...)`
  - `issues(id, project_id, type, severity, status, description, claim_a_id, claim_b_id, ...)`
  - `claim_a_id` and `claim_b_id` are foreign keys to `claims.id`.

#### 3. Transitive Dependency: Object Custody Location
- **Violation in Denormalized Schema**:
  - `CUSTODY(custody_id, object_id, location_id, location_name, location_description)`
  - FDs: `custody_id -> location_id`, `location_id -> {location_name, location_description}`
- **3NF Decomposition**:
  - `locations(id, project_id, name, description, first_chapter)`
  - `object_custody_events(id, project_id, object_id, chapter, holder_type, holder_name, action, evidence_quote)`

---

## 6. Boyce-Codd Normal Form (BCNF) Evaluation

### Formal Definition:
A relation $R$ is in **BCNF** if and only if for every non-trivial functional dependency $X \to Y$, $X$ is a **superkey** (contains a candidate key of $R$).

### Table-by-Table Verification:

| Table | Candidate Keys | Functional Dependencies ($X \to Y$) | Is $X$ a Superkey? | In BCNF? |
|:---|:---|:---|:---:|:---:|
| `users` | `{id}`, `{email}` | `id -> email, password_hash, display_name`<br>`email -> id, password_hash, display_name` | Yes | **Yes** |
| `user_sessions` | `{id}`, `{refresh_token_hash}` | `id -> all attributes`<br>`refresh_token_hash -> all attributes` | Yes | **Yes** |
| `user_settings` | `{id}`, `{user_id}` | `id -> all attributes`<br>`user_id -> all attributes` | Yes | **Yes** |
| `projects` | `{id}` | `id -> owner_id, title, genre, created_at` | Yes | **Yes** |
| `manuscripts` | `{id}` | `id -> project_id, title, raw_text, status, ...` | Yes | **Yes** |
| `chapter_analyses` | `{id}`, `{manuscript_id, chapter_number, content_hash}` | `id -> all attributes`<br>`{manuscript_id, ch, hash} -> id, result, created_at` | Yes | **Yes** |
| `chunks` | `{id}` | `id -> manuscript_id, chapter_number, content, embedding, ...` | Yes | **Yes** |
| `characters` | `{id}` | `id -> project_id, name, description, status, ...` | Yes | **Yes** |
| `relationships` | `{id}` | `id -> project_id, character_a_id, character_b_id, type, ...` | Yes | **Yes** |
| `claims` | `{id}` | `id -> project_id, subject, attribute, value, chapter, ...` | Yes | **Yes** |
| `issues` | `{id}` | `id -> project_id, type, severity, status, claim_a_id, ...` | Yes | **Yes** |
| `validation_candidates` | `{id}` | `id -> project_id, candidate_type, payload, route, ...` | Yes | **Yes** |
| `world_rules` | `{id}` | `id -> project_id, category, rule_text, ...` | Yes | **Yes** |

Because every functional determinant in our relational tables is a superkey, **the schema strictly conforms to BCNF**.

---

## 7. Justification of Semi-Structured & Vector Types in Modern RDBMS

PostgreSQL 16 supports `JSONB` and native `VECTOR` datatypes. It is important to clarify why certain attributes are retained in `JSONB` or `VECTOR` rather than being shredded into millions of relational tuples:

1. **`chunks.embedding VECTOR(384)`**:
   - High-dimensional vector embeddings are atomic mathematical representations (points in $\mathbb{R}^{384}$).
   - PostgreSQL `pgvector` indexing (HNSW / IVFFlat) provides cosine similarity search directly within SQL transactions.
2. **`characters.physical_traits JSONB`** & **`characters.aliases JSONB`**:
   - Physical traits vary wildly by genre (e.g. `eye_color`, `scars`, `cybernetic_implants`, `magic_core`). Storing dynamic key-value pairs in JSONB avoids wide sparse tables or EAV (Entity-Attribute-Value) anti-patterns while retaining GIN indexability.
3. **`chapter_analyses.result JSONB`**:
   - Raw LLM extraction payloads serve as an immutable audit trail and extraction cache. Once parsed, canonical narrative assertions are promoted to first-class relational tables (`characters`, `claims`, `events`).

---

## 8. Dual-Database Architecture & Graph Projection Synchronization

The relational tables above serve as the **authoritative system of record**. The graph database (Neo4j) provides an operational projection for network traversals.

```
                    ┌────────────────────────────────────────┐
                    │       PostgreSQL 16 + pgvector         │
                    │         (Source of Truth)              │
                    │  • Users, Projects, Manuscripts        │
                    │  • Canonical Claims & Issues           │
                    │  • Raw Chunks & Vector Embeddings      │
                    └───────────────────┬────────────────────┘
                                        │
                         Projection / Transactional Sync
                         (app/services/graph.py)
                                        │
                                        ▼
                    ┌────────────────────────────────────────┐
                    │            Neo4j 5 Graph DB            │
                    │         (Traversals & RAG)             │
                    │  • Multi-hop Graph Traversal (Cypher)  │
                    │  • Epistemic Knowledge Paths           │
                    │  • AntV G6 Interactive Constellation   │
                    └────────────────────────────────────────┘
```

### Relational to Graph Mapping Matrix:

| Relational Table (PostgreSQL) | Graph Element (Neo4j) | Properties & Cypher Semantics |
|:---|:---|:---|
| `characters` | `(:StoryEntity {kind: 'character'})` | `id`, `label`, `status`, `first_chapter`, `last_chapter` |
| `locations` | `(:StoryEntity {kind: 'location'})` | `id`, `label`, `description` |
| `objects` | `(:StoryEntity {kind: 'object'})` | `id`, `label`, `mention_chapters` |
| `relationships` | `(a)-[:RELATIONSHIP]->(b)` | `type`, `sentiment`, `evidence_quote`, `chapter`, `until_chapter` |
| `events` | `(:StoryEntity {kind: 'event'})` | `chapter_number`, `scene_order`, `story_time_order`, `summary` |
| `event_participants` | `(char)-[:PARTICIPATED_IN]->(event)` | `role`, `chapter` |
| `events` &rarr; `locations` | `(event)-[:OCCURRED_AT]->(location)` | `since_chapter` |
| `plot_threads` | `(:StoryEntity {kind: 'thread'})` | `title`, `setup_chapter`, `payoff_chapter`, `status` |
| `claims` (contradictions) | `(claim_a)-[:CONTRADICTS]->(claim_b)` | `issue_id`, `severity` |

---

## 9. Conclusion

By executing 1NF, 2NF, 3NF, and BCNF normalization:
- **Redundancies are eliminated**: No duplicated manuscript text, author metadata, or claim citations.
- **ACID Guarantees**: Transactional consistency prevents orphaned issues, phantom claims, or inconsistent character references.
- **Architectural Harmony**: PostgreSQL delivers hardened transactional integrity and vector similarity search, while Neo4j executes recursive Cypher traversals and real-time narrative constellation visualizations.
