-- Harden metadata model:
-- 1) Add app_data_types catalog and link app_entity_columns.data_type to it.
-- 2) Enforce UNIQUE on app_entities.table_name and mirror in app_entity_column_uniqueness.
-- 3) Add position to app_entity_index_columns to preserve index column order.

CREATE TABLE IF NOT EXISTS app_data_types (
    data_type VARCHAR(100) PRIMARY KEY,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL
);

DO $$
DECLARE
    metadata_owner TEXT;
BEGIN
    SELECT pg_get_userbyid(relowner)
      INTO metadata_owner
    FROM pg_class
    WHERE oid = 'app_entities'::regclass;

    IF metadata_owner IS NOT NULL THEN
        EXECUTE format('ALTER TABLE app_data_types OWNER TO %I', metadata_owner);
    END IF;
END $$;

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
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON app_data_types TO %I', grantee_name);
    END LOOP;
END $$;

INSERT INTO app_data_types (data_type, label_es, label_en)
SELECT DISTINCT
    c.data_type,
    initcap(replace(c.data_type, '_', ' ')) AS label_es,
    initcap(replace(c.data_type, '_', ' ')) AS label_en
FROM information_schema.columns c
WHERE c.table_schema = 'public'
ON CONFLICT (data_type) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

INSERT INTO app_data_types (data_type, label_es, label_en)
SELECT DISTINCT
    c.data_type,
    initcap(replace(c.data_type, '_', ' ')) AS label_es,
    initcap(replace(c.data_type, '_', ' ')) AS label_en
FROM app_entity_columns c
ON CONFLICT (data_type) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'app_entities_table_name_key'
          AND conrelid = 'app_entities'::regclass
    ) THEN
        ALTER TABLE app_entities
            ADD CONSTRAINT app_entities_table_name_key UNIQUE (table_name);
    END IF;
END $$;

CREATE OR REPLACE FUNCTION sync_entity_index(target_entity_key TEXT, target_index_name TEXT)
RETURNS VOID AS $$
DECLARE
        table_name_value TEXT;
        is_unique_value BOOLEAN;
        column_list TEXT;
BEGIN
        IF target_entity_key IS NULL OR target_index_name IS NULL THEN
                RETURN;
        END IF;

        SELECT e.table_name, idx.is_unique
            INTO table_name_value, is_unique_value
        FROM app_entity_indexes idx
        JOIN app_entities e ON e.entity_key = idx.entity_key
        WHERE idx.entity_key = target_entity_key
            AND idx.index_name = target_index_name;

        IF table_name_value IS NULL THEN
                EXECUTE format('DROP INDEX IF EXISTS %I', target_index_name);
                RETURN;
        END IF;

        SELECT string_agg(format('%I', column_name), ', ' ORDER BY position)
            INTO column_list
        FROM app_entity_index_columns
        WHERE entity_key = target_entity_key
            AND index_name = target_index_name;

        EXECUTE format('DROP INDEX IF EXISTS %I', target_index_name);

        IF column_list IS NULL THEN
                RETURN;
        END IF;

        EXECUTE format(
                'CREATE %sINDEX %I ON %I (%s)',
                CASE WHEN is_unique_value THEN 'UNIQUE ' ELSE '' END,
                target_index_name,
                table_name_value,
                column_list
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'app_entity_columns_data_type_fkey'
          AND conrelid = 'app_entity_columns'::regclass
    ) THEN
        ALTER TABLE app_entity_columns
            ADD CONSTRAINT app_entity_columns_data_type_fkey
            FOREIGN KEY (data_type)
            REFERENCES app_data_types(data_type)
            ON UPDATE CASCADE
            ON DELETE RESTRICT;
    END IF;
END $$;

ALTER TABLE app_entity_index_columns
ADD COLUMN IF NOT EXISTS position INTEGER;

WITH ranked AS (
    SELECT
        ctid,
        row_number() OVER (
            PARTITION BY entity_key, index_name
            ORDER BY column_name
        ) AS new_position
    FROM app_entity_index_columns
)
UPDATE app_entity_index_columns target
SET position = ranked.new_position
FROM ranked
WHERE target.ctid = ranked.ctid
  AND target.position IS NULL;

ALTER TABLE app_entity_index_columns
ALTER COLUMN position SET NOT NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'app_entity_index_columns_pkey'
          AND conrelid = 'app_entity_index_columns'::regclass
    ) THEN
        ALTER TABLE app_entity_index_columns DROP CONSTRAINT app_entity_index_columns_pkey;
    END IF;

    ALTER TABLE app_entity_index_columns
        ADD CONSTRAINT app_entity_index_columns_pkey
        PRIMARY KEY (entity_key, index_name, position);

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'app_entity_index_columns_entity_key_index_name_column_name_key'
          AND conrelid = 'app_entity_index_columns'::regclass
    ) THEN
        ALTER TABLE app_entity_index_columns
            ADD CONSTRAINT app_entity_index_columns_entity_key_index_name_column_name_key
            UNIQUE (entity_key, index_name, column_name);
    END IF;
END $$;

DROP TRIGGER IF EXISTS trg_sync_entity_indexes_on_columns ON app_entity_index_columns;

CREATE TRIGGER trg_sync_entity_indexes_on_columns
AFTER INSERT OR DELETE OR UPDATE OF entity_key, index_name, position, column_name ON app_entity_index_columns
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_indexes();

DROP TRIGGER IF EXISTS trg_guard_app_data_types ON app_data_types;

CREATE TRIGGER trg_guard_app_data_types
BEFORE INSERT OR UPDATE OR DELETE ON app_data_types
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

INSERT INTO app_entities (entity_key, table_name, singular_es, singular_en, plural_es, plural_en, is_allowed)
VALUES ('app_data_types', 'app_data_types', 'Tipo de dato', 'Data Type', 'Tipos de dato', 'Data Types', TRUE)
ON CONFLICT (entity_key) DO UPDATE SET
    table_name = EXCLUDED.table_name,
    singular_es = EXCLUDED.singular_es,
    singular_en = EXCLUDED.singular_en,
    plural_es = EXCLUDED.plural_es,
    plural_en = EXCLUDED.plural_en,
    is_allowed = EXCLUDED.is_allowed;

INSERT INTO app_entity_columns (entity_key, column_name, data_type, label_es, label_en)
VALUES
        ('app_data_types', 'data_type', 'character varying', 'Tipo de dato', 'Data type'),
        ('app_data_types', 'label_es', 'character varying', 'Etiqueta es', 'Spanish label'),
        ('app_data_types', 'label_en', 'character varying', 'Etiqueta en', 'English label'),
        ('app_entity_index_columns', 'position', 'integer', 'Posicion', 'Position')
ON CONFLICT (entity_key, column_name) DO UPDATE SET
        data_type = EXCLUDED.data_type;

DELETE FROM app_entity_column_nullability
WHERE entity_key = 'app_entity_index_columns'
    AND column_name = 'position';

INSERT INTO app_entity_column_uniqueness (entity_key, column_name)
VALUES ('app_entities', 'table_name')
ON CONFLICT (entity_key, column_name) DO NOTHING;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'app_entity_primary_keys'
          AND column_name = 'position'
    ) THEN
        INSERT INTO app_entity_primary_keys (entity_key, position, column_name)
        VALUES
            ('app_data_types', 1, 'data_type'),
            ('app_entity_index_columns', 3, 'position')
        ON CONFLICT (entity_key, position) DO UPDATE SET
            column_name = EXCLUDED.column_name;
    ELSE
        INSERT INTO app_entity_primary_keys (entity_key, column_name)
        VALUES
            ('app_data_types', 'data_type'),
            ('app_entity_index_columns', 'position')
        ON CONFLICT (entity_key, column_name) DO NOTHING;
    END IF;
END $$;

DELETE FROM app_entity_primary_keys
WHERE entity_key = 'app_entity_index_columns'
  AND column_name = 'column_name';

DELETE FROM app_entity_column_nullability
WHERE entity_key = 'app_entity_index_columns'
  AND column_name = 'position';

INSERT INTO app_submenu_entities (submenu_key, entity_key)
VALUES ('metadata', 'app_data_types')
ON CONFLICT (submenu_key, entity_key) DO NOTHING;

INSERT INTO app_entity_foreign_key_groups (entity_key, foreign_key_key, referenced_entity_key, on_update_action, on_delete_action)
VALUES ('app_entity_columns', 'app_entity_columns_data_type_fkey', 'app_data_types', 'CASCADE', 'RESTRICT')
ON CONFLICT (entity_key, foreign_key_key) DO UPDATE SET
    referenced_entity_key = EXCLUDED.referenced_entity_key,
    on_update_action = EXCLUDED.on_update_action,
    on_delete_action = EXCLUDED.on_delete_action;

INSERT INTO app_entity_foreign_keys (entity_key, foreign_key_key, position, column_name, referenced_entity_key, referenced_column_name)
VALUES ('app_entity_columns', 'app_entity_columns_data_type_fkey', 1, 'data_type', 'app_data_types', 'data_type')
ON CONFLICT (entity_key, foreign_key_key, position) DO UPDATE SET
    column_name = EXCLUDED.column_name,
    referenced_entity_key = EXCLUDED.referenced_entity_key,
    referenced_column_name = EXCLUDED.referenced_column_name;

SELECT refresh_foreign_key_dependency_metadata(NULL);
