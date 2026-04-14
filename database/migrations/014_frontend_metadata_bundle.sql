-- Add a single DB function that returns the frontend metadata bundle.
-- This keeps the backend as a thin consumer of DB-owned metadata.

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