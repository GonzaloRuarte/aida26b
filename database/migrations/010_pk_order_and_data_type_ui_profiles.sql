-- Harden metadata model with:
-- 1) data-type UI profile table (DB-driven field control/parser/input type)
-- 2) ordered PK metadata via app_entity_primary_keys.position

CREATE TABLE IF NOT EXISTS app_data_type_ui_profiles (
    data_type VARCHAR(100) PRIMARY KEY REFERENCES app_data_types(data_type) ON UPDATE CASCADE ON DELETE CASCADE,
    control VARCHAR(20),
    input_type VARCHAR(50),
    parser VARCHAR(30),
    step VARCHAR(20)
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
        EXECUTE format('ALTER TABLE app_data_type_ui_profiles OWNER TO %I', metadata_owner);
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
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON app_data_type_ui_profiles TO %I', grantee_name);
    END LOOP;
END $$;

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

INSERT INTO app_entities (entity_key, table_name, singular_es, singular_en, plural_es, plural_en, is_allowed)
VALUES ('app_data_type_ui_profiles', 'app_data_type_ui_profiles', 'Perfil UI de tipo de dato', 'Data Type UI Profile', 'Perfiles UI de tipos de dato', 'Data Type UI Profiles', TRUE)
ON CONFLICT (entity_key) DO UPDATE SET
    table_name = EXCLUDED.table_name,
    singular_es = EXCLUDED.singular_es,
    singular_en = EXCLUDED.singular_en,
    plural_es = EXCLUDED.plural_es,
    plural_en = EXCLUDED.plural_en,
    is_allowed = EXCLUDED.is_allowed;

INSERT INTO app_entity_columns (entity_key, column_name, data_type, label_es, label_en)
VALUES
('app_data_type_ui_profiles', 'data_type', 'character varying', 'Tipo de dato', 'Data type'),
('app_data_type_ui_profiles', 'control', 'character varying', 'Control', 'Control'),
('app_data_type_ui_profiles', 'input_type', 'character varying', 'Tipo de input', 'Input type'),
('app_data_type_ui_profiles', 'parser', 'character varying', 'Parser', 'Parser'),
('app_data_type_ui_profiles', 'step', 'character varying', 'Paso', 'Step')
ON CONFLICT (entity_key, column_name) DO UPDATE SET
    data_type = EXCLUDED.data_type;

INSERT INTO app_entity_columns (entity_key, column_name, data_type, label_es, label_en)
VALUES ('app_entity_primary_keys', 'position', 'integer', 'Posicion', 'Position')
ON CONFLICT (entity_key, column_name) DO UPDATE SET
    data_type = EXCLUDED.data_type;

INSERT INTO app_submenu_entities (submenu_key, entity_key)
VALUES ('metadata', 'app_data_type_ui_profiles')
ON CONFLICT (submenu_key, entity_key) DO NOTHING;

ALTER TABLE app_entity_primary_keys
ADD COLUMN IF NOT EXISTS position INTEGER;

ALTER TABLE app_entity_primary_keys DISABLE TRIGGER trg_sync_entity_tables_on_primary_keys;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'app_entity_primary_keys_pkey'
          AND conrelid = 'app_entity_primary_keys'::regclass
    ) THEN
        ALTER TABLE app_entity_primary_keys DROP CONSTRAINT app_entity_primary_keys_pkey;
    END IF;
END $$;

WITH ordered_pk_columns AS (
    SELECT
        e.entity_key,
        att.attname AS column_name,
        key_col.ordinality AS position
    FROM app_entities e
    JOIN pg_class rel ON rel.relname = e.table_name
    JOIN pg_namespace ns ON ns.oid = rel.relnamespace AND ns.nspname = 'public'
    JOIN pg_constraint con ON con.conrelid = rel.oid AND con.contype = 'p'
    JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS key_col(attnum, ordinality) ON TRUE
    JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = key_col.attnum
)
UPDATE app_entity_primary_keys target
SET position = ordered_pk_columns.position
FROM ordered_pk_columns
WHERE target.entity_key = ordered_pk_columns.entity_key
  AND target.column_name = ordered_pk_columns.column_name;

WITH ranked AS (
    SELECT
        ctid,
        row_number() OVER (
            PARTITION BY entity_key
            ORDER BY position NULLS LAST, column_name
        ) AS new_position
    FROM app_entity_primary_keys
)
UPDATE app_entity_primary_keys target
SET position = ranked.new_position
FROM ranked
WHERE target.ctid = ranked.ctid
  AND target.position IS NULL;

ALTER TABLE app_entity_primary_keys
ALTER COLUMN position SET NOT NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'app_entity_primary_keys_pkey'
          AND conrelid = 'app_entity_primary_keys'::regclass
    ) THEN
        ALTER TABLE app_entity_primary_keys DROP CONSTRAINT app_entity_primary_keys_pkey;
    END IF;

    ALTER TABLE app_entity_primary_keys
        ADD CONSTRAINT app_entity_primary_keys_pkey
        PRIMARY KEY (entity_key, position);

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'app_entity_primary_keys_entity_key_column_name_key'
          AND conrelid = 'app_entity_primary_keys'::regclass
    ) THEN
        ALTER TABLE app_entity_primary_keys
            ADD CONSTRAINT app_entity_primary_keys_entity_key_column_name_key
            UNIQUE (entity_key, column_name);
    END IF;
END $$;

INSERT INTO app_entity_primary_keys (entity_key, position, column_name)
VALUES
    ('app_entity_primary_keys', 1, 'entity_key'),
    ('app_data_type_ui_profiles', 1, 'data_type'),
    ('app_entity_primary_keys', 2, 'position')
ON CONFLICT (entity_key, position) DO UPDATE SET
    column_name = EXCLUDED.column_name;

DELETE FROM app_entity_primary_keys
WHERE entity_key = 'app_entity_primary_keys'
  AND column_name = 'column_name';

ALTER TABLE app_entity_primary_keys ENABLE TRIGGER trg_sync_entity_tables_on_primary_keys;

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

DROP TRIGGER IF EXISTS trg_guard_app_data_type_ui_profiles ON app_data_type_ui_profiles;

CREATE TRIGGER trg_guard_app_data_type_ui_profiles
BEFORE INSERT OR UPDATE OR DELETE ON app_data_type_ui_profiles
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();
