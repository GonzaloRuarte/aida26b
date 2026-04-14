-- Convert partially-derivable structural metadata tables to read-only derived views.
-- This moves the model to schema-first for structural aspects.

BEGIN;

-- Hide these structural entities from editable metadata navigation.
DELETE FROM app_submenu_entities
WHERE entity_key IN (
    'app_entity_column_nullability',
    'app_entity_column_uniqueness',
    'app_entity_primary_keys',
    'app_entity_foreign_key_groups',
    'app_entity_foreign_keys',
    'app_entity_indexes',
    'app_entity_index_columns'
);

UPDATE app_entities
SET is_allowed = FALSE
WHERE entity_key IN (
    'app_entity_column_nullability',
    'app_entity_column_uniqueness',
    'app_entity_primary_keys',
    'app_entity_foreign_key_groups',
    'app_entity_foreign_keys',
    'app_entity_indexes',
    'app_entity_index_columns'
);

-- Disable metadata-first structural sync triggers.
DROP TRIGGER IF EXISTS trg_apply_entity_column_nullability_constraints ON app_entity_column_nullability;
DROP TRIGGER IF EXISTS trg_apply_entity_column_uniqueness_constraints ON app_entity_column_uniqueness;
DROP TRIGGER IF EXISTS trg_sync_entity_tables_on_entities ON app_entities;
DROP TRIGGER IF EXISTS trg_sync_entity_tables_on_columns ON app_entity_columns;
DROP TRIGGER IF EXISTS trg_sync_entity_tables_on_primary_keys ON app_entity_primary_keys;
DROP TRIGGER IF EXISTS trg_sync_entity_foreign_keys_on_groups ON app_entity_foreign_key_groups;
DROP TRIGGER IF EXISTS trg_sync_entity_foreign_keys_on_columns ON app_entity_foreign_keys;
DROP TRIGGER IF EXISTS trg_sync_entity_indexes_on_indexes ON app_entity_indexes;
DROP TRIGGER IF EXISTS trg_sync_entity_indexes_on_columns ON app_entity_index_columns;

-- Remove dependency refresh triggers/functions (dependencies are now pure views).
DROP TRIGGER IF EXISTS trg_refresh_fk_dependency_metadata_on_groups ON app_entity_foreign_key_groups;
DROP TRIGGER IF EXISTS trg_refresh_fk_dependency_metadata_on_columns ON app_entity_foreign_keys;
DROP FUNCTION IF EXISTS trg_refresh_fk_dependency_metadata();
DROP FUNCTION IF EXISTS refresh_foreign_key_dependency_metadata(TEXT);

-- Remove guard triggers from tables that will become views.
DROP TRIGGER IF EXISTS trg_guard_app_entity_column_nullability ON app_entity_column_nullability;
DROP TRIGGER IF EXISTS trg_guard_app_entity_column_uniqueness ON app_entity_column_uniqueness;
DROP TRIGGER IF EXISTS trg_guard_app_entity_primary_keys ON app_entity_primary_keys;
DROP TRIGGER IF EXISTS trg_guard_app_entity_foreign_key_groups ON app_entity_foreign_key_groups;
DROP TRIGGER IF EXISTS trg_guard_app_entity_foreign_keys ON app_entity_foreign_keys;
DROP TRIGGER IF EXISTS trg_guard_app_entity_indexes ON app_entity_indexes;
DROP TRIGGER IF EXISTS trg_guard_app_entity_index_columns ON app_entity_index_columns;

-- Recreate FK dependency views after replacing FK source objects.
DROP VIEW IF EXISTS app_entity_foreign_key_dependency_mappings;
DROP VIEW IF EXISTS app_entity_foreign_key_dependencies;

-- Replace structural metadata tables with derived views.
DROP TABLE IF EXISTS app_entity_index_columns;
DROP TABLE IF EXISTS app_entity_indexes;
DROP TABLE IF EXISTS app_entity_foreign_keys;
DROP TABLE IF EXISTS app_entity_foreign_key_groups;
DROP TABLE IF EXISTS app_entity_primary_keys;
DROP TABLE IF EXISTS app_entity_column_uniqueness;
DROP TABLE IF EXISTS app_entity_column_nullability;

CREATE VIEW app_entity_column_nullability AS
SELECT
    e.entity_key,
    c.column_name
FROM app_entities e
JOIN information_schema.columns c
  ON c.table_schema = 'public'
 AND c.table_name = e.table_name
WHERE c.is_nullable = 'YES';

CREATE VIEW app_entity_column_uniqueness AS
SELECT
    e.entity_key,
    a.attname AS column_name
FROM app_entities e
JOIN pg_class rel
  ON rel.relname = e.table_name
JOIN pg_namespace ns
  ON ns.oid = rel.relnamespace
 AND ns.nspname = 'public'
JOIN pg_constraint con
  ON con.conrelid = rel.oid
 AND con.contype = 'u'
JOIN pg_attribute a
  ON a.attrelid = rel.oid
 AND a.attnum = con.conkey[1]
WHERE array_length(con.conkey, 1) = 1;

CREATE VIEW app_entity_primary_keys AS
SELECT
    e.entity_key,
    key_col.ordinality::integer AS position,
    a.attname AS column_name
FROM app_entities e
JOIN pg_class rel
  ON rel.relname = e.table_name
JOIN pg_namespace ns
  ON ns.oid = rel.relnamespace
 AND ns.nspname = 'public'
JOIN pg_constraint con
  ON con.conrelid = rel.oid
 AND con.contype = 'p'
JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS key_col(attnum, ordinality)
  ON TRUE
JOIN pg_attribute a
  ON a.attrelid = rel.oid
 AND a.attnum = key_col.attnum;

CREATE VIEW app_entity_foreign_key_groups AS
SELECT
    source_entity.entity_key,
    con.conname::varchar(100) AS foreign_key_key,
    referenced_entity.entity_key AS referenced_entity_key,
    CASE con.confupdtype
        WHEN 'a' THEN 'NO ACTION'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
        ELSE 'NO ACTION'
    END::varchar(20) AS on_update_action,
    CASE con.confdeltype
        WHEN 'a' THEN 'NO ACTION'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
        ELSE 'NO ACTION'
    END::varchar(20) AS on_delete_action
FROM pg_constraint con
JOIN pg_class source_table
  ON source_table.oid = con.conrelid
JOIN pg_namespace source_ns
  ON source_ns.oid = source_table.relnamespace
 AND source_ns.nspname = 'public'
JOIN pg_class referenced_table
  ON referenced_table.oid = con.confrelid
JOIN pg_namespace referenced_ns
  ON referenced_ns.oid = referenced_table.relnamespace
 AND referenced_ns.nspname = 'public'
JOIN app_entities source_entity
  ON source_entity.table_name = source_table.relname
JOIN app_entities referenced_entity
  ON referenced_entity.table_name = referenced_table.relname
WHERE con.contype = 'f';

CREATE VIEW app_entity_foreign_keys AS
SELECT
    source_entity.entity_key,
    con.conname::varchar(100) AS foreign_key_key,
    source_cols.ordinality::integer AS position,
    source_attr.attname AS column_name,
    referenced_entity.entity_key AS referenced_entity_key,
    referenced_attr.attname AS referenced_column_name
FROM pg_constraint con
JOIN pg_class source_table
  ON source_table.oid = con.conrelid
JOIN pg_namespace source_ns
  ON source_ns.oid = source_table.relnamespace
 AND source_ns.nspname = 'public'
JOIN pg_class referenced_table
  ON referenced_table.oid = con.confrelid
JOIN pg_namespace referenced_ns
  ON referenced_ns.oid = referenced_table.relnamespace
 AND referenced_ns.nspname = 'public'
JOIN app_entities source_entity
  ON source_entity.table_name = source_table.relname
JOIN app_entities referenced_entity
  ON referenced_entity.table_name = referenced_table.relname
JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS source_cols(attnum, ordinality)
  ON TRUE
JOIN LATERAL unnest(con.confkey) WITH ORDINALITY AS referenced_cols(attnum, ordinality)
  ON referenced_cols.ordinality = source_cols.ordinality
JOIN pg_attribute source_attr
  ON source_attr.attrelid = source_table.oid
 AND source_attr.attnum = source_cols.attnum
JOIN pg_attribute referenced_attr
  ON referenced_attr.attrelid = referenced_table.oid
 AND referenced_attr.attnum = referenced_cols.attnum
WHERE con.contype = 'f';

CREATE VIEW app_entity_indexes AS
SELECT
    e.entity_key,
    idx_name.relname::varchar(100) AS index_name,
    idx.indisunique AS is_unique
FROM pg_index idx
JOIN pg_class tbl
  ON tbl.oid = idx.indrelid
JOIN pg_namespace ns
  ON ns.oid = tbl.relnamespace
 AND ns.nspname = 'public'
JOIN pg_class idx_name
  ON idx_name.oid = idx.indexrelid
JOIN app_entities e
  ON e.table_name = tbl.relname
WHERE idx.indisprimary = FALSE
  AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint con
      WHERE con.conindid = idx.indexrelid
  );

CREATE VIEW app_entity_index_columns AS
SELECT
    e.entity_key,
    idx_name.relname::varchar(100) AS index_name,
    key_col.ordinality::integer AS position,
    a.attname AS column_name
FROM pg_index idx
JOIN pg_class tbl
  ON tbl.oid = idx.indrelid
JOIN pg_namespace ns
  ON ns.oid = tbl.relnamespace
 AND ns.nspname = 'public'
JOIN pg_class idx_name
  ON idx_name.oid = idx.indexrelid
JOIN app_entities e
  ON e.table_name = tbl.relname
JOIN LATERAL unnest(idx.indkey) WITH ORDINALITY AS key_col(attnum, ordinality)
  ON key_col.attnum > 0
JOIN pg_attribute a
  ON a.attrelid = tbl.oid
 AND a.attnum = key_col.attnum
WHERE idx.indisprimary = FALSE
  AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint con
      WHERE con.conindid = idx.indexrelid
  );

-- FK dependency views derived from app_entity_foreign_keys view.
CREATE VIEW app_entity_foreign_key_dependencies AS
WITH fk_local_sets AS (
    SELECT
        entity_key,
        foreign_key_key,
        array_agg(column_name ORDER BY position) AS local_columns
    FROM app_entity_foreign_keys
    GROUP BY entity_key, foreign_key_key
)
SELECT
    child.entity_key,
    child.foreign_key_key AS dependent_foreign_key_key,
    parent.foreign_key_key AS required_foreign_key_key
FROM fk_local_sets child
JOIN fk_local_sets parent
  ON parent.entity_key = child.entity_key
 AND parent.foreign_key_key <> child.foreign_key_key
WHERE parent.local_columns <@ child.local_columns
  AND parent.local_columns <> child.local_columns;

CREATE VIEW app_entity_foreign_key_dependency_mappings AS
SELECT
    dependency.entity_key,
    dependency.dependent_foreign_key_key,
    dependency.required_foreign_key_key,
    child_col.column_name AS shared_local_column_name
FROM app_entity_foreign_key_dependencies dependency
JOIN app_entity_foreign_keys child_col
  ON child_col.entity_key = dependency.entity_key
 AND child_col.foreign_key_key = dependency.dependent_foreign_key_key
JOIN app_entity_foreign_keys parent_col
  ON parent_col.entity_key = dependency.entity_key
 AND parent_col.foreign_key_key = dependency.required_foreign_key_key
 AND parent_col.column_name = child_col.column_name;

DO $$
DECLARE
    grantee_name TEXT;
BEGIN
    FOR grantee_name IN
        SELECT DISTINCT grantee
        FROM information_schema.role_table_grants
        WHERE table_schema = 'public'
          AND table_name = 'app_entities'
          AND privilege_type = 'SELECT'
    LOOP
        EXECUTE format('GRANT SELECT ON app_entity_column_nullability TO %I', grantee_name);
        EXECUTE format('GRANT SELECT ON app_entity_column_uniqueness TO %I', grantee_name);
        EXECUTE format('GRANT SELECT ON app_entity_primary_keys TO %I', grantee_name);
        EXECUTE format('GRANT SELECT ON app_entity_foreign_key_groups TO %I', grantee_name);
        EXECUTE format('GRANT SELECT ON app_entity_foreign_keys TO %I', grantee_name);
        EXECUTE format('GRANT SELECT ON app_entity_indexes TO %I', grantee_name);
        EXECUTE format('GRANT SELECT ON app_entity_index_columns TO %I', grantee_name);
        EXECUTE format('GRANT SELECT ON app_entity_foreign_key_dependencies TO %I', grantee_name);
        EXECUTE format('GRANT SELECT ON app_entity_foreign_key_dependency_mappings TO %I', grantee_name);
    END LOOP;
END $$;

COMMIT;
