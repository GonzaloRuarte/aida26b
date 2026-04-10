-- Ensure refresh_foreign_key_dependency_metadata exists and recompute dependency tables.
-- This migration is idempotent and can be executed repeatedly.

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

SELECT refresh_foreign_key_dependency_metadata(NULL);
