# DBMS Normalization: NERRA Data Model

**Team**: T0123  
**Project**: NERRA (Intelligent Story Operating System for Novelists & Narrative Designers)  
**Deliverable**: Checkpoint 1 (CP1) — `dbms/01_normalization.md`  

---

## 1. Overview & System Context

NERRA is an intelligent story operating system for authors and narrative designers. As manuscripts scale beyond 30,000+ words, writers suffer from narrative complexity collapse (timeline inconsistencies, conflicting character attributes, unresolved plot threads, broken entity relations). NERRA ingests manuscripts, parses chapters, extracts narrative entities and claims, and performs consistency checks.

This document presents the relational database design for NERRA's relational storage layer (PostgreSQL), taking the data model systematically through:
1. **Unnormalized Form (UNF)**
2. **First Normal Form (1NF)**
3. **Second Normal Form (2NF)**
4. **Third Normal Form (3NF)**
5. **Boyce-Codd Normal Form (BCNF) Evaluation**

---

## 2. Unnormalized Form (UNF)

In an unnormalized architecture, a single flat log or monolithic record attempts to represent all user operations, projects, manuscripts, extracted narrative entities, and issues.

### Universal Relation Schema: `UNF_NARRATIVE_RECORD`
```
UNF_NARRATIVE_RECORD (
    user_id,
    user_email,
    user_password_hash,
    user_display_name,
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
        { chapter_number, content_hash, result_json }
    ],
    characters: [
        { name, aliases: [...], status, physical_traits: {...}, first_chapter, last_chapter }
    ],
    locations: [
        { name, description, first_chapter }
    ],
    objects: [
        { name, description, first_chapter, mention_chapters: [...] }
    ],
    events: [
        { chapter_number, scene_order, story_time_order, temporal_anchor, summary, participants: [...] }
    ],
    claims: [
        { subject, attribute, value, chapter, evidence_quote, status }
    ],
    issues: [
        { issue_type, severity, description, status, claim_a_id, claim_b_id }
    ]
)
```

### Anomalies in UNF:
* **Repeating Groups / Multi-valued Attributes**: Arrays of characters, chapters, claims, objects, and nested extraction results violate atomicity.
* **Insertion Anomaly**: Cannot create a `User` without creating a `Project`, `Manuscript`, and `Character`.
* **Update Anomaly**: If a character's description or name changes, it must be updated in thousands of embedded rows.
* **Deletion Anomaly**: Deleting a manuscript inadvertently destroys author settings or character identities.

---

## 3. First Normal Form (1NF)

### Rules for 1NF:
1. Each column must contain atomic (indivisible) values.
2. No repeating groups or nested relation arrays.
3. A unique primary key exists for every relation.

### Flattening Repeating Groups into 1NF Tables:

To achieve 1NF, every nested array (characters, claims, events, objects, etc.) is extracted into distinct tabular relations, and multi-valued attributes (like aliases, mention chapters, participants) are converted into scalar foreign-key references or individual relational junction rows.

#### Table 1: `Users_1NF`
* `(user_id, email, password_hash, display_name, created_at)`
* **Primary Key**: `user_id`

#### Table 2: `Projects_1NF`
* `(project_id, owner_id, title, genre, created_at)`
* **Primary Key**: `project_id`

#### Table 3: `Manuscripts_1NF`
* `(manuscript_id, project_id, title, raw_text, status, chapters_done, chapters_total, error_note, created_at)`
* **Primary Key**: `manuscript_id`

#### Table 4: `ChapterAnalyses_1NF`
* `(analysis_id, manuscript_id, chapter_number, content_hash, raw_payload, created_at)`
* **Primary Key**: `analysis_id`

#### Table 5: `Characters_1NF`
* `(character_id, project_id, name, description, status, first_chapter, last_chapter, created_at)`
* **Primary Key**: `character_id`

#### Table 6: `CharacterAliases_1NF`
* `(alias_id, character_id, alias_name)`
* **Primary Key**: `alias_id` (or composite `(character_id, alias_name)`)

#### Table 7: `Locations_1NF`
* `(location_id, project_id, name, description, first_chapter)`
* **Primary Key**: `location_id`

#### Table 8: `Objects_1NF`
* `(object_id, project_id, name, description, first_chapter)`
* **Primary Key**: `object_id`

#### Table 9: `ObjectMentions_1NF`
* `(object_id, chapter_number)`
* **Primary Key**: `(object_id, chapter_number)`

#### Table 10: `Relationships_1NF`
* `(relationship_id, project_id, character_a_id, character_b_id, rel_type, sentiment, description, evidence_quote, chapter, until_chapter)`
* **Primary Key**: `relationship_id`

#### Table 11: `Events_1NF`
* `(event_id, project_id, chapter_number, scene_order, story_time_order, temporal_anchor, is_flashback, is_flashforward, summary, location_name, created_at)`
* **Primary Key**: `event_id`

#### Table 12: `EventParticipants_1NF`
* `(event_id, character_id)`
* **Primary Key**: `(event_id, character_id)`

#### Table 13: `Claims_1NF`
* `(claim_id, project_id, subject_id, attribute_name, claim_value, chapter, evidence_quote, source_paragraph_id, confidence, validation_state, status, created_at)`
* **Primary Key**: `claim_id`

#### Table 14: `KnowledgeUpdates_1NF`
* `(update_id, project_id, character_id, fact_text, chapter, how_learned, source_character_id)`
* **Primary Key**: `update_id`

#### Table 15: `Issues_1NF`
* `(issue_id, project_id, issue_type, severity, status, description, confidence, ai_reasoning, intent_classification, claim_a_id, claim_b_id, created_at)`
* **Primary Key**: `issue_id`

#### Table 16: `PlotThreads_1NF`
* `(thread_id, project_id, title, description, setup_chapter, payoff_chapter, status, evidence_quote, updated_at)`
* **Primary Key**: `thread_id`

---

## 4. Second Normal Form (2NF)

### Rules for 2NF:
1. Must be in 1NF.
2. No partial functional dependencies: every non-prime attribute must depend on the **whole candidate key** (no non-prime attribute can depend on a proper subset of a composite primary key).

### Functional Dependency & Partial Dependency Analysis:

Let us examine relations with composite candidate keys in 1NF:

#### 1. Relation `EventParticipants_1NF`:
* Composite Key: `{event_id, character_id}`
* Non-prime attributes: None (pure junction table).
* Dependencies:
  * `{event_id, character_id} -> None`
* **Result**: Satisfies 2NF.

#### 2. Relation `ObjectMentions_1NF`:
* Composite Key: `{object_id, chapter_number}`
* Non-prime attributes: None.
* Dependencies:
  * `{object_id, chapter_number} -> None`
* **Result**: Satisfies 2NF.

#### 3. Relation with potential partial dependency violation (hypothetical pre-2NF `ChapterAnalyses`):
If `ChapterAnalyses` was keyed by `(manuscript_id, chapter_number)` and stored `manuscript_title`:
* Composite Key: `{manuscript_id, chapter_number}`
* Dependency: `manuscript_id -> manuscript_title` (Partial dependency on subset of key!)
* **Resolution**: Decompose into `Manuscripts` (where `manuscript_id -> manuscript_title`) and `ChapterAnalyses` (keyed by surrogate `analysis_id` or `{manuscript_id, chapter_number}`). In our schema, `manuscript_title` lives exclusively in `Manuscripts`.

#### 4. Relation `Claims`:
* Candidate Key: `{claim_id}` (surrogate key) or natural key `{project_id, subject_id, attribute_name, chapter}`.
* Since all entities have single-attribute primary keys (`UUID` surrogate keys) and junction tables have only key attributes, **no partial dependency exists**.

Every table satisfies 2NF.

---

## 5. Third Normal Form (3NF)

### Rules for 3NF:
1. Must be in 2NF.
2. No transitive dependencies: no non-prime attribute may depend functionally on another non-prime attribute ($X \to Y$ where $X$ is not a superkey).

### Identifying and Eliminating Transitive Dependencies:

#### Issue Case: Entity Ownership via Project vs. User
Consider an un-decomposed claim or manuscript entity:
* `(claim_id, project_id, owner_id, owner_email, subject, attribute, value)`
* Dependency:
  * `claim_id -> project_id`
  * `project_id -> owner_id`
  * `owner_id -> owner_email`
* `owner_email` is transitively dependent on `claim_id` via `owner_id`.
* **3NF Resolution**:
  * Extract `Users(user_id, email, password_hash, display_name)`.
  * Extract `Projects(project_id, owner_id, title, genre)`.
  * `Claims` references only `project_id`. The user details are reached via foreign key joins `Claims -> Projects -> Users`.

#### Issue Case: Conflict/Issue Claim Details
Suppose `Issues` contained:
* `(issue_id, project_id, claim_a_id, claim_a_subject, claim_a_attribute, claim_a_value, claim_b_id, claim_b_value)`
* Dependency:
  * `issue_id -> claim_a_id`
  * `claim_a_id -> {claim_a_subject, claim_a_attribute, claim_a_value}`
* This is a transitive dependency ($issue\_id \to claim\_a\_id \to attributes$).
* **3NF Resolution**:
  * Store only foreign keys `claim_a_id` and `claim_b_id` in `Issues`.
  * The actual claim attributes are fetched via relational joins from `Claims(claim_id, ...)`.

#### Issue Case: Location & Character in Events
Suppose `Events` contained:
* `(event_id, location_id, location_name, location_description, summary)`
* Dependency:
  * `event_id -> location_id`
  * `location_id -> {location_name, location_description}`
* **3NF Resolution**:
  * Extract `Locations(location_id, project_id, name, description, first_chapter)`.
  * Store `location_id` in `Events`.

---

## 6. Boyce-Codd Normal Form (BCNF) Evaluation

### Definition of BCNF:
A relation $R$ is in BCNF if and only if for every non-trivial functional dependency $X \to Y$, $X$ is a **superkey** of $R$.

### Evaluation of Core NERRA Tables:

1. **`Users`**:
   * Functional Dependencies:
     * `user_id -> email, password_hash, display_name, created_at`
     * `email -> user_id, password_hash, display_name, created_at`
   * Both `user_id` and `email` are candidate keys (superkeys).
   * **In BCNF**: Yes.

2. **`Projects`**:
   * Functional Dependencies:
     * `project_id -> owner_id, title, genre, created_at`
   * Determinant `project_id` is candidate key.
   * **In BCNF**: Yes.

3. **`Manuscripts`**:
   * Functional Dependencies:
     * `manuscript_id -> project_id, title, raw_text, status, chapters_done, chapters_total, created_at`
   * Determinant `manuscript_id` is candidate key.
   * **In BCNF**: Yes.

4. **`Characters`**:
   * Functional Dependencies:
     * `character_id -> project_id, name, description, status, first_chapter, last_chapter, created_at`
   * Determinant `character_id` is candidate key.
   * **In BCNF**: Yes.

5. **`Relationships`**:
   * Functional Dependencies:
     * `relationship_id -> project_id, character_a_id, character_b_id, type, sentiment, description, evidence_quote, chapter, until_chapter`
   * Determinant `relationship_id` is candidate key.
   * **In BCNF**: Yes.

6. **`Claims`**:
   * Functional Dependencies:
     * `claim_id -> project_id, subject, attribute, value, chapter, evidence_quote, source_paragraph_id, confidence, validation_state, status, created_at`
   * Determinant `claim_id` is candidate key.
   * **In BCNF**: Yes.

7. **`Issues`**:
   * Functional Dependencies:
     * `issue_id -> project_id, type, severity, status, description, confidence, ai_reasoning, intent_classification, claim_a_id, claim_b_id, created_at`
   * Determinant `issue_id` is candidate key.
   * **In BCNF**: Yes.

### Summary:
All relation schemas in the final design satisfy 3NF and BCNF because all functional dependencies have a superkey on the left-hand side. There are no non-trivial dependencies on non-superkeys.

---

## 7. Final Normalized Relational Schema Summary

| Table Name | Primary Key | Foreign Keys | Normal Form | Purpose |
|:---|:---|:---|:---:|:---|
| `users` | `id` | None | BCNF | Author credentials and profiles |
| `user_sessions` | `id` | `user_id -> users(id)` | BCNF | Auth tokens, active sessions |
| `user_settings` | `id` | `user_id -> users(id)` | BCNF | Sovereign AI API keys & settings |
| `projects` | `id` | `owner_id -> users(id)` | BCNF | Story projects/novels |
| `manuscripts` | `id` | `project_id -> projects(id)` | BCNF | Manuscript documents and ingest state |
| `chapter_analyses` | `id` | `manuscript_id -> manuscripts(id)` | BCNF | Chapter level extraction caches |
| `chunks` | `id` | `manuscript_id -> manuscripts(id)` | BCNF | Text chunks & vector embeddings |
| `characters` | `id` | `project_id -> projects(id)` | BCNF | Extracted characters |
| `character_aliases` | `id` | `character_id -> characters(id)` | BCNF | 1NF/3NF atomic character aliases |
| `relationships` | `id` | `character_a_id -> characters(id)`, `character_b_id -> characters(id)` | BCNF | Inter-character relationships & sentiment |
| `locations` | `id` | `project_id -> projects(id)` | BCNF | Story world geographic locations |
| `objects` | `id` | `project_id -> projects(id)` | BCNF | Key story artifacts and items |
| `object_custody_events` | `id` | `object_id -> objects(id)` | BCNF | Custody timeline for props/artifacts |
| `events` | `id` | `project_id -> projects(id)` | BCNF | Timeline plot scenes and chronology |
| `claims` | `id` | `project_id -> projects(id)` | BCNF | Discrete narrative assertions (facts) |
| `knowledge_updates` | `id` | `project_id -> projects(id)` | BCNF | Epistemic state (who knows what when) |
| `issues` | `id` | `claim_a_id -> claims(id)`, `claim_b_id -> claims(id)` | BCNF | Consistency violations & contradictions |
| `plot_threads` | `id` | `project_id -> projects(id)` | BCNF | Arcs, setup, and payoff resolutions |

---

## 8. Conclusion

By completing 1NF, 2NF, 3NF, and BCNF normalization:
- **Redundancy is minimized**: Eliminating duplicate author, manuscript, and entity data across chapters.
- **Data integrity is guaranteed**: Foreign key constraints and unique constraints prevent orphaned narrative facts.
- **Anomalies are eliminated**: Authors can freely update character details or delete draft revisions without corrupting canon data.
- **Performance is optimized**: Smaller tuple footprints allow high-speed index scans and efficient joins in PostgreSQL.
