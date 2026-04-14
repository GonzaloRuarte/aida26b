-- Replace redundant FK dependency metadata tables with derived views.
-- This removes duplicated persisted data and keeps output shape compatible for reads.

BEGIN;

-- These entities are now derived/read-only; hide them from editable metadata menus.
DELETE FROM app_submenu_entities
WHERE entity_key IN ('app_entity_foreign_key_dependencies', 'app_entity_foreign_key_dependency_mappings');

UPDATE app_entities
SET is_allowed = FALSE
WHERE entity_key IN ('app_entity_foreign_key_dependencies', 'app_entity_foreign_key_dependency_mappings');

-- Stop background refresh, no longer needed once we derive from app_entity_foreign_keys.
DROP TRIGGER IF EXISTS trg_refresh_fk_dependency_metadata_on_groups ON app_entity_foreign_key_groups;
DROP TRIGGER IF EXISTS trg_refresh_fk_dependency_metadata_on_columns ON app_entity_foreign_keys;
DROP FUNCTION IF EXISTS trg_refresh_fk_dependency_metadata();
DROP FUNCTION IF EXISTS refresh_foreign_key_dependency_metadata(TEXT);

-- Guard triggers attached to old tables are removed before replacing with views.
DROP TRIGGER IF EXISTS trg_guard_app_entity_foreign_key_dependencies ON app_entity_foreign_key_dependencies;
DROP TRIGGER IF EXISTS trg_guard_app_entity_foreign_key_dependency_mappings ON app_entity_foreign_key_dependency_mappings;

-- Replace stored redundant data with derived read-only views.
DROP TABLE IF EXISTS app_entity_foreign_key_dependency_mappings;
DROP TABLE IF EXISTS app_entity_foreign_key_dependencies;

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
        EXECUTE format('GRANT SELECT ON app_entity_foreign_key_dependencies TO %I', grantee_name);
        EXECUTE format('GRANT SELECT ON app_entity_foreign_key_dependency_mappings TO %I', grantee_name);
    END LOOP;
END $$;

COMMIT;
