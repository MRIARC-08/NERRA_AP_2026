-- ============================================================================
-- NERRA Production Relational Schema (PostgreSQL 16 + pgvector)
-- Team: T0123 | Project: NERRA
-- Deliverable: CP2 - dbms/03_schema.sql
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ---------------------------------------------------------------------------
-- 1. IDENTITY & SOVEREIGN USER SETTINGS
-- ---------------------------------------------------------------------------

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(320) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash VARCHAR(128) NOT NULL,
    user_agent VARCHAR(512),
    ip_address VARCHAR(64),
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(refresh_token_hash);

CREATE TABLE user_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    anthropic_api_key VARCHAR(512),
    anthropic_base_url VARCHAR(512),
    primary_model VARCHAR(128) DEFAULT 'claude-3-5-sonnet-20241022',
    embedding_model VARCHAR(128) DEFAULT 'text-embedding-3-small',
    max_hop_depth INTEGER DEFAULT 2,
    extra_config JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 2. PROJECTS & MANUSCRIPT VERSIONING
-- ---------------------------------------------------------------------------

CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    genre VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_projects_owner_id ON projects(owner_id);

CREATE TABLE manuscripts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL DEFAULT 'Untitled manuscript',
    raw_text TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending | processing | ready | failed
    chapters_done INTEGER NOT NULL DEFAULT 0,
    chapters_total INTEGER NOT NULL DEFAULT 0,
    error_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_manuscripts_project_id ON manuscripts(project_id);

CREATE TABLE manuscript_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    manuscript_id UUID NOT NULL REFERENCES manuscripts(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL DEFAULT 1,
    content_hash VARCHAR(64) NOT NULL,
    raw_text TEXT NOT NULL,
    diff_summary JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_manuscript_versions_doc ON manuscript_versions(manuscript_id, version_number);

CREATE TABLE chapter_analyses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    manuscript_id UUID NOT NULL REFERENCES manuscripts(id) ON DELETE CASCADE,
    chapter_number INTEGER NOT NULL,
    content_hash VARCHAR(64) NOT NULL,
    result JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_chapter_analysis UNIQUE (manuscript_id, chapter_number, content_hash)
);

CREATE INDEX idx_chapter_analyses_manuscript ON chapter_analyses(manuscript_id);

CREATE TABLE chunks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    manuscript_id UUID NOT NULL REFERENCES manuscripts(id) ON DELETE CASCADE,
    chapter_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    content_hash VARCHAR(64) NOT NULL,
    paragraph_hashes JSONB DEFAULT '[]'::jsonb,
    embedding VECTOR(384),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chunks_manuscript_chapter ON chunks(manuscript_id, chapter_number);

-- ---------------------------------------------------------------------------
-- 3. STORY WORLD CANONICAL ENTITIES
-- ---------------------------------------------------------------------------

CREATE TABLE characters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    aliases JSONB DEFAULT '[]'::jsonb,
    description TEXT,
    status VARCHAR(50) DEFAULT 'unknown', -- alive | dead | unknown
    physical_traits JSONB DEFAULT '{}'::jsonb,
    first_chapter INTEGER,
    last_chapter INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_characters_project_id ON characters(project_id);
CREATE INDEX idx_characters_name ON characters(name);

CREATE TABLE relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    character_a_id UUID NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    character_b_id UUID NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    type VARCHAR(50) DEFAULT 'unknown',       -- family | friend | enemy | romantic | mentor | etc.
    sentiment VARCHAR(50) DEFAULT 'neutral',  -- positive | neutral | hostile | complex
    description TEXT,
    evidence_quote TEXT,
    chapter INTEGER,
    until_chapter INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_relationships_project ON relationships(project_id);
CREATE INDEX idx_relationships_chars ON relationships(character_a_id, character_b_id);

CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    first_chapter INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_locations_project ON locations(project_id);

CREATE TABLE objects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    first_chapter INTEGER,
    mention_chapters JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_objects_project ON objects(project_id);

CREATE TABLE object_custody_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    object_id UUID NOT NULL REFERENCES objects(id) ON DELETE CASCADE,
    chapter INTEGER NOT NULL,
    holder_type VARCHAR(50) DEFAULT 'character', -- character | location | unknown
    holder_name VARCHAR(255) NOT NULL,
    action VARCHAR(50) DEFAULT 'acquired',        -- acquired | lost | moved | locked | destroyed
    evidence_quote TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_custody_object ON object_custody_events(object_id);
CREATE INDEX idx_custody_project ON object_custody_events(project_id);

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    chapter_number INTEGER NOT NULL,
    scene_order INTEGER DEFAULT 1,
    story_time_order INTEGER DEFAULT 1,
    temporal_anchor VARCHAR(255),
    is_flashback BOOLEAN DEFAULT FALSE,
    is_flashforward BOOLEAN DEFAULT FALSE,
    summary TEXT NOT NULL,
    participants JSONB DEFAULT '[]'::jsonb,
    location VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_events_project ON events(project_id);
CREATE INDEX idx_events_timeline ON events(project_id, story_time_order);

-- ---------------------------------------------------------------------------
-- 4. CLAIMS, VALIDATION GATE & CONSISTENCY ISSUES
-- ---------------------------------------------------------------------------

CREATE TABLE claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    subject VARCHAR(255) NOT NULL,
    attribute VARCHAR(255) NOT NULL,
    value TEXT NOT NULL,
    chapter INTEGER NOT NULL,
    evidence_quote TEXT NOT NULL,
    source_paragraph_id VARCHAR(50),
    extraction_version INTEGER DEFAULT 1,
    confidence REAL DEFAULT 1.0,
    validation_state VARCHAR(50) DEFAULT 'AUTO_ACCEPTED', -- AUTO_ACCEPTED | PENDING_REVIEW | DISMISSED
    status VARCHAR(50) DEFAULT 'active',                  -- active | superseded | intentional
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_claims_project ON claims(project_id);
CREATE INDEX idx_claims_subject_attr ON claims(project_id, subject, attribute);

CREATE TABLE validation_candidates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    manuscript_id UUID REFERENCES manuscripts(id) ON DELETE CASCADE,
    chapter INTEGER NOT NULL,
    candidate_type VARCHAR(50) NOT NULL, -- character | alias | claim | relationship | location
    payload JSONB DEFAULT '{}'::jsonb,
    confidence REAL DEFAULT 0.7,
    route VARCHAR(50) DEFAULT 'human_review', -- auto_accepted | human_review | reject_hold
    ambiguity_reason TEXT,
    source_paragraph_id VARCHAR(50),
    evidence_quote TEXT,
    status VARCHAR(50) DEFAULT 'pending',     -- pending | approved | rejected | merged | split
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_validation_candidates_route ON validation_candidates(project_id, route, status);

CREATE TABLE knowledge_updates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    character VARCHAR(255) NOT NULL,
    fact TEXT NOT NULL,
    chapter INTEGER NOT NULL,
    how_learned VARCHAR(50) DEFAULT 'witnessed', -- witnessed | told | deduced | overheard
    source_character VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_knowledge_project ON knowledge_updates(project_id);
CREATE INDEX idx_knowledge_char ON knowledge_updates(project_id, character);

CREATE TABLE world_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    category VARCHAR(50) DEFAULT 'setting', -- magic | physics | society | setting
    rule_text TEXT NOT NULL,
    source_chapter INTEGER,
    is_author_defined BOOLEAN DEFAULT TRUE,
    status VARCHAR(50) DEFAULT 'active',    -- active | deprecated
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_world_rules_project ON world_rules(project_id);

CREATE TABLE issues (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    type VARCHAR(100) NOT NULL,                  -- attribute_contradiction | timeline_paradox | knowledge_leak | etc.
    severity VARCHAR(20) DEFAULT 'yellow',       -- red | yellow | info
    status VARCHAR(50) DEFAULT 'open',           -- open | acknowledged | resolved | dismissed
    description TEXT NOT NULL,
    evidence JSONB DEFAULT '[]'::jsonb,
    confidence REAL DEFAULT 0.9,
    ai_reasoning TEXT,
    intent_classification VARCHAR(50) DEFAULT 'error', -- error | intentional | ambiguous
    related_entities JSONB DEFAULT '[]'::jsonb,
    claim_a_id UUID REFERENCES claims(id) ON DELETE SET NULL,
    claim_b_id UUID REFERENCES claims(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_issues_project ON issues(project_id);
CREATE INDEX idx_issues_status ON issues(project_id, status);

CREATE TABLE correction_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    rule_type VARCHAR(100) NOT NULL, -- alias_merge | entity_split | character_rename | fact_override | plot_status
    target_entity VARCHAR(255) NOT NULL,
    instruction_text TEXT NOT NULL,
    payload JSONB DEFAULT '{}'::jsonb,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_correction_rules_project ON correction_rules(project_id, active);

CREATE TABLE plot_threads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    setup_chapter INTEGER DEFAULT 1,
    payoff_chapter INTEGER,
    status VARCHAR(50) DEFAULT 'open', -- open | resolved | abandoned | red_herring
    related_entities JSONB DEFAULT '[]'::jsonb,
    evidence_quote TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_plot_threads_project ON plot_threads(project_id);

CREATE TABLE project_customizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL UNIQUE REFERENCES projects(id) ON DELETE CASCADE,
    custom_context TEXT,
    custom_prompt TEXT,
    custom_validation JSONB DEFAULT '{}'::jsonb,
    custom_graph_write JSONB DEFAULT '{}'::jsonb,
    custom_ui_config JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
