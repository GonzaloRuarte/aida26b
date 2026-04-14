-- Add DB function to resolve option-set items from metadata definitions.
-- This migration is idempotent.

CREATE OR REPLACE FUNCTION api_option_set_items(p_option_set_key TEXT)
RETURNS TABLE (
    value TEXT,
    label_es TEXT,
    label_en TEXT
) AS $$
DECLARE
    v_source_kind TEXT;
BEGIN
    SELECT source_kind
      INTO v_source_kind
    FROM app_option_set_definitions
    WHERE option_set_key = p_option_set_key;

    IF v_source_kind IS NULL THEN
        RETURN;
    END IF;

    IF v_source_kind = 'entities' THEN
        RETURN QUERY
        SELECT e.entity_key::text, e.singular_es::text, e.singular_en::text
        FROM app_entities e
        WHERE e.is_allowed = TRUE
        ORDER BY e.entity_key;
        RETURN;
    END IF;

    IF v_source_kind = 'tables' THEN
        RETURN QUERY
        SELECT t.table_name::text, t.singular_es::text, t.singular_en::text
        FROM (
            SELECT DISTINCT ON (e.table_name)
                e.table_name,
                e.singular_es,
                e.singular_en,
                e.entity_key
            FROM app_entities e
            WHERE e.is_allowed = TRUE
            ORDER BY e.table_name, e.entity_key
        ) t
        ORDER BY t.table_name;
        RETURN;
    END IF;

    IF v_source_kind = 'referential_actions' THEN
        RETURN QUERY
        SELECT a.action_key::text, a.label_es::text, a.label_en::text
        FROM app_referential_actions a
        ORDER BY a.action_key;
        RETURN;
    END IF;

    IF v_source_kind = 'ui_actions' THEN
        RETURN QUERY
        SELECT a.action_key::text, a.label_es::text, a.label_en::text
        FROM ui_actions a
        ORDER BY a.action_key;
        RETURN;
    END IF;

    RAISE EXCEPTION 'Unsupported option set source_kind: %', v_source_kind;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

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
        EXECUTE format('GRANT EXECUTE ON FUNCTION api_option_set_items(TEXT) TO %I', grantee_name);
    END LOOP;
END $$;