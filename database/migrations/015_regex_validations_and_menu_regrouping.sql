-- Add regex validation metadata, regroup metadata menus, and expose/enforce rules.

BEGIN;

SELECT set_config('aida26.app_user', current_user, false);

CREATE TABLE IF NOT EXISTS app_validation_rules (
    validation_key VARCHAR(100) PRIMARY KEY,
    regex_pattern TEXT NOT NULL,
    label_es VARCHAR(200) NOT NULL,
    label_en VARCHAR(200) NOT NULL,
    error_es VARCHAR(300) NOT NULL,
    error_en VARCHAR(300) NOT NULL
);

CREATE TABLE IF NOT EXISTS app_entity_column_validations (
    entity_key VARCHAR(100) NOT NULL,
    column_name VARCHAR(100) NOT NULL,
    validation_key VARCHAR(100) NOT NULL,
    PRIMARY KEY (entity_key, column_name, validation_key),
    FOREIGN KEY (entity_key, column_name) REFERENCES app_entity_columns(entity_key, column_name) ON DELETE CASCADE,
    FOREIGN KEY (validation_key) REFERENCES app_validation_rules(validation_key) ON DELETE CASCADE
);

INSERT INTO app_entities (entity_key, table_name, is_allowed) VALUES
('app_validation_rules', 'app_validation_rules', TRUE),
('app_entity_column_validations', 'app_entity_column_validations', TRUE)
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
  AND c.table_name IN ('app_validation_rules', 'app_entity_column_validations')
ON CONFLICT (data_type) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

INSERT INTO app_entity_columns (entity_key, column_name, data_type)
SELECT
    e.entity_key,
    c.column_name,
    c.data_type
FROM app_entities e
JOIN information_schema.columns c
    ON c.table_schema = 'public'
   AND c.table_name = e.table_name
WHERE e.entity_key IN ('app_validation_rules', 'app_entity_column_validations')
ON CONFLICT (entity_key, column_name) DO UPDATE SET
    data_type = EXCLUDED.data_type;

INSERT INTO app_entity_primary_keys (entity_key, position, column_name) VALUES
('app_validation_rules', 1, 'validation_key'),
('app_entity_column_validations', 1, 'entity_key'),
('app_entity_column_validations', 2, 'column_name'),
('app_entity_column_validations', 3, 'validation_key')
ON CONFLICT (entity_key, position) DO UPDATE SET
    column_name = EXCLUDED.column_name;

INSERT INTO app_submenus (submenu_key, label_es, label_en) VALUES
('metadataCore', 'Metadatos base', 'Core metadata'),
('metadataRelations', 'Metadatos de relaciones', 'Relationship metadata'),
('metadataUI', 'Metadatos de interfaz', 'UI metadata'),
('metadataValidation', 'Metadatos de validacion', 'Validation metadata'),
('tables', 'Tablas', 'Tables')
ON CONFLICT (submenu_key) DO UPDATE SET
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en;

DELETE FROM app_submenu_entities WHERE submenu_key = 'metadata';
DELETE FROM app_submenus WHERE submenu_key = 'metadata';

INSERT INTO app_submenu_entities (submenu_key, entity_key) VALUES
('metadataCore', 'app_entities'),
('metadataCore', 'app_data_types'),
('metadataCore', 'app_entity_columns'),
('metadataCore', 'app_entity_column_nullability'),
('metadataCore', 'app_entity_column_uniqueness'),
('metadataCore', 'app_entity_primary_keys'),
('metadataCore', 'app_entity_hidden_columns'),
('metadataCore', 'app_entity_indexes'),
('metadataCore', 'app_entity_index_columns'),
('metadataRelations', 'app_entity_foreign_key_groups'),
('metadataRelations', 'app_entity_foreign_keys'),
('metadataRelations', 'app_entity_foreign_key_dependencies'),
('metadataRelations', 'app_entity_foreign_key_dependency_mappings'),
('metadataRelations', 'app_referential_actions'),
('metadataRelations', 'app_shown_referenced_entity_columns'),
('metadataUI', 'app_data_type_ui_profiles'),
('metadataUI', 'app_submenus'),
('metadataUI', 'app_submenu_entities'),
('metadataUI', 'ui_actions'),
('metadataUI', 'app_option_set_definitions'),
('metadataUI', 'app_ui_messages'),
('metadataValidation', 'app_validation_rules'),
('metadataValidation', 'app_entity_column_validations')
ON CONFLICT (submenu_key, entity_key) DO NOTHING;

INSERT INTO app_validation_rules (validation_key, regex_pattern, label_es, label_en, error_es, error_en) VALUES
('email_basic', '^[^\s@]+@[^\s@]+\.[^\s@]+$', 'Email basico', 'Basic email', 'Debe ser un email valido', 'Must be a valid email'),
('dni_digits_7_10', '^\d{7,10}$', 'DNI 7-10 digitos', 'ID 7-10 digits', 'Debe contener entre 7 y 10 digitos', 'Must contain between 7 and 10 digits'),
('alnum_1_100', '^[A-Za-z0-9_\-\s]{1,100}$', 'Alfanumerico 1-100', 'Alphanumeric 1-100', 'Solo letras, numeros, espacios, guion y guion bajo (1-100)', 'Only letters, numbers, spaces, dash and underscore (1-100)')
ON CONFLICT (validation_key) DO UPDATE SET
    regex_pattern = EXCLUDED.regex_pattern,
    label_es = EXCLUDED.label_es,
    label_en = EXCLUDED.label_en,
    error_es = EXCLUDED.error_es,
    error_en = EXCLUDED.error_en;

INSERT INTO app_entity_column_validations (entity_key, column_name, validation_key) VALUES
('students', 'email', 'email_basic'),
('students', 'dni', 'dni_digits_7_10'),
('students', 'first_name', 'alnum_1_100'),
('students', 'last_name', 'alnum_1_100')
ON CONFLICT (entity_key, column_name, validation_key) DO NOTHING;

WITH entity_label_seed(entity_key, singular_es, singular_en, plural_es, plural_en) AS (
    VALUES
    ('app_validation_rules', 'Regla de validacion', 'Validation Rule', 'Reglas de validacion', 'Validation Rules'),
    ('app_entity_column_validations', 'Validacion de columna', 'Column Validation', 'Validaciones de columna', 'Column Validations')
)
UPDATE app_entities e
SET
    singular_es = seed.singular_es,
    singular_en = seed.singular_en,
    plural_es = seed.plural_es,
    plural_en = seed.plural_en
FROM entity_label_seed seed
WHERE e.entity_key = seed.entity_key;

CREATE OR REPLACE FUNCTION api_frontend_metadata_bundle()
RETURNS JSONB AS $$
DECLARE
    payload JSONB;
BEGIN
    SELECT jsonb_build_object(
        'app_entities', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key)
            FROM (
                SELECT entity_key, table_name, singular_es, singular_en, plural_es, plural_en
                FROM app_entities
                WHERE is_allowed = TRUE
                ORDER BY entity_key
            ) t
        ), '[]'::jsonb),
        'app_entity_hidden_columns', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key, t.column_name)
            FROM (
                SELECT entity_key, column_name
                FROM app_entity_hidden_columns
                ORDER BY entity_key, column_name
            ) t
        ), '[]'::jsonb),
        'app_shown_referenced_entity_columns', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key, t.referenced_entity_key, t.displayed_entity_column)
            FROM (
                SELECT entity_key, referenced_entity_key, displayed_entity_column
                FROM app_shown_referenced_entity_columns
                ORDER BY entity_key, referenced_entity_key, displayed_entity_column
            ) t
        ), '[]'::jsonb),
        'app_entity_columns', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key, t.column_name)
            FROM (
                SELECT entity_key, column_name, label_es, label_en
                FROM app_entity_columns
                ORDER BY entity_key, column_name
            ) t
        ), '[]'::jsonb),
        'app_entity_primary_keys', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key, t.position)
            FROM (
                SELECT entity_key, position, column_name
                FROM app_entity_primary_keys
                ORDER BY entity_key, position
            ) t
        ), '[]'::jsonb),
        'app_data_type_ui_profiles', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.data_type)
            FROM (
                SELECT data_type, control, input_type, parser, step
                FROM app_data_type_ui_profiles
                ORDER BY data_type
            ) t
        ), '[]'::jsonb),
        'app_entity_foreign_key_groups', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key, t.foreign_key_key)
            FROM (
                SELECT entity_key, foreign_key_key, referenced_entity_key, on_update_action, on_delete_action
                FROM app_entity_foreign_key_groups
                ORDER BY entity_key, foreign_key_key
            ) t
        ), '[]'::jsonb),
        'app_entity_foreign_keys', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key, t.foreign_key_key, t.position)
            FROM (
                SELECT entity_key, foreign_key_key, position, column_name, referenced_entity_key, referenced_column_name
                FROM app_entity_foreign_keys
                ORDER BY entity_key, foreign_key_key, position
            ) t
        ), '[]'::jsonb),
        'app_entity_foreign_key_dependencies', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key, t.dependent_foreign_key_key, t.required_foreign_key_key)
            FROM (
                SELECT entity_key, dependent_foreign_key_key, required_foreign_key_key
                FROM app_entity_foreign_key_dependencies
                ORDER BY entity_key, dependent_foreign_key_key, required_foreign_key_key
            ) t
        ), '[]'::jsonb),
        'app_entity_foreign_key_dependency_mappings', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key, t.dependent_foreign_key_key, t.required_foreign_key_key, t.shared_local_column_name)
            FROM (
                SELECT entity_key, dependent_foreign_key_key, required_foreign_key_key, shared_local_column_name
                FROM app_entity_foreign_key_dependency_mappings
                ORDER BY entity_key, dependent_foreign_key_key, required_foreign_key_key, shared_local_column_name
            ) t
        ), '[]'::jsonb),
        'app_option_set_definitions', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.option_set_key)
            FROM (
                SELECT option_set_key, source_kind, label_es, label_en
                FROM app_option_set_definitions
                ORDER BY option_set_key
            ) t
        ), '[]'::jsonb),
        'app_ui_messages', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.message_key)
            FROM (
                SELECT message_key, text_es, text_en
                FROM app_ui_messages
                ORDER BY message_key
            ) t
        ), '[]'::jsonb),
        'app_validation_rules', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.validation_key)
            FROM (
                SELECT validation_key, regex_pattern, label_es, label_en, error_es, error_en
                FROM app_validation_rules
                ORDER BY validation_key
            ) t
        ), '[]'::jsonb),
        'app_entity_column_validations', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.entity_key, t.column_name, t.validation_key)
            FROM (
                SELECT entity_key, column_name, validation_key
                FROM app_entity_column_validations
                ORDER BY entity_key, column_name, validation_key
            ) t
        ), '[]'::jsonb),
        'app_submenus', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.submenu_key)
            FROM (
                SELECT submenu_key, label_es, label_en
                FROM app_submenus
                ORDER BY submenu_key
            ) t
        ), '[]'::jsonb),
        'app_submenu_entities', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.submenu_key, t.entity_key)
            FROM (
                SELECT submenu_key, entity_key
                FROM app_submenu_entities
                ORDER BY submenu_key, entity_key
            ) t
        ), '[]'::jsonb),
        'ui_actions', COALESCE((
            SELECT jsonb_agg(to_jsonb(t) ORDER BY t.action_key)
            FROM (
                SELECT action_key, label_es, label_en
                FROM ui_actions
                ORDER BY action_key
            ) t
        ), '[]'::jsonb)
    ) INTO payload;

    RETURN payload;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION validate_entity_regex_rules(v_entity_key TEXT, v_payload JSONB)
RETURNS VOID AS $$
DECLARE
    rule_record RECORD;
    column_value TEXT;
BEGIN
    FOR rule_record IN
        SELECT
            ecv.column_name,
            vr.regex_pattern,
            vr.error_es
        FROM app_entity_column_validations ecv
        JOIN app_validation_rules vr
            ON vr.validation_key = ecv.validation_key
        WHERE ecv.entity_key = v_entity_key
    LOOP
        column_value := v_payload ->> rule_record.column_name;

        IF column_value IS NULL OR btrim(column_value) = '' THEN
            CONTINUE;
        END IF;

        IF column_value !~ rule_record.regex_pattern THEN
            RAISE EXCEPTION '% (columna %)', rule_record.error_es, rule_record.column_name;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION trg_validate_students_regex_rules()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM validate_entity_regex_rules('students', to_jsonb(NEW));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION guard_metadata_writes_for_app_user()
RETURNS TRIGGER AS $$
DECLARE
    app_user_name TEXT;
    target_entity_key TEXT;
BEGIN
    app_user_name := COALESCE(current_setting('aida26.app_user', true), current_user);
    IF current_user <> app_user_name THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

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
        IF COALESCE(NEW.submenu_key, OLD.submenu_key) IN ('metadataCore', 'metadataRelations', 'metadataUI', 'metadataValidation', 'tables') THEN
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

    IF TG_TABLE_NAME = 'app_validation_rules' THEN
        RAISE EXCEPTION 'app_user cannot modify protected table app_validation_rules';
    END IF;

    IF TG_TABLE_NAME = 'app_entity_column_validations' THEN
        target_entity_key := COALESCE(NEW.entity_key, OLD.entity_key);
        IF is_protected_metadata_entity_key(target_entity_key) THEN
            RAISE EXCEPTION 'app_user cannot modify protected metadata for entity % in table %', target_entity_key, TG_TABLE_NAME;
        END IF;
        RETURN COALESCE(NEW, OLD);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_guard_app_validation_rules ON app_validation_rules;
DROP TRIGGER IF EXISTS trg_guard_app_entity_column_validations ON app_entity_column_validations;
DROP TRIGGER IF EXISTS trg_students_regex_validation ON students;

CREATE TRIGGER trg_guard_app_validation_rules
BEFORE INSERT OR UPDATE OR DELETE ON app_validation_rules
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_guard_app_entity_column_validations
BEFORE INSERT OR UPDATE OR DELETE ON app_entity_column_validations
FOR EACH ROW
EXECUTE FUNCTION guard_metadata_writes_for_app_user();

CREATE TRIGGER trg_students_regex_validation
BEFORE INSERT OR UPDATE ON students
FOR EACH ROW
EXECUTE FUNCTION trg_validate_students_regex_rules();

DO $$
DECLARE
    role_record RECORD;
BEGIN
    FOR role_record IN
        SELECT DISTINCT grantee
        FROM information_schema.role_table_grants
        WHERE table_schema = 'public'
          AND table_name = 'app_entities'
          AND privilege_type = 'SELECT'
    LOOP
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON app_validation_rules TO %I', role_record.grantee);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON app_entity_column_validations TO %I', role_record.grantee);
    END LOOP;
END $$;

COMMIT;
