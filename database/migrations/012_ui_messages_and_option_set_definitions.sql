-- Add DB-driven UI messages and option set definitions.
-- This migration is idempotent.

CREATE TABLE IF NOT EXISTS app_option_set_definitions (
    option_set_key VARCHAR(100) PRIMARY KEY,
    source_kind VARCHAR(50) NOT NULL,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL,
    CONSTRAINT app_option_set_definitions_source_kind_check
        CHECK (source_kind IN ('entities', 'tables', 'referential_actions', 'ui_actions'))
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'app_option_set_definitions_source_kind_check'
          AND conrelid = 'app_option_set_definitions'::regclass
    ) THEN
        ALTER TABLE app_option_set_definitions
            ADD CONSTRAINT app_option_set_definitions_source_kind_check
            CHECK (source_kind IN ('entities', 'tables', 'referential_actions', 'ui_actions'));
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS app_ui_messages (
    message_key VARCHAR(100) PRIMARY KEY,
    text_es VARCHAR(300) NOT NULL,
    text_en VARCHAR(300) NOT NULL
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
        EXECUTE format('ALTER TABLE app_option_set_definitions OWNER TO %I', metadata_owner);
        EXECUTE format('ALTER TABLE app_ui_messages OWNER TO %I', metadata_owner);
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
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON app_option_set_definitions TO %I', grantee_name);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON app_ui_messages TO %I', grantee_name);
    END LOOP;
END $$;

INSERT INTO app_entities (entity_key, table_name, singular_es, singular_en, plural_es, plural_en, is_allowed)
VALUES
('app_option_set_definitions', 'app_option_set_definitions', 'Definicion de option set', 'Option Set Definition', 'Definiciones de option set', 'Option Set Definitions', TRUE),
('app_ui_messages', 'app_ui_messages', 'Mensaje de UI', 'UI Message', 'Mensajes de UI', 'UI Messages', TRUE)
ON CONFLICT (entity_key) DO UPDATE SET
    table_name = EXCLUDED.table_name,
    singular_es = EXCLUDED.singular_es,
    singular_en = EXCLUDED.singular_en,
    plural_es = EXCLUDED.plural_es,
    plural_en = EXCLUDED.plural_en,
    is_allowed = EXCLUDED.is_allowed;

INSERT INTO app_entity_columns (entity_key, column_name, data_type, label_es, label_en)
VALUES
('app_option_set_definitions', 'option_set_key', 'character varying', 'Clave de option set', 'Option set key'),
('app_option_set_definitions', 'source_kind', 'character varying', 'Tipo de fuente', 'Source kind'),
('app_option_set_definitions', 'label_es', 'character varying', 'Etiqueta ES', 'Label ES'),
('app_option_set_definitions', 'label_en', 'character varying', 'Label EN', 'Label EN'),
('app_ui_messages', 'message_key', 'character varying', 'Clave de mensaje', 'Message key'),
('app_ui_messages', 'text_es', 'character varying', 'Texto ES', 'Text ES'),
('app_ui_messages', 'text_en', 'character varying', 'Texto EN', 'Text EN')
ON CONFLICT (entity_key, column_name) DO UPDATE SET
    data_type = EXCLUDED.data_type,
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

DELETE FROM app_entity_column_nullability
WHERE (entity_key = 'app_option_set_definitions' AND column_name IN ('option_set_key', 'source_kind', 'label_es', 'label_en'))
   OR (entity_key = 'app_ui_messages' AND column_name IN ('message_key', 'text_es', 'text_en'));

INSERT INTO app_entity_primary_keys (entity_key, position, column_name)
VALUES
('app_option_set_definitions', 1, 'option_set_key'),
('app_ui_messages', 1, 'message_key')
ON CONFLICT (entity_key, position) DO UPDATE SET
    column_name = EXCLUDED.column_name;

INSERT INTO app_submenu_entities (submenu_key, entity_key)
VALUES
('metadata', 'app_option_set_definitions'),
('metadata', 'app_ui_messages')
ON CONFLICT (submenu_key, entity_key) DO NOTHING;

INSERT INTO app_option_set_definitions (option_set_key, source_kind, label_es, label_en)
VALUES
('appEntities', 'entities', 'Entidades de app', 'App entities'),
('databaseTables', 'tables', 'Tablas de base de datos', 'Database tables'),
('referentialActions', 'referential_actions', 'Acciones referenciales', 'Referential actions'),
('uiActions', 'ui_actions', 'Acciones de UI', 'UI actions')
ON CONFLICT (option_set_key) DO UPDATE SET
    source_kind = EXCLUDED.source_kind,
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

INSERT INTO app_ui_messages (message_key, text_es, text_en)
VALUES
('validationErrors', 'Errores de validacion', 'Validation errors'),
('deleteConfirm', 'Esta seguro de que desea eliminar este registro?', 'Are you sure you want to delete this record?'),
('required', 'es obligatorio', 'is required'),
('invalidFormat', 'formato invalido', 'invalid format'),
('mustBeAtLeast', 'debe ser >=', 'must be >='),
('mustBeAtMost', 'debe ser <=', 'must be <=')
ON CONFLICT (message_key) DO UPDATE SET
    text_es = EXCLUDED.text_es,
    text_en = EXCLUDED.text_en;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'guard_metadata_writes_for_app_user'
    ) THEN
        DROP TRIGGER IF EXISTS trg_guard_app_option_set_definitions ON app_option_set_definitions;
        DROP TRIGGER IF EXISTS trg_guard_app_ui_messages ON app_ui_messages;

        CREATE TRIGGER trg_guard_app_option_set_definitions
        BEFORE INSERT OR UPDATE OR DELETE ON app_option_set_definitions
        FOR EACH ROW
        EXECUTE FUNCTION guard_metadata_writes_for_app_user();

        CREATE TRIGGER trg_guard_app_ui_messages
        BEFORE INSERT OR UPDATE OR DELETE ON app_ui_messages
        FOR EACH ROW
        EXECUTE FUNCTION guard_metadata_writes_for_app_user();
    END IF;
END $$;
