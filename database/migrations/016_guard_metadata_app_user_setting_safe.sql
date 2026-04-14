-- Make guard_metadata_writes_for_app_user resilient when aida26.app_user is unset.

BEGIN;

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

COMMIT;
