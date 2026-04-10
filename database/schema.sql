-- Database schema for Faculty Student Management System
-- Code and comments in English, documentation in Spanish

CREATE ROLE :"owner_user";
CREATE ROLE :"app_user" WITH LOGIN PASSWORD :'app_password';

CREATE DATABASE faculty_management;
ALTER DATABASE faculty_management OWNER TO :"owner_user";

\c faculty_management;
SET ROLE :"owner_user";
GRANT CONNECT ON DATABASE faculty_management TO :"app_user";
ALTER SCHEMA public OWNER TO :"owner_user";

CREATE TABLE students_statuses (
    status_key VARCHAR(50) PRIMARY KEY,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL
);

CREATE TABLE enrollments_statuses (
    status_key VARCHAR(50) PRIMARY KEY,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL
);

CREATE TABLE students (
    numero_libreta VARCHAR(20) PRIMARY KEY,
    dni VARCHAR(20) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    enrollment_date DATE,
    status VARCHAR(50) REFERENCES students_statuses(status_key) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE subjects (
    cod_mat VARCHAR(20) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    credits INTEGER,
    department VARCHAR(100)
);

CREATE TABLE enrollments (
    numero_libreta VARCHAR(20) REFERENCES students(numero_libreta) ON UPDATE CASCADE,
    cod_mat VARCHAR(20) REFERENCES subjects(cod_mat) ON UPDATE CASCADE,
    enrollment_date DATE NOT NULL,
    grade DECIMAL(5,2),
    status VARCHAR(50) REFERENCES enrollments_statuses(status_key) ON UPDATE CASCADE ON DELETE RESTRICT,
    PRIMARY KEY (numero_libreta, cod_mat)
);

CREATE TABLE app_entities (
    entity_key VARCHAR(100) PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL UNIQUE,
    singular_es VARCHAR(200) NOT NULL,
    singular_en VARCHAR(200) NOT NULL,
    plural_es VARCHAR(200) NOT NULL,
    plural_en VARCHAR(200) NOT NULL,
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE app_data_types (
    data_type VARCHAR(100) PRIMARY KEY,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL
);

CREATE TABLE app_data_type_ui_profiles (
    data_type VARCHAR(100) PRIMARY KEY REFERENCES app_data_types(data_type) ON UPDATE CASCADE ON DELETE CASCADE,
    control VARCHAR(20),
    input_type VARCHAR(50),
    parser VARCHAR(30),
    step VARCHAR(20)
);

CREATE TABLE app_entity_columns (
    entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    column_name VARCHAR(100) NOT NULL,
    data_type VARCHAR(100) NOT NULL REFERENCES app_data_types(data_type) ON UPDATE CASCADE ON DELETE RESTRICT,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL,
    PRIMARY KEY (entity_key, column_name)
);

CREATE OR REPLACE FUNCTION normalize_app_entity_labels()
RETURNS TRIGGER AS $$
BEGIN
    NEW.singular_es := COALESCE(NULLIF(trim(NEW.singular_es), ''), initcap(replace(NEW.entity_key, '_', ' ')));
    NEW.singular_en := COALESCE(NULLIF(trim(NEW.singular_en), ''), initcap(replace(NEW.entity_key, '_', ' ')));
    NEW.plural_es := COALESCE(NULLIF(trim(NEW.plural_es), ''), NEW.singular_es || 's');
    NEW.plural_en := COALESCE(NULLIF(trim(NEW.plural_en), ''), NEW.singular_en || 's');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION normalize_app_entity_column_labels()
RETURNS TRIGGER AS $$
BEGIN
    NEW.label_es := COALESCE(NULLIF(trim(NEW.label_es), ''), initcap(replace(NEW.column_name, '_', ' ')));
    NEW.label_en := COALESCE(NULLIF(trim(NEW.label_en), ''), initcap(replace(NEW.column_name, '_', ' ')));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_app_entity_labels ON app_entities;
DROP TRIGGER IF EXISTS trg_normalize_app_entity_column_labels ON app_entity_columns;

CREATE TRIGGER trg_normalize_app_entity_labels
BEFORE INSERT OR UPDATE ON app_entities
FOR EACH ROW
EXECUTE FUNCTION normalize_app_entity_labels();

CREATE TRIGGER trg_normalize_app_entity_column_labels
BEFORE INSERT OR UPDATE ON app_entity_columns
FOR EACH ROW
EXECUTE FUNCTION normalize_app_entity_column_labels();

CREATE TABLE app_entity_column_nullability (
    entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    column_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (entity_key, column_name) REFERENCES app_entity_columns(entity_key, column_name) ON DELETE CASCADE,
    PRIMARY KEY (entity_key, column_name)
);

CREATE TABLE app_entity_column_uniqueness (
    entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    column_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (entity_key, column_name) REFERENCES app_entity_columns(entity_key, column_name) ON DELETE CASCADE,
    PRIMARY KEY (entity_key, column_name)
);

CREATE TABLE app_entity_primary_keys (
    entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    column_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (entity_key, column_name) REFERENCES app_entity_columns(entity_key, column_name) ON DELETE CASCADE,
    PRIMARY KEY (entity_key, position),
    UNIQUE (entity_key, column_name)
);

CREATE TABLE app_referential_actions (
    action_key VARCHAR(20) PRIMARY KEY,
    label_es VARCHAR(100) NOT NULL,
    label_en VARCHAR(100) NOT NULL
);

CREATE TABLE app_entity_foreign_key_groups (
    entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    foreign_key_key VARCHAR(100) NOT NULL,
    referenced_entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE RESTRICT,
    on_update_action VARCHAR(20) NOT NULL DEFAULT 'NO ACTION' REFERENCES app_referential_actions(action_key) ON UPDATE CASCADE ON DELETE RESTRICT,
    on_delete_action VARCHAR(20) NOT NULL DEFAULT 'NO ACTION' REFERENCES app_referential_actions(action_key) ON UPDATE CASCADE ON DELETE RESTRICT,
    PRIMARY KEY (entity_key, foreign_key_key),
    UNIQUE (entity_key, foreign_key_key, referenced_entity_key)
);

CREATE TABLE app_entity_foreign_keys (
    entity_key VARCHAR(100) NOT NULL,
    foreign_key_key VARCHAR(100) NOT NULL,
    position INTEGER NOT NULL,
    column_name VARCHAR(100) NOT NULL,
    referenced_entity_key VARCHAR(100) NOT NULL,
    referenced_column_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (entity_key) REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    FOREIGN KEY (entity_key, foreign_key_key) REFERENCES app_entity_foreign_key_groups(entity_key, foreign_key_key) ON DELETE CASCADE,
    FOREIGN KEY (entity_key, foreign_key_key, referenced_entity_key) REFERENCES app_entity_foreign_key_groups(entity_key, foreign_key_key, referenced_entity_key) ON DELETE CASCADE,
    FOREIGN KEY (entity_key, column_name) REFERENCES app_entity_columns(entity_key, column_name) ON DELETE CASCADE,
    FOREIGN KEY (referenced_entity_key, referenced_column_name) REFERENCES app_entity_columns(entity_key, column_name) ON DELETE RESTRICT,
    PRIMARY KEY (entity_key, foreign_key_key, position),
    UNIQUE (entity_key, foreign_key_key, column_name)
);

CREATE TABLE app_entity_foreign_key_dependencies (
    entity_key VARCHAR(100) NOT NULL,
    dependent_foreign_key_key VARCHAR(100) NOT NULL,
    required_foreign_key_key VARCHAR(100) NOT NULL,
    FOREIGN KEY (entity_key, dependent_foreign_key_key) REFERENCES app_entity_foreign_key_groups(entity_key, foreign_key_key) ON DELETE CASCADE,
    FOREIGN KEY (entity_key, required_foreign_key_key) REFERENCES app_entity_foreign_key_groups(entity_key, foreign_key_key) ON DELETE CASCADE,
    PRIMARY KEY (entity_key, dependent_foreign_key_key, required_foreign_key_key),
    CHECK (dependent_foreign_key_key <> required_foreign_key_key)
);

CREATE TABLE app_entity_foreign_key_dependency_mappings (
    entity_key VARCHAR(100) NOT NULL,
    dependent_foreign_key_key VARCHAR(100) NOT NULL,
    required_foreign_key_key VARCHAR(100) NOT NULL,
    shared_local_column_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (entity_key, dependent_foreign_key_key, required_foreign_key_key)
        REFERENCES app_entity_foreign_key_dependencies(entity_key, dependent_foreign_key_key, required_foreign_key_key) ON DELETE CASCADE,
    FOREIGN KEY (entity_key, dependent_foreign_key_key, shared_local_column_name)
        REFERENCES app_entity_foreign_keys(entity_key, foreign_key_key, column_name) ON DELETE CASCADE,
    FOREIGN KEY (entity_key, required_foreign_key_key, shared_local_column_name)
        REFERENCES app_entity_foreign_keys(entity_key, foreign_key_key, column_name) ON DELETE CASCADE,
    PRIMARY KEY (entity_key, dependent_foreign_key_key, required_foreign_key_key, shared_local_column_name)
);

CREATE OR REPLACE FUNCTION refresh_foreign_key_dependency_metadata(target_entity_key TEXT DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
    WITH fk_local_sets AS (
        SELECT
            entity_key,
            foreign_key_key,
            array_agg(column_name ORDER BY position) AS local_columns
        FROM app_entity_foreign_keys
        WHERE target_entity_key IS NULL OR entity_key = target_entity_key
        GROUP BY entity_key, foreign_key_key
    ),
    candidate_dependencies AS (
        SELECT
            child.entity_key,
            child.foreign_key_key AS dependent_foreign_key_key,
            parent.foreign_key_key AS required_foreign_key_key
        FROM fk_local_sets child
        JOIN fk_local_sets parent
          ON parent.entity_key = child.entity_key
         AND parent.foreign_key_key <> child.foreign_key_key
        WHERE parent.local_columns <@ child.local_columns
          AND parent.local_columns <> child.local_columns
    )
    INSERT INTO app_entity_foreign_key_dependencies (entity_key, dependent_foreign_key_key, required_foreign_key_key)
    SELECT entity_key, dependent_foreign_key_key, required_foreign_key_key
    FROM candidate_dependencies
    ON CONFLICT (entity_key, dependent_foreign_key_key, required_foreign_key_key) DO NOTHING;

    WITH fk_local_sets AS (
        SELECT
            entity_key,
            foreign_key_key,
            array_agg(column_name ORDER BY position) AS local_columns
        FROM app_entity_foreign_keys
        WHERE target_entity_key IS NULL OR entity_key = target_entity_key
        GROUP BY entity_key, foreign_key_key
    ),
    candidate_dependencies AS (
        SELECT
            child.entity_key,
            child.foreign_key_key AS dependent_foreign_key_key,
            parent.foreign_key_key AS required_foreign_key_key
        FROM fk_local_sets child
        JOIN fk_local_sets parent
          ON parent.entity_key = child.entity_key
         AND parent.foreign_key_key <> child.foreign_key_key
        WHERE parent.local_columns <@ child.local_columns
          AND parent.local_columns <> child.local_columns
    )
    DELETE FROM app_entity_foreign_key_dependencies existing
    WHERE (target_entity_key IS NULL OR existing.entity_key = target_entity_key)
      AND NOT EXISTS (
        SELECT 1
        FROM candidate_dependencies candidate
        WHERE candidate.entity_key = existing.entity_key
          AND candidate.dependent_foreign_key_key = existing.dependent_foreign_key_key
          AND candidate.required_foreign_key_key = existing.required_foreign_key_key
    );

    WITH fk_local_sets AS (
        SELECT
            entity_key,
            foreign_key_key,
            array_agg(column_name ORDER BY position) AS local_columns
        FROM app_entity_foreign_keys
        WHERE target_entity_key IS NULL OR entity_key = target_entity_key
        GROUP BY entity_key, foreign_key_key
    ),
    candidate_dependencies AS (
        SELECT
            child.entity_key,
            child.foreign_key_key AS dependent_foreign_key_key,
            parent.foreign_key_key AS required_foreign_key_key
        FROM fk_local_sets child
        JOIN fk_local_sets parent
          ON parent.entity_key = child.entity_key
         AND parent.foreign_key_key <> child.foreign_key_key
        WHERE parent.local_columns <@ child.local_columns
          AND parent.local_columns <> child.local_columns
    ),
    candidate_mappings AS (
        SELECT
            dependency.entity_key,
            dependency.dependent_foreign_key_key,
            dependency.required_foreign_key_key,
            child_col.column_name AS shared_local_column_name
        FROM candidate_dependencies dependency
        JOIN app_entity_foreign_keys child_col
          ON child_col.entity_key = dependency.entity_key
         AND child_col.foreign_key_key = dependency.dependent_foreign_key_key
        JOIN app_entity_foreign_keys parent_col
          ON parent_col.entity_key = dependency.entity_key
         AND parent_col.foreign_key_key = dependency.required_foreign_key_key
         AND parent_col.column_name = child_col.column_name
    )
    INSERT INTO app_entity_foreign_key_dependency_mappings (
        entity_key,
        dependent_foreign_key_key,
        required_foreign_key_key,
        shared_local_column_name
    )
    SELECT
        entity_key,
        dependent_foreign_key_key,
        required_foreign_key_key,
        shared_local_column_name
    FROM candidate_mappings
    ON CONFLICT (entity_key, dependent_foreign_key_key, required_foreign_key_key, shared_local_column_name) DO NOTHING;

    WITH fk_local_sets AS (
        SELECT
            entity_key,
            foreign_key_key,
            array_agg(column_name ORDER BY position) AS local_columns
        FROM app_entity_foreign_keys
        WHERE target_entity_key IS NULL OR entity_key = target_entity_key
        GROUP BY entity_key, foreign_key_key
    ),
    candidate_dependencies AS (
        SELECT
            child.entity_key,
            child.foreign_key_key AS dependent_foreign_key_key,
            parent.foreign_key_key AS required_foreign_key_key
        FROM fk_local_sets child
        JOIN fk_local_sets parent
          ON parent.entity_key = child.entity_key
         AND parent.foreign_key_key <> child.foreign_key_key
        WHERE parent.local_columns <@ child.local_columns
          AND parent.local_columns <> child.local_columns
    ),
    candidate_mappings AS (
        SELECT
            dependency.entity_key,
            dependency.dependent_foreign_key_key,
            dependency.required_foreign_key_key,
            child_col.column_name AS shared_local_column_name
        FROM candidate_dependencies dependency
        JOIN app_entity_foreign_keys child_col
          ON child_col.entity_key = dependency.entity_key
         AND child_col.foreign_key_key = dependency.dependent_foreign_key_key
        JOIN app_entity_foreign_keys parent_col
          ON parent_col.entity_key = dependency.entity_key
         AND parent_col.foreign_key_key = dependency.required_foreign_key_key
         AND parent_col.column_name = child_col.column_name
    )
    DELETE FROM app_entity_foreign_key_dependency_mappings existing
    WHERE (target_entity_key IS NULL OR existing.entity_key = target_entity_key)
      AND NOT EXISTS (
        SELECT 1
        FROM candidate_mappings candidate
        WHERE candidate.entity_key = existing.entity_key
          AND candidate.dependent_foreign_key_key = existing.dependent_foreign_key_key
          AND candidate.required_foreign_key_key = existing.required_foreign_key_key
          AND candidate.shared_local_column_name = existing.shared_local_column_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TABLE app_entity_hidden_columns (
    entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    column_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (entity_key, column_name) REFERENCES app_entity_columns(entity_key, column_name) ON DELETE CASCADE,
    PRIMARY KEY (entity_key, column_name)
);

CREATE TABLE app_shown_referenced_entity_columns (
    entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    referenced_entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    displayed_entity_column VARCHAR(100) NOT NULL,
    FOREIGN KEY (referenced_entity_key, displayed_entity_column) REFERENCES app_entity_columns(entity_key, column_name) ON DELETE CASCADE,
    PRIMARY KEY (entity_key, referenced_entity_key, displayed_entity_column)
);

CREATE TABLE app_entity_indexes (
    entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    index_name VARCHAR(100) NOT NULL,
    is_unique BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (entity_key, index_name)
);

CREATE TABLE app_entity_index_columns (
    entity_key VARCHAR(100) NOT NULL,
    index_name VARCHAR(100) NOT NULL,
    position INTEGER NOT NULL,
    column_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (entity_key, index_name) REFERENCES app_entity_indexes(entity_key, index_name) ON DELETE CASCADE,
    FOREIGN KEY (entity_key, column_name) REFERENCES app_entity_columns(entity_key, column_name) ON DELETE CASCADE,
    PRIMARY KEY (entity_key, index_name, position),
    UNIQUE (entity_key, index_name, column_name)
);

CREATE TABLE app_submenus (
    submenu_key VARCHAR(100) PRIMARY KEY,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL
);

CREATE TABLE app_submenu_entities (
    submenu_key VARCHAR(100) NOT NULL REFERENCES app_submenus(submenu_key) ON DELETE CASCADE,
    entity_key VARCHAR(100) NOT NULL REFERENCES app_entities(entity_key) ON DELETE CASCADE,
    PRIMARY KEY (submenu_key, entity_key)
);

CREATE TABLE ui_actions (
    action_key VARCHAR(100) PRIMARY KEY,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL
);

CREATE TABLE app_option_set_definitions (
    option_set_key VARCHAR(100) PRIMARY KEY,
    source_kind VARCHAR(50) NOT NULL,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL
);

CREATE TABLE app_ui_messages (
    message_key VARCHAR(100) PRIMARY KEY,
    text_es VARCHAR(300) NOT NULL,
    text_en VARCHAR(300) NOT NULL
);

BEGIN;
SET CONSTRAINTS ALL DEFERRED;

INSERT INTO app_entities (entity_key, table_name, is_allowed) VALUES
('app_entities', 'app_entities', TRUE),
('app_data_types', 'app_data_types', TRUE),
('app_data_type_ui_profiles', 'app_data_type_ui_profiles', TRUE),
('app_entity_columns', 'app_entity_columns', TRUE),
('app_entity_column_nullability', 'app_entity_column_nullability', TRUE),
('app_entity_column_uniqueness', 'app_entity_column_uniqueness', TRUE),
('app_entity_primary_keys', 'app_entity_primary_keys', TRUE),
('app_entity_foreign_key_groups', 'app_entity_foreign_key_groups', TRUE),
('app_entity_foreign_keys', 'app_entity_foreign_keys', TRUE),
('app_entity_foreign_key_dependencies', 'app_entity_foreign_key_dependencies', TRUE),
('app_entity_foreign_key_dependency_mappings', 'app_entity_foreign_key_dependency_mappings', TRUE),
('app_referential_actions', 'app_referential_actions', TRUE),
('app_entity_hidden_columns', 'app_entity_hidden_columns', TRUE),
('app_shown_referenced_entity_columns', 'app_shown_referenced_entity_columns', TRUE),
('app_entity_indexes', 'app_entity_indexes', TRUE),
('app_entity_index_columns', 'app_entity_index_columns', TRUE),
('app_submenus', 'app_submenus', TRUE),
('app_submenu_entities', 'app_submenu_entities', TRUE),
('ui_actions', 'ui_actions', TRUE),
('app_option_set_definitions', 'app_option_set_definitions', TRUE),
('app_ui_messages', 'app_ui_messages', TRUE),
('students_statuses', 'students_statuses', TRUE),
('enrollments_statuses', 'enrollments_statuses', TRUE),
('students', 'students', TRUE),
('subjects', 'subjects', TRUE),
('enrollments', 'enrollments', TRUE)
ON CONFLICT (entity_key) DO UPDATE SET
    table_name = EXCLUDED.table_name,
    is_allowed = EXCLUDED.is_allowed;

INSERT INTO app_data_types (data_type, label_es, label_en)
SELECT DISTINCT
    c.data_type,
    initcap(replace(c.data_type, '_', ' ')) AS label_es,
    initcap(replace(c.data_type, '_', ' ')) AS label_en
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name IN (
      SELECT table_name
      FROM app_entities
  )
ON CONFLICT (data_type) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

INSERT INTO app_data_type_ui_profiles (data_type, control, input_type, parser, step)
SELECT seed.data_type, seed.control, seed.input_type, seed.parser, seed.step
FROM (
    VALUES
    ('date', NULL, 'date', NULL, NULL),
    ('boolean', 'checkbox', NULL, 'boolean', NULL),
    ('json', 'textarea', NULL, 'string', NULL),
    ('jsonb', 'textarea', NULL, 'string', NULL),
    ('smallint', NULL, 'number', 'intOrNull', '1'),
    ('integer', NULL, 'number', 'intOrNull', '1'),
    ('bigint', NULL, 'number', 'intOrNull', '1'),
    ('numeric', NULL, 'number', 'floatOrNull', '0.01'),
    ('real', NULL, 'number', 'floatOrNull', '0.01'),
    ('double precision', NULL, 'number', 'floatOrNull', '0.01')
) AS seed(data_type, control, input_type, parser, step)
JOIN app_data_types d ON d.data_type = seed.data_type
ON CONFLICT (data_type) DO UPDATE SET
    control = EXCLUDED.control,
    input_type = EXCLUDED.input_type,
    parser = EXCLUDED.parser,
    step = EXCLUDED.step;

INSERT INTO app_entity_columns (entity_key, column_name, data_type)
SELECT
    e.entity_key,
    c.column_name,
    c.data_type
FROM app_entities e
JOIN information_schema.columns c
    ON c.table_schema = 'public'
   AND c.table_name = e.table_name
ON CONFLICT (entity_key, column_name) DO UPDATE SET
    data_type = EXCLUDED.data_type;

INSERT INTO app_entity_column_nullability (entity_key, column_name)
SELECT
    e.entity_key,
    c.column_name
FROM app_entities e
JOIN information_schema.columns c
    ON c.table_schema = 'public'
   AND c.table_name = e.table_name
WHERE c.is_nullable = 'YES'
ON CONFLICT (entity_key, column_name) DO NOTHING;

DELETE FROM app_entity_column_nullability n
USING app_entity_columns c, app_entities e, information_schema.columns i
WHERE n.entity_key = c.entity_key
  AND n.column_name = c.column_name
  AND c.entity_key = e.entity_key
  AND i.table_schema = 'public'
  AND i.table_name = e.table_name
  AND i.column_name = c.column_name
  AND i.is_nullable <> 'YES';

INSERT INTO app_entity_column_uniqueness (entity_key, column_name)
SELECT
    e.entity_key,
    c.column_name
FROM app_entities e
JOIN information_schema.columns c
    ON c.table_schema = 'public'
   AND c.table_name = e.table_name
WHERE EXISTS (
    SELECT 1
    FROM pg_class t
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN pg_index i ON i.indrelid = t.oid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = i.indkey[1]
    WHERE n.nspname = 'public'
      AND t.relname = e.table_name
      AND i.indisunique
      AND array_length(i.indkey, 1) = 1
      AND a.attname = c.column_name
      AND NOT i.indisprimary
)
ON CONFLICT (entity_key, column_name) DO NOTHING;

DELETE FROM app_entity_column_uniqueness u
USING app_entity_columns c, app_entities e, information_schema.columns i
WHERE u.entity_key = c.entity_key
  AND u.column_name = c.column_name
  AND c.entity_key = e.entity_key
  AND i.table_schema = 'public'
  AND i.table_name = e.table_name
  AND i.column_name = c.column_name
  AND NOT EXISTS (
      SELECT 1
      FROM pg_class t
      JOIN pg_namespace n ON n.oid = t.relnamespace
      JOIN pg_index idx ON idx.indrelid = t.oid
      JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = idx.indkey[1]
      WHERE n.nspname = 'public'
        AND t.relname = e.table_name
        AND idx.indisunique
        AND array_length(idx.indkey, 1) = 1
        AND a.attname = c.column_name
        AND NOT idx.indisprimary
  );

INSERT INTO app_entity_column_uniqueness (entity_key, column_name)
VALUES ('app_entities', 'table_name')
ON CONFLICT (entity_key, column_name) DO NOTHING;

INSERT INTO app_entity_primary_keys (entity_key, position, column_name)
SELECT
    seed.entity_key,
    seed.position,
    seed.column_name
FROM (
    VALUES
    ('app_entities', 1, 'entity_key'),
    ('app_data_types', 1, 'data_type'),
    ('app_data_type_ui_profiles', 1, 'data_type'),
    ('app_entity_columns', 1, 'entity_key'),
    ('app_entity_columns', 2, 'column_name'),
    ('app_entity_column_nullability', 1, 'entity_key'),
    ('app_entity_column_nullability', 2, 'column_name'),
    ('app_entity_column_uniqueness', 1, 'entity_key'),
    ('app_entity_column_uniqueness', 2, 'column_name'),
    ('app_entity_primary_keys', 1, 'entity_key'),
    ('app_entity_primary_keys', 2, 'position'),
    ('app_entity_foreign_key_groups', 1, 'entity_key'),
    ('app_entity_foreign_key_groups', 2, 'foreign_key_key'),
    ('app_entity_foreign_keys', 1, 'entity_key'),
    ('app_entity_foreign_keys', 2, 'foreign_key_key'),
    ('app_entity_foreign_keys', 3, 'position'),
    ('app_entity_foreign_key_dependencies', 1, 'entity_key'),
    ('app_entity_foreign_key_dependencies', 2, 'dependent_foreign_key_key'),
    ('app_entity_foreign_key_dependencies', 3, 'required_foreign_key_key'),
    ('app_entity_foreign_key_dependency_mappings', 1, 'entity_key'),
    ('app_entity_foreign_key_dependency_mappings', 2, 'dependent_foreign_key_key'),
    ('app_entity_foreign_key_dependency_mappings', 3, 'required_foreign_key_key'),
    ('app_entity_foreign_key_dependency_mappings', 4, 'shared_local_column_name'),
    ('app_referential_actions', 1, 'action_key'),
    ('app_entity_hidden_columns', 1, 'entity_key'),
    ('app_entity_hidden_columns', 2, 'column_name'),
    ('app_shown_referenced_entity_columns', 1, 'entity_key'),
    ('app_shown_referenced_entity_columns', 2, 'referenced_entity_key'),
    ('app_shown_referenced_entity_columns', 3, 'displayed_entity_column'),
    ('app_entity_indexes', 1, 'entity_key'),
    ('app_entity_indexes', 2, 'index_name'),
    ('app_entity_index_columns', 1, 'entity_key'),
    ('app_entity_index_columns', 2, 'index_name'),
    ('app_entity_index_columns', 3, 'position'),
    ('app_submenus', 1, 'submenu_key'),
    ('app_submenu_entities', 1, 'submenu_key'),
    ('app_submenu_entities', 2, 'entity_key'),
    ('ui_actions', 1, 'action_key'),
    ('app_option_set_definitions', 1, 'option_set_key'),
    ('app_ui_messages', 1, 'message_key'),
    ('students_statuses', 1, 'status_key'),
    ('enrollments_statuses', 1, 'status_key'),
    ('students', 1, 'numero_libreta'),
    ('subjects', 1, 'cod_mat'),
    ('enrollments', 1, 'numero_libreta'),
    ('enrollments', 2, 'cod_mat')
) AS seed(entity_key, position, column_name)
ON CONFLICT (entity_key, position) DO UPDATE SET
    column_name = EXCLUDED.column_name;

INSERT INTO app_submenus (submenu_key, label_es, label_en) VALUES
('metadata', 'Metadatos', 'Metadata'),
('tables', 'Tablas', 'Tables')
ON CONFLICT (submenu_key) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

INSERT INTO app_submenu_entities (submenu_key, entity_key) VALUES
('metadata', 'app_entities'),
('metadata', 'app_data_types'),
('metadata', 'app_data_type_ui_profiles'),
('metadata', 'app_entity_columns'),
('metadata', 'app_entity_column_nullability'),
('metadata', 'app_entity_column_uniqueness'),
('metadata', 'app_entity_primary_keys'),
('metadata', 'app_entity_foreign_key_groups'),
('metadata', 'app_entity_foreign_keys'),
('metadata', 'app_entity_foreign_key_dependencies'),
('metadata', 'app_entity_foreign_key_dependency_mappings'),
('metadata', 'app_referential_actions'),
('metadata', 'app_entity_hidden_columns'),
('metadata', 'app_shown_referenced_entity_columns'),
('metadata', 'app_entity_indexes'),
('metadata', 'app_entity_index_columns'),
('metadata', 'app_submenus'),
('metadata', 'app_submenu_entities'),
('metadata', 'ui_actions'),
('metadata', 'app_option_set_definitions'),
('metadata', 'app_ui_messages'),
('tables', 'students_statuses'),
('tables', 'enrollments_statuses'),
('tables', 'students'),
('tables', 'subjects'),
('tables', 'enrollments')
ON CONFLICT (submenu_key, entity_key) DO NOTHING;

INSERT INTO app_referential_actions (action_key, label_es, label_en) VALUES
('NO ACTION', 'Sin accion', 'No action'),
('RESTRICT', 'Restringir', 'Restrict'),
('CASCADE', 'Cascada', 'Cascade'),
('SET NULL', 'Establecer nulo', 'Set null'),
('SET DEFAULT', 'Establecer defecto', 'Set default')
ON CONFLICT (action_key) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

INSERT INTO app_entity_foreign_key_groups (entity_key, foreign_key_key, referenced_entity_key, on_update_action, on_delete_action)
SELECT
    source_entity.entity_key,
    con.conname AS foreign_key_key,
    referenced_entity.entity_key AS referenced_entity_key,
    CASE con.confupdtype
        WHEN 'a' THEN 'NO ACTION'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
        ELSE 'NO ACTION'
    END AS on_update_action,
    CASE con.confdeltype
        WHEN 'a' THEN 'NO ACTION'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
        ELSE 'NO ACTION'
    END AS on_delete_action
FROM pg_constraint con
JOIN pg_class source_table ON source_table.oid = con.conrelid
JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace
JOIN pg_class referenced_table ON referenced_table.oid = con.confrelid
JOIN pg_namespace referenced_ns ON referenced_ns.oid = referenced_table.relnamespace
JOIN app_entities source_entity ON source_entity.table_name = source_table.relname
JOIN app_entities referenced_entity ON referenced_entity.table_name = referenced_table.relname
WHERE con.contype = 'f'
  AND source_ns.nspname = 'public'
  AND referenced_ns.nspname = 'public'
ON CONFLICT (entity_key, foreign_key_key) DO UPDATE SET
    referenced_entity_key = EXCLUDED.referenced_entity_key,
    on_update_action = EXCLUDED.on_update_action,
    on_delete_action = EXCLUDED.on_delete_action;

INSERT INTO ui_actions (action_key, label_es, label_en) VALUES
('add', 'Agregar', 'Add'),
('edit', 'Editar', 'Edit'),
('update', 'Actualizar', 'Update'),
('delete', 'Eliminar', 'Delete'),
('cancel', 'Cancelar', 'Cancel'),
('openData', 'Abrir datos', 'Open data'),
('actions', 'Acciones', 'Actions')
ON CONFLICT (action_key) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

INSERT INTO app_option_set_definitions (option_set_key, source_kind, label_es, label_en) VALUES
('appEntities', 'entities', 'Entidades de app', 'App entities'),
('databaseTables', 'tables', 'Tablas de base de datos', 'Database tables'),
('referentialActions', 'referential_actions', 'Acciones referenciales', 'Referential actions'),
('uiActions', 'ui_actions', 'Acciones de UI', 'UI actions')
ON CONFLICT (option_set_key) DO UPDATE SET
    source_kind = EXCLUDED.source_kind,
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

INSERT INTO app_ui_messages (message_key, text_es, text_en) VALUES
('validationErrors', 'Errores de validacion', 'Validation errors'),
('deleteConfirm', 'Esta seguro de que desea eliminar este registro?', 'Are you sure you want to delete this record?'),
('required', 'es obligatorio', 'is required'),
('invalidFormat', 'formato invalido', 'invalid format'),
('mustBeAtLeast', 'debe ser >=', 'must be >='),
('mustBeAtMost', 'debe ser <=', 'must be <=')
ON CONFLICT (message_key) DO UPDATE SET
    text_es = EXCLUDED.text_es,
    text_en = EXCLUDED.text_en;

INSERT INTO app_entity_foreign_keys (entity_key, foreign_key_key, position, column_name, referenced_entity_key, referenced_column_name)
SELECT
        source_entity.entity_key,
        con.conname AS foreign_key_key,
        source_cols.ordinality AS position,
        source_attr.attname AS column_name,
        referenced_entity.entity_key AS referenced_entity_key,
        referenced_attr.attname AS referenced_column_name
FROM pg_constraint con
JOIN pg_class source_table ON source_table.oid = con.conrelid
JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace
JOIN pg_class referenced_table ON referenced_table.oid = con.confrelid
JOIN pg_namespace referenced_ns ON referenced_ns.oid = referenced_table.relnamespace
JOIN app_entities source_entity ON source_entity.table_name = source_table.relname
JOIN app_entities referenced_entity ON referenced_entity.table_name = referenced_table.relname
JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS source_cols(attnum, ordinality) ON TRUE
JOIN LATERAL unnest(con.confkey) WITH ORDINALITY AS referenced_cols(attnum, ordinality)
    ON referenced_cols.ordinality = source_cols.ordinality
JOIN pg_attribute source_attr ON source_attr.attrelid = source_table.oid AND source_attr.attnum = source_cols.attnum
JOIN pg_attribute referenced_attr ON referenced_attr.attrelid = referenced_table.oid AND referenced_attr.attnum = referenced_cols.attnum
WHERE con.contype = 'f'
    AND source_ns.nspname = 'public'
    AND referenced_ns.nspname = 'public'
ON CONFLICT (entity_key, foreign_key_key, position) DO UPDATE SET
        column_name = EXCLUDED.column_name,
        referenced_entity_key = EXCLUDED.referenced_entity_key,
        referenced_column_name = EXCLUDED.referenced_column_name;

DELETE FROM app_entity_foreign_keys fk
WHERE NOT EXISTS (
        SELECT 1
        FROM app_entity_foreign_key_groups fkg
        WHERE fkg.entity_key = fk.entity_key
            AND fkg.foreign_key_key = fk.foreign_key_key
);

DELETE FROM app_entity_foreign_key_groups fkg
WHERE NOT EXISTS (
        SELECT 1
        FROM app_entity_foreign_keys fk
        WHERE fk.entity_key = fkg.entity_key
            AND fk.foreign_key_key = fkg.foreign_key_key
);

SELECT refresh_foreign_key_dependency_metadata(NULL);

INSERT INTO app_entity_hidden_columns (entity_key, column_name) VALUES
('enrollments', 'numero_libreta'),
('enrollments', 'cod_mat')
ON CONFLICT (entity_key, column_name) DO NOTHING;

INSERT INTO app_shown_referenced_entity_columns (entity_key, referenced_entity_key, displayed_entity_column) VALUES
('enrollments', 'students', 'first_name'),
('enrollments', 'students', 'last_name'),
('enrollments', 'subjects', 'name')
ON CONFLICT (entity_key, referenced_entity_key, displayed_entity_column) DO NOTHING;

INSERT INTO app_entity_indexes (entity_key, index_name, is_unique) VALUES
('students', 'idx_students_status', FALSE),
('enrollments', 'idx_enrollments_status', FALSE)
ON CONFLICT (entity_key, index_name) DO UPDATE SET
    is_unique = EXCLUDED.is_unique;

INSERT INTO app_entity_index_columns (entity_key, index_name, position, column_name) VALUES
('students', 'idx_students_status', 1, 'status'),
('enrollments', 'idx_enrollments_status', 1, 'status')
ON CONFLICT (entity_key, index_name, position) DO UPDATE SET
    column_name = EXCLUDED.column_name;

UPDATE app_entities
SET
    singular_es = CASE entity_key
        WHEN 'students' THEN 'Alumno'
        WHEN 'subjects' THEN 'Materia'
        WHEN 'enrollments' THEN 'Inscripcion'
        WHEN 'app_entities' THEN 'Entidad de app'
        WHEN 'app_data_types' THEN 'Tipo de dato'
        WHEN 'app_data_type_ui_profiles' THEN 'Perfil UI de tipo de dato'
        WHEN 'app_entity_columns' THEN 'Columna de entidad'
        WHEN 'app_entity_column_nullability' THEN 'Nulabilidad de columna de entidad'
        WHEN 'app_entity_column_uniqueness' THEN 'Unicidad de columna de entidad'
        WHEN 'app_entity_primary_keys' THEN 'Clave primaria de entidad'
        WHEN 'app_entity_foreign_key_groups' THEN 'Grupo de clave foranea de entidad'
        WHEN 'app_entity_foreign_keys' THEN 'Clave foranea de entidad'
        WHEN 'app_entity_foreign_key_dependencies' THEN 'Dependencia de clave foranea de entidad'
        WHEN 'app_entity_foreign_key_dependency_mappings' THEN 'Mapeo de dependencia de clave foranea'
        WHEN 'app_entity_hidden_columns' THEN 'Columna oculta de entidad'
        WHEN 'app_shown_referenced_entity_columns' THEN 'Columna referenciada mostrada'
        WHEN 'app_entity_indexes' THEN 'Indice de entidad'
        WHEN 'app_entity_index_columns' THEN 'Columna de indice de entidad'
        WHEN 'app_submenus' THEN 'Submenu'
        WHEN 'app_submenu_entities' THEN 'Submenu por entidad'
        WHEN 'app_referential_actions' THEN 'Accion referencial'
        WHEN 'ui_actions' THEN 'Accion de UI'
        WHEN 'app_option_set_definitions' THEN 'Definicion de option set'
        WHEN 'app_ui_messages' THEN 'Mensaje de UI'
        WHEN 'students_statuses' THEN 'Estado de alumno'
        WHEN 'enrollments_statuses' THEN 'Estado de inscripcion'
        ELSE initcap(replace(entity_key, '_', ' '))
    END,
    singular_en = CASE entity_key
        WHEN 'students' THEN 'Student'
        WHEN 'subjects' THEN 'Subject'
        WHEN 'enrollments' THEN 'Enrollment'
        WHEN 'app_entities' THEN 'App Entity'
        WHEN 'app_data_types' THEN 'Data Type'
        WHEN 'app_data_type_ui_profiles' THEN 'Data Type UI Profile'
        WHEN 'app_entity_columns' THEN 'Entity Column'
        WHEN 'app_entity_column_nullability' THEN 'Entity Column Nullability'
        WHEN 'app_entity_column_uniqueness' THEN 'Entity Column Uniqueness'
        WHEN 'app_entity_primary_keys' THEN 'Entity Primary Key'
        WHEN 'app_entity_foreign_key_groups' THEN 'Entity Foreign Key Group'
        WHEN 'app_entity_foreign_keys' THEN 'Entity Foreign Key'
        WHEN 'app_entity_foreign_key_dependencies' THEN 'Entity Foreign Key Dependency'
        WHEN 'app_entity_foreign_key_dependency_mappings' THEN 'Entity Foreign Key Dependency Mapping'
        WHEN 'app_entity_hidden_columns' THEN 'Entity Hidden Column'
        WHEN 'app_shown_referenced_entity_columns' THEN 'Shown Referenced Entity Column'
        WHEN 'app_entity_indexes' THEN 'Entity Index'
        WHEN 'app_entity_index_columns' THEN 'Entity Index Column'
        WHEN 'app_submenus' THEN 'Submenu'
        WHEN 'app_submenu_entities' THEN 'Submenu by Entity'
        WHEN 'app_referential_actions' THEN 'Referential Action'
        WHEN 'ui_actions' THEN 'UI Action'
        WHEN 'app_option_set_definitions' THEN 'Option Set Definition'
        WHEN 'app_ui_messages' THEN 'UI Message'
        WHEN 'students_statuses' THEN 'Student Status'
        WHEN 'enrollments_statuses' THEN 'Enrollment Status'
        ELSE initcap(replace(entity_key, '_', ' '))
    END,
    plural_es = CASE entity_key
        WHEN 'students' THEN 'Alumnos'
        WHEN 'subjects' THEN 'Materias'
        WHEN 'enrollments' THEN 'Inscripciones'
        WHEN 'app_entities' THEN 'Entidades de la app'
        WHEN 'app_data_types' THEN 'Tipos de dato'
        WHEN 'app_data_type_ui_profiles' THEN 'Perfiles UI de tipos de dato'
        WHEN 'app_entity_columns' THEN 'Columnas de entidad'
        WHEN 'app_entity_column_nullability' THEN 'Nulabilidades de columna de entidad'
        WHEN 'app_entity_column_uniqueness' THEN 'Unicidades de columna de entidad'
        WHEN 'app_entity_primary_keys' THEN 'Claves primarias de entidad'
        WHEN 'app_entity_foreign_key_groups' THEN 'Grupos de clave foranea de entidad'
        WHEN 'app_entity_foreign_keys' THEN 'Claves foraneas de entidad'
        WHEN 'app_entity_foreign_key_dependencies' THEN 'Dependencias de claves foraneas'
        WHEN 'app_entity_foreign_key_dependency_mappings' THEN 'Mapeos de dependencias de claves foraneas'
        WHEN 'app_entity_hidden_columns' THEN 'Columnas ocultas de entidad'
        WHEN 'app_shown_referenced_entity_columns' THEN 'Columnas referenciadas mostradas'
        WHEN 'app_entity_indexes' THEN 'Indices de entidad'
        WHEN 'app_entity_index_columns' THEN 'Columnas de indice de entidad'
        WHEN 'app_submenus' THEN 'Submenus'
        WHEN 'app_submenu_entities' THEN 'Submenus por entidad'
        WHEN 'app_referential_actions' THEN 'Acciones referenciales'
        WHEN 'ui_actions' THEN 'Acciones de UI'
        WHEN 'app_option_set_definitions' THEN 'Definiciones de option set'
        WHEN 'app_ui_messages' THEN 'Mensajes de UI'
        WHEN 'students_statuses' THEN 'Estados de alumnos'
        WHEN 'enrollments_statuses' THEN 'Estados de inscripciones'
        ELSE initcap(replace(entity_key, '_', ' ')) || 's'
    END,
    plural_en = CASE entity_key
        WHEN 'students' THEN 'Students'
        WHEN 'subjects' THEN 'Subjects'
        WHEN 'enrollments' THEN 'Enrollments'
        WHEN 'app_entities' THEN 'App Entities'
        WHEN 'app_data_types' THEN 'Data Types'
        WHEN 'app_data_type_ui_profiles' THEN 'Data Type UI Profiles'
        WHEN 'app_entity_columns' THEN 'Entity Columns'
        WHEN 'app_entity_column_nullability' THEN 'Entity Column Nullabilities'
        WHEN 'app_entity_column_uniqueness' THEN 'Entity Column Uniqueness Rules'
        WHEN 'app_entity_primary_keys' THEN 'Entity Primary Keys'
        WHEN 'app_entity_foreign_key_groups' THEN 'Entity Foreign Key Groups'
        WHEN 'app_entity_foreign_keys' THEN 'Entity Foreign Keys'
        WHEN 'app_entity_foreign_key_dependencies' THEN 'Entity Foreign Key Dependencies'
        WHEN 'app_entity_foreign_key_dependency_mappings' THEN 'Entity Foreign Key Dependency Mappings'
        WHEN 'app_entity_hidden_columns' THEN 'Entity Hidden Columns'
        WHEN 'app_shown_referenced_entity_columns' THEN 'Shown Referenced Entity Columns'
        WHEN 'app_entity_indexes' THEN 'Entity Indexes'
        WHEN 'app_entity_index_columns' THEN 'Entity Index Columns'
        WHEN 'app_submenus' THEN 'Submenus'
        WHEN 'app_submenu_entities' THEN 'Submenus by Entity'
        WHEN 'app_referential_actions' THEN 'Referential Actions'
        WHEN 'ui_actions' THEN 'UI Actions'
        WHEN 'app_option_set_definitions' THEN 'Option Set Definitions'
        WHEN 'app_ui_messages' THEN 'UI Messages'
        WHEN 'students_statuses' THEN 'Student Statuses'
        WHEN 'enrollments_statuses' THEN 'Enrollment Statuses'
        ELSE initcap(replace(entity_key, '_', ' ')) || 's'
    END;

ALTER TABLE app_entities ALTER COLUMN singular_es SET NOT NULL;
ALTER TABLE app_entities ALTER COLUMN singular_en SET NOT NULL;
ALTER TABLE app_entities ALTER COLUMN plural_es SET NOT NULL;
ALTER TABLE app_entities ALTER COLUMN plural_en SET NOT NULL;

UPDATE app_entity_columns
SET
    label_es = CASE column_name
        WHEN 'numero_libreta' THEN 'Numero de Libreta'
        WHEN 'dni' THEN 'DNI'
        WHEN 'first_name' THEN 'Nombre'
        WHEN 'last_name' THEN 'Apellido'
        WHEN 'email' THEN 'Email'
        WHEN 'enrollment_date' THEN 'Fecha de Inscripcion'
        WHEN 'status' THEN 'Estado'
        WHEN 'cod_mat' THEN 'Codigo de Materia'
        WHEN 'name' THEN 'Nombre'
        WHEN 'description' THEN 'Descripcion'
        WHEN 'credits' THEN 'Creditos'
        WHEN 'department' THEN 'Departamento'
        WHEN 'grade' THEN 'Nota'
        WHEN 'entity_key' THEN 'Clave de entidad'
        WHEN 'column_name' THEN 'Nombre de columna'
        WHEN 'index_name' THEN 'Nombre de indice'
        WHEN 'table_name' THEN 'Nombre de tabla'
        WHEN 'referenced_entity_key' THEN 'Entidad referenciada'
        WHEN 'referenced_column_name' THEN 'Columna referenciada'
        WHEN 'displayed_entity_column' THEN 'Columna mostrada'
        WHEN 'foreign_key_key' THEN 'Clave de FK'
        WHEN 'position' THEN 'Posicion'
        WHEN 'on_update_action' THEN 'Accion al actualizar'
        WHEN 'on_delete_action' THEN 'Accion al eliminar'
        WHEN 'dependent_foreign_key_key' THEN 'Clave FK dependiente'
        WHEN 'required_foreign_key_key' THEN 'Clave FK requerida'
        WHEN 'shared_local_column_name' THEN 'Columna local compartida'
        WHEN 'action_key' THEN 'Accion'
        WHEN 'option_set_key' THEN 'Clave de option set'
        WHEN 'source_kind' THEN 'Tipo de fuente'
        WHEN 'message_key' THEN 'Clave de mensaje'
        WHEN 'text_es' THEN 'Texto ES'
        WHEN 'text_en' THEN 'Texto EN'
        WHEN 'submenu_key' THEN 'Submenu'
        WHEN 'is_allowed' THEN 'Permitido'
        WHEN 'is_unique' THEN 'Es unico'
        WHEN 'is_nullable' THEN 'Es nulo'
        WHEN 'label_es' THEN 'Etiqueta ES'
        WHEN 'label_en' THEN 'Etiqueta EN'
        WHEN 'data_type' THEN 'Tipo de dato'
        ELSE initcap(replace(column_name, '_', ' '))
    END,
    label_en = CASE column_name
        WHEN 'numero_libreta' THEN 'Student ID'
        WHEN 'dni' THEN 'ID Number'
        WHEN 'first_name' THEN 'First Name'
        WHEN 'last_name' THEN 'Last Name'
        WHEN 'email' THEN 'Email'
        WHEN 'enrollment_date' THEN 'Enrollment Date'
        WHEN 'status' THEN 'Status'
        WHEN 'cod_mat' THEN 'Subject Code'
        WHEN 'name' THEN 'Name'
        WHEN 'description' THEN 'Description'
        WHEN 'credits' THEN 'Credits'
        WHEN 'department' THEN 'Department'
        WHEN 'grade' THEN 'Grade'
        WHEN 'entity_key' THEN 'Entity Key'
        WHEN 'column_name' THEN 'Column Name'
        WHEN 'index_name' THEN 'Index Name'
        WHEN 'table_name' THEN 'Table Name'
        WHEN 'referenced_entity_key' THEN 'Referenced Entity'
        WHEN 'referenced_column_name' THEN 'Referenced Column'
        WHEN 'displayed_entity_column' THEN 'Displayed Column'
        WHEN 'foreign_key_key' THEN 'FK Key'
        WHEN 'position' THEN 'Position'
        WHEN 'on_update_action' THEN 'On Update Action'
        WHEN 'on_delete_action' THEN 'On Delete Action'
        WHEN 'dependent_foreign_key_key' THEN 'Dependent FK Key'
        WHEN 'required_foreign_key_key' THEN 'Required FK Key'
        WHEN 'shared_local_column_name' THEN 'Shared Local Column'
        WHEN 'action_key' THEN 'Action'
        WHEN 'option_set_key' THEN 'Option set key'
        WHEN 'source_kind' THEN 'Source kind'
        WHEN 'message_key' THEN 'Message key'
        WHEN 'text_es' THEN 'Text ES'
        WHEN 'text_en' THEN 'Text EN'
        WHEN 'submenu_key' THEN 'Submenu'
        WHEN 'is_allowed' THEN 'Allowed'
        WHEN 'is_unique' THEN 'Is unique'
        WHEN 'is_nullable' THEN 'Is nullable'
        WHEN 'label_es' THEN 'Label ES'
        WHEN 'label_en' THEN 'Label EN'
        WHEN 'data_type' THEN 'Data type'
        ELSE initcap(replace(column_name, '_', ' '))
    END;

ALTER TABLE app_entity_columns ALTER COLUMN label_es SET NOT NULL;
ALTER TABLE app_entity_columns ALTER COLUMN label_en SET NOT NULL;

INSERT INTO students_statuses (status_key, label_es, label_en) VALUES
('active', 'Activo', 'Active'),
('graduated', 'Graduado', 'Graduated'),
('interrupted', 'Interrumpido', 'Interrupted')
ON CONFLICT (status_key) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

INSERT INTO enrollments_statuses (status_key, label_es, label_en) VALUES
('enrolled', 'Inscrito', 'Enrolled'),
('completed', 'Completado', 'Completed'),
('failed', 'Fallido', 'Failed')
ON CONFLICT (status_key) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

DO $$
DECLARE
    column_record RECORD;
    managed_constraint_name TEXT;
BEGIN
    CREATE TEMP TABLE tmp_entity_column_constraints ON COMMIT DROP AS
        SELECT
            c.entity_key,
            e.table_name,
            c.column_name,
            EXISTS (
                SELECT 1
                FROM app_entity_column_nullability n
                WHERE n.entity_key = c.entity_key
                  AND n.column_name = c.column_name
            ) AS is_nullable,
            EXISTS (
                SELECT 1
                FROM app_entity_column_uniqueness u
                WHERE u.entity_key = c.entity_key
                  AND u.column_name = c.column_name
            ) AS is_unique
        FROM app_entity_columns c
        JOIN app_entities e ON e.entity_key = c.entity_key
        ORDER BY c.entity_key, c.column_name;

    FOR column_record IN
        SELECT entity_key, table_name, column_name, is_nullable, is_unique
        FROM tmp_entity_column_constraints
    LOOP
        IF column_record.is_nullable THEN
            EXECUTE format('ALTER TABLE %I ALTER COLUMN %I DROP NOT NULL', column_record.table_name, column_record.column_name);
        ELSE
            EXECUTE format('ALTER TABLE %I ALTER COLUMN %I SET NOT NULL', column_record.table_name, column_record.column_name);
        END IF;

        managed_constraint_name := format('uq_meta_%s_%s', column_record.table_name, column_record.column_name);
        IF length(managed_constraint_name) > 63 THEN
            managed_constraint_name := 'uqm_' || substr(md5(column_record.table_name || '_' || column_record.column_name), 1, 27);
        END IF;

        IF column_record.is_unique THEN
            IF NOT EXISTS (
                SELECT 1
                FROM pg_constraint con
                JOIN pg_class rel ON rel.oid = con.conrelid
                JOIN pg_namespace ns ON ns.oid = rel.relnamespace
                JOIN unnest(con.conkey) AS key_col(attnum) ON TRUE
                JOIN pg_attribute attr ON attr.attrelid = rel.oid AND attr.attnum = key_col.attnum
                WHERE ns.nspname = 'public'
                  AND rel.relname = column_record.table_name
                  AND con.contype IN ('p', 'u')
                GROUP BY con.oid
                HAVING COUNT(*) = 1 AND max(attr.attname) = column_record.column_name
            ) THEN
                EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I UNIQUE (%I)', column_record.table_name, managed_constraint_name, column_record.column_name);
            END IF;
        ELSE
            IF EXISTS (
                SELECT 1
                FROM pg_constraint con
                JOIN pg_class rel ON rel.oid = con.conrelid
                JOIN pg_namespace ns ON ns.oid = rel.relnamespace
                WHERE ns.nspname = 'public'
                  AND rel.relname = column_record.table_name
                  AND con.conname = managed_constraint_name
            ) THEN
                EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', column_record.table_name, managed_constraint_name);
            END IF;
        END IF;
    END LOOP;
END $$;

CREATE OR REPLACE FUNCTION apply_entity_column_nullability_constraints()
RETURNS TRIGGER AS $$
DECLARE
    target_entity_key TEXT;
    target_column_name TEXT;
    table_name_value TEXT;
BEGIN
    target_entity_key := COALESCE(NEW.entity_key, OLD.entity_key);
    target_column_name := COALESCE(NEW.column_name, OLD.column_name);

    SELECT table_name INTO table_name_value
    FROM app_entities
    WHERE entity_key = target_entity_key;

    IF table_name_value IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF TG_OP = 'DELETE' THEN
        EXECUTE format('ALTER TABLE %I ALTER COLUMN %I SET NOT NULL', table_name_value, target_column_name);
    ELSE
        EXECUTE format('ALTER TABLE %I ALTER COLUMN %I DROP NOT NULL', table_name_value, target_column_name);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION apply_entity_column_uniqueness_constraints()
RETURNS TRIGGER AS $$
DECLARE
    target_entity_key TEXT;
    target_column_name TEXT;
    table_name_value TEXT;
    managed_constraint_name TEXT;
BEGIN
    target_entity_key := COALESCE(NEW.entity_key, OLD.entity_key);
    target_column_name := COALESCE(NEW.column_name, OLD.column_name);

    SELECT table_name INTO table_name_value
    FROM app_entities
    WHERE entity_key = target_entity_key;

    IF table_name_value IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    managed_constraint_name := format('uq_meta_%s_%s', table_name_value, target_column_name);
    IF length(managed_constraint_name) > 63 THEN
        managed_constraint_name := 'uqm_' || substr(md5(table_name_value || '_' || target_column_name), 1, 27);
    END IF;

    IF TG_OP <> 'DELETE' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_constraint con
            JOIN pg_class rel ON rel.oid = con.conrelid
            JOIN pg_namespace ns ON ns.oid = rel.relnamespace
            JOIN unnest(con.conkey) AS key_col(attnum) ON TRUE
            JOIN pg_attribute attr ON attr.attrelid = rel.oid AND attr.attnum = key_col.attnum
            WHERE ns.nspname = 'public'
              AND rel.relname = table_name_value
              AND con.contype IN ('p', 'u')
            GROUP BY con.oid
            HAVING COUNT(*) = 1 AND max(attr.attname) = target_column_name
        ) THEN
            EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I UNIQUE (%I)', table_name_value, managed_constraint_name, target_column_name);
        END IF;
    ELSE
        IF EXISTS (
            SELECT 1
            FROM pg_constraint con
            JOIN pg_class rel ON rel.oid = con.conrelid
            JOIN pg_namespace ns ON ns.oid = rel.relnamespace
            WHERE ns.nspname = 'public'
              AND rel.relname = table_name_value
              AND con.conname = managed_constraint_name
        ) THEN
            EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', table_name_value, managed_constraint_name);
        END IF;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_apply_entity_column_nullability_constraints ON app_entity_column_nullability;
DROP TRIGGER IF EXISTS trg_apply_entity_column_uniqueness_constraints ON app_entity_column_uniqueness;

CREATE TRIGGER trg_apply_entity_column_nullability_constraints
AFTER INSERT OR DELETE OR UPDATE OF entity_key, column_name ON app_entity_column_nullability
FOR EACH ROW
EXECUTE FUNCTION apply_entity_column_nullability_constraints();

CREATE TRIGGER trg_apply_entity_column_uniqueness_constraints
AFTER INSERT OR DELETE OR UPDATE OF entity_key, column_name ON app_entity_column_uniqueness
FOR EACH ROW
EXECUTE FUNCTION apply_entity_column_uniqueness_constraints();

CREATE OR REPLACE FUNCTION metadata_managed_pk_constraint_name(target_table_name TEXT)
RETURNS TEXT AS $$
DECLARE
    constraint_name TEXT;
BEGIN
    constraint_name := format('pk_meta_%s', target_table_name);
    IF length(constraint_name) > 63 THEN
        constraint_name := 'pkm_' || substr(md5(target_table_name), 1, 59);
    END IF;
    RETURN constraint_name;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION metadata_managed_index_name(target_entity_key TEXT, target_index_name TEXT)
RETURNS TEXT AS $$
DECLARE
    physical_name TEXT;
BEGIN
    physical_name := format('idx_meta_%s_%s', target_entity_key, target_index_name);
    IF length(physical_name) > 63 THEN
        physical_name := 'idxm_' || substr(md5(target_entity_key || '_' || target_index_name), 1, 58);
    END IF;
    RETURN physical_name;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION sync_entity_columns_and_pk(target_entity_key TEXT, target_table_name TEXT)
RETURNS VOID AS $$
DECLARE
    column_record RECORD;
    existing_column RECORD;
    pk_constraint_record RECORD;
    pk_columns TEXT;
    pk_constraint_name TEXT;
BEGIN
    IF target_entity_key IS NULL OR target_table_name IS NULL THEN
        RETURN;
    END IF;

    IF target_entity_key LIKE 'app_%' OR target_entity_key = 'ui_actions' THEN
        RETURN;
    END IF;

    -- Add missing columns from metadata.
    FOR column_record IN
        SELECT column_name, data_type
        FROM app_entity_columns
        WHERE entity_key = target_entity_key
        ORDER BY column_name
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = target_table_name
              AND column_name = column_record.column_name
        ) THEN
            EXECUTE format(
                'ALTER TABLE %I ADD COLUMN %I %s',
                target_table_name,
                column_record.column_name,
                column_record.data_type
            );
        END IF;
    END LOOP;

    -- Drop columns removed from metadata.
    FOR existing_column IN
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = target_table_name
          AND NOT EXISTS (
              SELECT 1
              FROM app_entity_columns c
              WHERE c.entity_key = target_entity_key
                AND c.column_name = information_schema.columns.column_name
          )
        ORDER BY column_name
    LOOP
        EXECUTE format('ALTER TABLE %I DROP COLUMN IF EXISTS %I CASCADE', target_table_name, existing_column.column_name);
    END LOOP;

    -- Reconcile primary key with metadata.
    FOR pk_constraint_record IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace ns ON ns.oid = rel.relnamespace
        WHERE ns.nspname = 'public'
          AND rel.relname = target_table_name
          AND con.contype = 'p'
    LOOP
        EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', target_table_name, pk_constraint_record.conname);
    END LOOP;

        SELECT string_agg(format('%I', pk.column_name), ', ' ORDER BY pk.position)
      INTO pk_columns
    FROM app_entity_primary_keys pk
    WHERE pk.entity_key = target_entity_key;

    IF pk_columns IS NOT NULL THEN
        pk_constraint_name := metadata_managed_pk_constraint_name(target_table_name);
        EXECUTE format(
            'ALTER TABLE %I ADD CONSTRAINT %I PRIMARY KEY (%s)',
            target_table_name,
            pk_constraint_name,
            pk_columns
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION sync_entity_table_from_metadata(target_entity_key TEXT, target_table_name_hint TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
    managed_table_name TEXT;
BEGIN
    IF target_entity_key IS NULL THEN
        RETURN;
    END IF;

    IF target_entity_key LIKE 'app_%' OR target_entity_key = 'ui_actions' THEN
        RETURN;
    END IF;

    SELECT table_name INTO managed_table_name
    FROM app_entities
    WHERE entity_key = target_entity_key;

    IF managed_table_name IS NULL THEN
        IF target_table_name_hint IS NOT NULL THEN
            EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', target_table_name_hint);
        END IF;
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = managed_table_name
    ) THEN
        EXECUTE format('CREATE TABLE %I ()', managed_table_name);
    END IF;

    PERFORM sync_entity_columns_and_pk(target_entity_key, managed_table_name);

    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON TABLE %I TO %I', managed_table_name, session_user);
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aida26_user') THEN
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON TABLE %I TO %I', managed_table_name, 'aida26_user');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION trg_sync_entity_tables_from_entities()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM sync_entity_table_from_metadata(OLD.entity_key, OLD.table_name);
        RETURN OLD;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.table_name <> NEW.table_name THEN
        IF EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = OLD.table_name
        ) AND NOT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = NEW.table_name
        ) THEN
            EXECUTE format('ALTER TABLE %I RENAME TO %I', OLD.table_name, NEW.table_name);
        END IF;
    END IF;

    PERFORM sync_entity_table_from_metadata(NEW.entity_key, NEW.table_name);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION trg_sync_entity_tables_from_columns_or_pk()
RETURNS TRIGGER AS $$
DECLARE
    target_entity_key TEXT;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        PERFORM sync_entity_table_from_metadata(OLD.entity_key);
    END IF;

    target_entity_key := COALESCE(NEW.entity_key, OLD.entity_key);
    PERFORM sync_entity_table_from_metadata(target_entity_key);
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_sync_entity_tables_on_entities ON app_entities;
DROP TRIGGER IF EXISTS trg_sync_entity_tables_on_columns ON app_entity_columns;
DROP TRIGGER IF EXISTS trg_sync_entity_tables_on_primary_keys ON app_entity_primary_keys;

CREATE TRIGGER trg_sync_entity_tables_on_entities
AFTER INSERT OR DELETE OR UPDATE OF entity_key, table_name ON app_entities
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_tables_from_entities();

CREATE TRIGGER trg_sync_entity_tables_on_columns
AFTER INSERT OR DELETE OR UPDATE OF entity_key, column_name, data_type ON app_entity_columns
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_tables_from_columns_or_pk();

CREATE TRIGGER trg_sync_entity_tables_on_primary_keys
AFTER INSERT OR UPDATE OR DELETE ON app_entity_primary_keys
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_tables_from_columns_or_pk();

CREATE OR REPLACE FUNCTION sync_entity_index(target_entity_key TEXT, target_index_name TEXT)
RETURNS VOID AS $$
DECLARE
    table_name_value TEXT;
    is_unique_value BOOLEAN;
    column_list TEXT;
    physical_index_name TEXT;
BEGIN
    IF target_entity_key IS NULL OR target_index_name IS NULL THEN
        RETURN;
    END IF;

    physical_index_name := metadata_managed_index_name(target_entity_key, target_index_name);

    SELECT e.table_name, idx.is_unique
      INTO table_name_value, is_unique_value
    FROM app_entity_indexes idx
    JOIN app_entities e ON e.entity_key = idx.entity_key
    WHERE idx.entity_key = target_entity_key
      AND idx.index_name = target_index_name;

    IF table_name_value IS NULL THEN
                EXECUTE format('DROP INDEX IF EXISTS %I', physical_index_name);
        EXECUTE format('DROP INDEX IF EXISTS %I', target_index_name);
        RETURN;
    END IF;

        SELECT string_agg(format('%I', column_name), ', ' ORDER BY position)
      INTO column_list
    FROM app_entity_index_columns
    WHERE entity_key = target_entity_key
      AND index_name = target_index_name;

        EXECUTE format('DROP INDEX IF EXISTS %I', physical_index_name);
    EXECUTE format('DROP INDEX IF EXISTS %I', target_index_name);

    IF column_list IS NULL THEN
        RETURN;
    END IF;

    EXECUTE format(
        'CREATE %sINDEX %I ON %I (%s)',
        CASE WHEN is_unique_value THEN 'UNIQUE ' ELSE '' END,
        physical_index_name,
        table_name_value,
        column_list
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION trg_sync_entity_indexes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        PERFORM sync_entity_index(OLD.entity_key, OLD.index_name);
    END IF;

    PERFORM sync_entity_index(COALESCE(NEW.entity_key, OLD.entity_key), COALESCE(NEW.index_name, OLD.index_name));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_sync_entity_indexes_on_indexes ON app_entity_indexes;
DROP TRIGGER IF EXISTS trg_sync_entity_indexes_on_columns ON app_entity_index_columns;

CREATE TRIGGER trg_sync_entity_indexes_on_indexes
AFTER INSERT OR DELETE OR UPDATE OF entity_key, index_name, is_unique ON app_entity_indexes
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_indexes();

CREATE TRIGGER trg_sync_entity_indexes_on_columns
AFTER INSERT OR DELETE OR UPDATE OF entity_key, index_name, position, column_name ON app_entity_index_columns
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_indexes();

CREATE OR REPLACE FUNCTION sync_entity_foreign_key(target_entity_key TEXT, target_foreign_key_key TEXT)
RETURNS VOID AS $$
DECLARE
    source_table_name TEXT;
    referenced_table_name TEXT;
    on_update_action_value TEXT;
    on_delete_action_value TEXT;
    source_columns TEXT;
    referenced_columns TEXT;
BEGIN
    IF target_entity_key IS NULL OR target_foreign_key_key IS NULL THEN
        RETURN;
    END IF;

    SELECT source_entity.table_name,
           referenced_entity.table_name,
           group_row.on_update_action,
           group_row.on_delete_action
      INTO source_table_name,
           referenced_table_name,
           on_update_action_value,
           on_delete_action_value
    FROM app_entity_foreign_key_groups group_row
    JOIN app_entities source_entity ON source_entity.entity_key = group_row.entity_key
    JOIN app_entities referenced_entity ON referenced_entity.entity_key = group_row.referenced_entity_key
    WHERE group_row.entity_key = target_entity_key
      AND group_row.foreign_key_key = target_foreign_key_key;

    IF source_table_name IS NULL THEN
        SELECT table_name INTO source_table_name
        FROM app_entities
        WHERE entity_key = target_entity_key;

        IF source_table_name IS NOT NULL THEN
            EXECUTE format('ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I', source_table_name, target_foreign_key_key);
        END IF;

        RETURN;
    END IF;

    SELECT string_agg(format('%I', fk.column_name), ', ' ORDER BY fk.position),
           string_agg(format('%I', fk.referenced_column_name), ', ' ORDER BY fk.position)
      INTO source_columns, referenced_columns
    FROM app_entity_foreign_keys fk
    WHERE fk.entity_key = target_entity_key
      AND fk.foreign_key_key = target_foreign_key_key;

    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I', source_table_name, target_foreign_key_key);

    IF source_columns IS NULL OR referenced_columns IS NULL THEN
        RETURN;
    END IF;

    EXECUTE format(
        'ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%s) REFERENCES %I (%s) ON UPDATE %s ON DELETE %s',
        source_table_name,
        target_foreign_key_key,
        source_columns,
        referenced_table_name,
        referenced_columns,
        on_update_action_value,
        on_delete_action_value
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION trg_sync_entity_foreign_keys()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        PERFORM sync_entity_foreign_key(OLD.entity_key, OLD.foreign_key_key);
    END IF;

    PERFORM sync_entity_foreign_key(COALESCE(NEW.entity_key, OLD.entity_key), COALESCE(NEW.foreign_key_key, OLD.foreign_key_key));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_sync_entity_foreign_keys_on_groups ON app_entity_foreign_key_groups;
DROP TRIGGER IF EXISTS trg_sync_entity_foreign_keys_on_columns ON app_entity_foreign_keys;

CREATE TRIGGER trg_sync_entity_foreign_keys_on_groups
AFTER INSERT OR DELETE OR UPDATE OF entity_key, foreign_key_key, referenced_entity_key, on_update_action, on_delete_action ON app_entity_foreign_key_groups
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_foreign_keys();

CREATE TRIGGER trg_sync_entity_foreign_keys_on_columns
AFTER INSERT OR DELETE OR UPDATE OF entity_key, foreign_key_key, position, column_name, referenced_entity_key, referenced_column_name ON app_entity_foreign_keys
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_foreign_keys();

CREATE OR REPLACE FUNCTION trg_refresh_fk_dependency_metadata()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.entity_key IS DISTINCT FROM NEW.entity_key THEN
        PERFORM refresh_foreign_key_dependency_metadata(OLD.entity_key);
    END IF;

    PERFORM refresh_foreign_key_dependency_metadata(COALESCE(NEW.entity_key, OLD.entity_key));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_refresh_fk_dependency_metadata_on_groups ON app_entity_foreign_key_groups;
DROP TRIGGER IF EXISTS trg_refresh_fk_dependency_metadata_on_columns ON app_entity_foreign_keys;

CREATE TRIGGER trg_refresh_fk_dependency_metadata_on_groups
AFTER INSERT OR DELETE OR UPDATE OF entity_key, foreign_key_key, referenced_entity_key ON app_entity_foreign_key_groups
FOR EACH ROW
EXECUTE FUNCTION trg_refresh_fk_dependency_metadata();

CREATE TRIGGER trg_refresh_fk_dependency_metadata_on_columns
AFTER INSERT OR DELETE OR UPDATE OF entity_key, foreign_key_key, position, column_name ON app_entity_foreign_keys
FOR EACH ROW
EXECUTE FUNCTION trg_refresh_fk_dependency_metadata();

CREATE OR REPLACE FUNCTION is_protected_metadata_entity_key(target_entity_key TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN target_entity_key LIKE 'app_%' OR target_entity_key = 'ui_actions';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION guard_metadata_writes_for_app_user()
RETURNS TRIGGER AS $$
DECLARE
    target_entity_key TEXT;
BEGIN
    IF pg_has_role(current_user, (SELECT relowner FROM pg_class WHERE oid = 'app_entities'::regclass), 'USAGE') THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF TG_TABLE_NAME = 'app_entities' THEN
        target_entity_key := COALESCE(NEW.entity_key, OLD.entity_key);
        IF is_protected_metadata_entity_key(target_entity_key) THEN
            RAISE EXCEPTION 'app_user cannot modify protected metadata entity %', target_entity_key;
        END IF;
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF TG_TABLE_NAME = 'app_data_types' THEN
        RAISE EXCEPTION 'app_user cannot modify protected table app_data_types';
    END IF;

    IF TG_TABLE_NAME = 'app_data_type_ui_profiles' THEN
        RAISE EXCEPTION 'app_user cannot modify protected table app_data_type_ui_profiles';
    END IF;

    IF TG_TABLE_NAME = 'app_entity_columns'
        OR TG_TABLE_NAME = 'app_entity_column_nullability'
        OR TG_TABLE_NAME = 'app_entity_column_uniqueness'
        OR TG_TABLE_NAME = 'app_entity_primary_keys'
        OR TG_TABLE_NAME = 'app_entity_foreign_key_groups'
        OR TG_TABLE_NAME = 'app_entity_foreign_keys'
        OR TG_TABLE_NAME = 'app_entity_foreign_key_dependencies'
        OR TG_TABLE_NAME = 'app_entity_foreign_key_dependency_mappings'
        OR TG_TABLE_NAME = 'app_entity_indexes'
        OR TG_TABLE_NAME = 'app_entity_index_columns'
        OR TG_TABLE_NAME = 'app_entity_hidden_columns' THEN
        target_entity_key := COALESCE(NEW.entity_key, OLD.entity_key);
        IF is_protected_metadata_entity_key(target_entity_key) THEN
            RAISE EXCEPTION 'app_user cannot modify protected metadata for entity % in table %', target_entity_key, TG_TABLE_NAME;
        END IF;
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF TG_TABLE_NAME = 'app_shown_referenced_entity_columns' THEN
        IF is_protected_metadata_entity_key(COALESCE(NEW.entity_key, OLD.entity_key))
            OR is_protected_metadata_entity_key(COALESCE(NEW.referenced_entity_key, OLD.referenced_entity_key)) THEN
            RAISE EXCEPTION 'app_user cannot modify shown referenced columns for protected metadata entities';
        END IF;
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF TG_TABLE_NAME = 'app_submenus' THEN
        IF COALESCE(NEW.submenu_key, OLD.submenu_key) IN ('metadata', 'tables') THEN
            RAISE EXCEPTION 'app_user cannot modify protected submenu %', COALESCE(NEW.submenu_key, OLD.submenu_key);
        END IF;
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF TG_TABLE_NAME = 'app_submenu_entities' THEN
        IF is_protected_metadata_entity_key(COALESCE(NEW.entity_key, OLD.entity_key)) THEN
            RAISE EXCEPTION 'app_user cannot modify submenu bindings for protected metadata entity %', COALESCE(NEW.entity_key, OLD.entity_key);
        END IF;
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF TG_TABLE_NAME = 'app_referential_actions' THEN
        RAISE EXCEPTION 'app_user cannot modify protected table app_referential_actions';
    END IF;

    IF TG_TABLE_NAME = 'ui_actions' THEN
        IF COALESCE(NEW.action_key, OLD.action_key) IN ('add', 'edit', 'update', 'delete', 'cancel', 'openData', 'actions') THEN
            RAISE EXCEPTION 'app_user cannot modify protected UI action %', COALESCE(NEW.action_key, OLD.action_key);
        END IF;
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF TG_TABLE_NAME = 'app_option_set_definitions' THEN
        RAISE EXCEPTION 'app_user cannot modify protected table app_option_set_definitions';
    END IF;

    IF TG_TABLE_NAME = 'app_ui_messages' THEN
        RAISE EXCEPTION 'app_user cannot modify protected table app_ui_messages';
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_guard_app_entities ON app_entities;
DROP TRIGGER IF EXISTS trg_guard_app_data_types ON app_data_types;
DROP TRIGGER IF EXISTS trg_guard_app_data_type_ui_profiles ON app_data_type_ui_profiles;
DROP TRIGGER IF EXISTS trg_guard_app_entity_columns ON app_entity_columns;
DROP TRIGGER IF EXISTS trg_guard_app_entity_column_nullability ON app_entity_column_nullability;
DROP TRIGGER IF EXISTS trg_guard_app_entity_column_uniqueness ON app_entity_column_uniqueness;
DROP TRIGGER IF EXISTS trg_guard_app_entity_primary_keys ON app_entity_primary_keys;
DROP TRIGGER IF EXISTS trg_guard_app_entity_foreign_key_groups ON app_entity_foreign_key_groups;
DROP TRIGGER IF EXISTS trg_guard_app_entity_foreign_keys ON app_entity_foreign_keys;
DROP TRIGGER IF EXISTS trg_guard_app_entity_foreign_key_dependencies ON app_entity_foreign_key_dependencies;
DROP TRIGGER IF EXISTS trg_guard_app_entity_foreign_key_dependency_mappings ON app_entity_foreign_key_dependency_mappings;
DROP TRIGGER IF EXISTS trg_guard_app_entity_hidden_columns ON app_entity_hidden_columns;
DROP TRIGGER IF EXISTS trg_guard_app_shown_referenced_entity_columns ON app_shown_referenced_entity_columns;
DROP TRIGGER IF EXISTS trg_guard_app_entity_indexes ON app_entity_indexes;
DROP TRIGGER IF EXISTS trg_guard_app_entity_index_columns ON app_entity_index_columns;
DROP TRIGGER IF EXISTS trg_guard_app_submenus ON app_submenus;
DROP TRIGGER IF EXISTS trg_guard_app_submenu_entities ON app_submenu_entities;
DROP TRIGGER IF EXISTS trg_guard_app_referential_actions ON app_referential_actions;
DROP TRIGGER IF EXISTS trg_guard_ui_actions ON ui_actions;
DROP TRIGGER IF EXISTS trg_guard_app_option_set_definitions ON app_option_set_definitions;
DROP TRIGGER IF EXISTS trg_guard_app_ui_messages ON app_ui_messages;

CREATE TRIGGER trg_guard_app_entities
BEFORE INSERT OR UPDATE OR DELETE ON app_entities
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_data_types
BEFORE INSERT OR UPDATE OR DELETE ON app_data_types
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_data_type_ui_profiles
BEFORE INSERT OR UPDATE OR DELETE ON app_data_type_ui_profiles
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_columns
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_columns
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_column_nullability
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_column_nullability
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_column_uniqueness
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_column_uniqueness
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_primary_keys
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_primary_keys
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_foreign_key_groups
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_foreign_key_groups
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_foreign_keys
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_foreign_keys
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_foreign_key_dependencies
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_foreign_key_dependencies
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_foreign_key_dependency_mappings
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_foreign_key_dependency_mappings
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_hidden_columns
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_hidden_columns
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_shown_referenced_entity_columns
BEFORE INSERT OR UPDATE OR DELETE ON app_shown_referenced_entity_columns
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_indexes
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_indexes
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_index_columns
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_index_columns
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_submenus
BEFORE INSERT OR UPDATE OR DELETE ON app_submenus
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_submenu_entities
BEFORE INSERT OR UPDATE OR DELETE ON app_submenu_entities
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_referential_actions
BEFORE INSERT OR UPDATE OR DELETE ON app_referential_actions
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_ui_actions
BEFORE INSERT OR UPDATE OR DELETE ON ui_actions
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_option_set_definitions
BEFORE INSERT OR UPDATE OR DELETE ON app_option_set_definitions
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_ui_messages
BEFORE INSERT OR UPDATE OR DELETE ON app_ui_messages
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

COMMIT;

DO $$
DECLARE
    index_record RECORD;
    column_list TEXT;
    physical_index_name TEXT;
BEGIN
    FOR index_record IN
        SELECT entity_key, index_name, is_unique
        FROM app_entity_indexes
        ORDER BY index_name
    LOOP
                SELECT string_agg(quote_ident(column_name), ', ' ORDER BY position)
          INTO column_list
        FROM app_entity_index_columns
        WHERE entity_key = index_record.entity_key
          AND index_name = index_record.index_name;

        IF column_list IS NOT NULL THEN
            physical_index_name := metadata_managed_index_name(index_record.entity_key, index_record.index_name);

            EXECUTE format('DROP INDEX IF EXISTS %I', index_record.index_name);
            EXECUTE format(
                'CREATE %sINDEX IF NOT EXISTS %I ON %I (%s)',
                CASE WHEN index_record.is_unique THEN 'UNIQUE ' ELSE '' END,
                physical_index_name,
                (SELECT table_name FROM app_entities WHERE entity_key = index_record.entity_key),
                column_list
            );
        END IF;
    END LOOP;
END $$;

SELECT set_config('aida26.app_user', :'app_user', false);

DO $$
DECLARE
    entity_record RECORD;
BEGIN
    FOR entity_record IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE'
    LOOP
        EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE %I FROM %I', entity_record.table_name, current_setting('aida26.app_user'));
    END LOOP;

    FOR entity_record IN
        SELECT table_name AS relation_name
        FROM information_schema.views
        WHERE table_schema = 'public'
    LOOP
        EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE %I FROM %I', entity_record.relation_name, current_setting('aida26.app_user'));
    END LOOP;

    FOR entity_record IN
        SELECT table_name
        FROM app_entities
        WHERE is_allowed = TRUE
        ORDER BY entity_key
    LOOP
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE %I TO %I', entity_record.table_name, current_setting('aida26.app_user'));
    END LOOP;

END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON app_entities TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_data_types TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_data_type_ui_profiles TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_columns TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_column_nullability TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_column_uniqueness TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_primary_keys TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_foreign_key_groups TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_foreign_keys TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_foreign_key_dependencies TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_foreign_key_dependency_mappings TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_referential_actions TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_hidden_columns TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_shown_referenced_entity_columns TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_indexes TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_index_columns TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_submenus TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_submenu_entities TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON students_statuses TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON enrollments_statuses TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON ui_actions TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_option_set_definitions TO :"app_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON app_ui_messages TO :"app_user";

GRANT USAGE ON SCHEMA public TO :"app_user";
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM :"app_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"app_user";
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"app_user";
GRANT REFERENCES ON ALL TABLES IN SCHEMA public TO :"app_user";

ALTER DEFAULT PRIVILEGES FOR ROLE :"owner_user" IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON TABLES TO :"app_user";
