-- Generated file. Do not edit manually.
-- Source of truth: database/migrations/*.sql
-- Regenerate with: ./database/scripts/generate-schema.ps1

--
--



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: api_frontend_metadata_bundle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."api_frontend_metadata_bundle"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


--
-- Name: api_option_set_items("text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."api_option_set_items"("p_option_set_key" "text") RETURNS TABLE("value" "text", "label_es" "text", "label_en" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


--
-- Name: apply_entity_column_nullability_constraints(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."apply_entity_column_nullability_constraints"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    target_entity_key TEXT;
    target_column_name TEXT;
    table_name_value TEXT;
BEGIN
    target_entity_key := COALESCE(NEW.entity_key, OLD.entity_key);
    target_column_name := COALESCE(NEW.column_name, OLD.column_name);

    SELECT table_name INTO table_name_value
    FROM app_entities
    WHERE entity_key = target_entity_key;

    IF table_name_value IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF TG_OP = 'DELETE' THEN
        EXECUTE format('ALTER TABLE %I ALTER COLUMN %I SET NOT NULL', table_name_value, target_column_name);
    ELSE
        EXECUTE format('ALTER TABLE %I ALTER COLUMN %I DROP NOT NULL', table_name_value, target_column_name);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: apply_entity_column_uniqueness_constraints(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."apply_entity_column_uniqueness_constraints"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    target_entity_key TEXT;
    target_column_name TEXT;
    table_name_value TEXT;
    managed_constraint_name TEXT;
BEGIN
    target_entity_key := COALESCE(NEW.entity_key, OLD.entity_key);
    target_column_name := COALESCE(NEW.column_name, OLD.column_name);

    SELECT table_name INTO table_name_value
    FROM app_entities
    WHERE entity_key = target_entity_key;

    IF table_name_value IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    managed_constraint_name := format('uq_meta_%s_%s', table_name_value, target_column_name);
    IF length(managed_constraint_name) > 63 THEN
        managed_constraint_name := 'uqm_' || substr(md5(table_name_value || '_' || target_column_name), 1, 27);
    END IF;

    IF TG_OP <> 'DELETE' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_constraint con
            JOIN pg_class rel ON rel.oid = con.conrelid
            JOIN pg_namespace ns ON ns.oid = rel.relnamespace
            JOIN unnest(con.conkey) AS key_col(attnum) ON TRUE
            JOIN pg_attribute attr ON attr.attrelid = rel.oid AND attr.attnum = key_col.attnum
            WHERE ns.nspname = 'public'
              AND rel.relname = table_name_value
              AND con.contype IN ('p', 'u')
            GROUP BY con.oid
            HAVING COUNT(*) = 1 AND max(attr.attname) = target_column_name
        ) THEN
            EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I UNIQUE (%I)', table_name_value, managed_constraint_name, target_column_name);
        END IF;
    ELSE
        IF EXISTS (
            SELECT 1
            FROM pg_constraint con
            JOIN pg_class rel ON rel.oid = con.conrelid
            JOIN pg_namespace ns ON ns.oid = rel.relnamespace
            WHERE ns.nspname = 'public'
              AND rel.relname = table_name_value
              AND con.conname = managed_constraint_name
        ) THEN
            EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', table_name_value, managed_constraint_name);
        END IF;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: guard_metadata_writes_for_app_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."guard_metadata_writes_for_app_user"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


--
-- Name: is_protected_metadata_entity_key("text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."is_protected_metadata_entity_key"("target_entity_key" "text") RETURNS boolean
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
BEGIN
    RETURN target_entity_key LIKE 'app_%' OR target_entity_key = 'ui_actions';
END;
$$;


--
-- Name: metadata_managed_index_name("text", "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."metadata_managed_index_name"("target_entity_key" "text", "target_index_name" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    physical_name TEXT;
BEGIN
    physical_name := format('idx_meta_%s_%s', target_entity_key, target_index_name);
    IF length(physical_name) > 63 THEN
        physical_name := 'idxm_' || substr(md5(target_entity_key || '_' || target_index_name), 1, 58);
    END IF;
    RETURN physical_name;
END;
$$;


--
-- Name: metadata_managed_pk_constraint_name("text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."metadata_managed_pk_constraint_name"("target_table_name" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    constraint_name TEXT;
BEGIN
    constraint_name := format('pk_meta_%s', target_table_name);
    IF length(constraint_name) > 63 THEN
        constraint_name := 'pkm_' || substr(md5(target_table_name), 1, 59);
    END IF;
    RETURN constraint_name;
END;
$$;


--
-- Name: normalize_app_entity_column_labels(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."normalize_app_entity_column_labels"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.label_es := COALESCE(NULLIF(trim(NEW.label_es), ''), initcap(replace(NEW.column_name, '_', ' ')));
    NEW.label_en := COALESCE(NULLIF(trim(NEW.label_en), ''), initcap(replace(NEW.column_name, '_', ' ')));
    RETURN NEW;
END;
$$;


--
-- Name: normalize_app_entity_labels(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."normalize_app_entity_labels"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.singular_es := COALESCE(NULLIF(trim(NEW.singular_es), ''), initcap(replace(NEW.entity_key, '_', ' ')));
    NEW.singular_en := COALESCE(NULLIF(trim(NEW.singular_en), ''), initcap(replace(NEW.entity_key, '_', ' ')));
    NEW.plural_es := COALESCE(NULLIF(trim(NEW.plural_es), ''), NEW.singular_es || 's');
    NEW.plural_en := COALESCE(NULLIF(trim(NEW.plural_en), ''), NEW.singular_en || 's');
    RETURN NEW;
END;
$$;


--
-- Name: sync_entity_columns_and_pk("text", "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."sync_entity_columns_and_pk"("target_entity_key" "text", "target_table_name" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


--
-- Name: sync_entity_foreign_key("text", "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."sync_entity_foreign_key"("target_entity_key" "text", "target_foreign_key_key" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    source_table_name TEXT;
    referenced_table_name TEXT;
    on_update_action_value TEXT;
    on_delete_action_value TEXT;
    source_columns TEXT;
    referenced_columns TEXT;
BEGIN
    IF target_entity_key IS NULL OR target_foreign_key_key IS NULL THEN
        RETURN;
    END IF;

    SELECT source_entity.table_name,
           referenced_entity.table_name,
           group_row.on_update_action,
           group_row.on_delete_action
      INTO source_table_name,
           referenced_table_name,
           on_update_action_value,
           on_delete_action_value
    FROM app_entity_foreign_key_groups group_row
    JOIN app_entities source_entity ON source_entity.entity_key = group_row.entity_key
    JOIN app_entities referenced_entity ON referenced_entity.entity_key = group_row.referenced_entity_key
    WHERE group_row.entity_key = target_entity_key
      AND group_row.foreign_key_key = target_foreign_key_key;

    IF source_table_name IS NULL THEN
        SELECT table_name INTO source_table_name
        FROM app_entities
        WHERE entity_key = target_entity_key;

        IF source_table_name IS NOT NULL THEN
            EXECUTE format('ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I', source_table_name, target_foreign_key_key);
        END IF;

        RETURN;
    END IF;

    SELECT string_agg(format('%I', fk.column_name), ', ' ORDER BY fk.position),
           string_agg(format('%I', fk.referenced_column_name), ', ' ORDER BY fk.position)
      INTO source_columns, referenced_columns
    FROM app_entity_foreign_keys fk
    WHERE fk.entity_key = target_entity_key
      AND fk.foreign_key_key = target_foreign_key_key;

    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I', source_table_name, target_foreign_key_key);

    IF source_columns IS NULL OR referenced_columns IS NULL THEN
        RETURN;
    END IF;

    EXECUTE format(
        'ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%s) REFERENCES %I (%s) ON UPDATE %s ON DELETE %s',
        source_table_name,
        target_foreign_key_key,
        source_columns,
        referenced_table_name,
        referenced_columns,
        on_update_action_value,
        on_delete_action_value
    );
END;
$$;


--
-- Name: sync_entity_index("text", "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."sync_entity_index"("target_entity_key" "text", "target_index_name" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    table_name_value TEXT;
    is_unique_value BOOLEAN;
    column_list TEXT;
    physical_index_name TEXT;
BEGIN
    IF target_entity_key IS NULL OR target_index_name IS NULL THEN
        RETURN;
    END IF;

    physical_index_name := metadata_managed_index_name(target_entity_key, target_index_name);

    SELECT e.table_name, idx.is_unique
      INTO table_name_value, is_unique_value
    FROM app_entity_indexes idx
    JOIN app_entities e ON e.entity_key = idx.entity_key
    WHERE idx.entity_key = target_entity_key
      AND idx.index_name = target_index_name;

    IF table_name_value IS NULL THEN
        EXECUTE format('DROP INDEX IF EXISTS %I', physical_index_name);
        EXECUTE format('DROP INDEX IF EXISTS %I', target_index_name);
        RETURN;
    END IF;

    SELECT string_agg(format('%I', column_name), ', ' ORDER BY position)
      INTO column_list
    FROM app_entity_index_columns
    WHERE entity_key = target_entity_key
      AND index_name = target_index_name;

    EXECUTE format('DROP INDEX IF EXISTS %I', physical_index_name);
    EXECUTE format('DROP INDEX IF EXISTS %I', target_index_name);

    IF column_list IS NULL THEN
        RETURN;
    END IF;

    EXECUTE format(
        'CREATE %sINDEX %I ON %I (%s)',
        CASE WHEN is_unique_value THEN 'UNIQUE ' ELSE '' END,
        physical_index_name,
        table_name_value,
        column_list
    );
END;
$$;


--
-- Name: sync_entity_table_from_metadata("text", "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."sync_entity_table_from_metadata"("target_entity_key" "text", "target_table_name_hint" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    managed_table_name TEXT;
BEGIN
    IF target_entity_key IS NULL THEN
        RETURN;
    END IF;

    IF target_entity_key LIKE 'app_%' OR target_entity_key = 'ui_actions' THEN
        RETURN;
    END IF;

    SELECT table_name INTO managed_table_name
    FROM app_entities
    WHERE entity_key = target_entity_key;

    IF managed_table_name IS NULL THEN
        IF target_table_name_hint IS NOT NULL THEN
            EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', target_table_name_hint);
        END IF;
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = managed_table_name
    ) THEN
        EXECUTE format('CREATE TABLE %I ()', managed_table_name);
    END IF;

    PERFORM sync_entity_columns_and_pk(target_entity_key, managed_table_name);

    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON TABLE %I TO %I', managed_table_name, session_user);
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aida26_user') THEN
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON TABLE %I TO %I', managed_table_name, 'aida26_user');
    END IF;
END;
$$;


--
-- Name: trg_sync_entity_foreign_keys(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."trg_sync_entity_foreign_keys"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        PERFORM sync_entity_foreign_key(OLD.entity_key, OLD.foreign_key_key);
    END IF;

    PERFORM sync_entity_foreign_key(COALESCE(NEW.entity_key, OLD.entity_key), COALESCE(NEW.foreign_key_key, OLD.foreign_key_key));
    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: trg_sync_entity_indexes(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."trg_sync_entity_indexes"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        PERFORM sync_entity_index(OLD.entity_key, OLD.index_name);
    END IF;

    PERFORM sync_entity_index(COALESCE(NEW.entity_key, OLD.entity_key), COALESCE(NEW.index_name, OLD.index_name));
    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: trg_sync_entity_tables_from_columns_or_pk(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."trg_sync_entity_tables_from_columns_or_pk"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    target_entity_key TEXT;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        PERFORM sync_entity_table_from_metadata(OLD.entity_key);
    END IF;

    target_entity_key := COALESCE(NEW.entity_key, OLD.entity_key);
    PERFORM sync_entity_table_from_metadata(target_entity_key);
    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: trg_sync_entity_tables_from_entities(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."trg_sync_entity_tables_from_entities"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM sync_entity_table_from_metadata(OLD.entity_key, OLD.table_name);
        RETURN OLD;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.table_name <> NEW.table_name THEN
        IF EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = OLD.table_name
        ) AND NOT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = NEW.table_name
        ) THEN
            EXECUTE format('ALTER TABLE %I RENAME TO %I', OLD.table_name, NEW.table_name);
        END IF;
    END IF;

    PERFORM sync_entity_table_from_metadata(NEW.entity_key, NEW.table_name);
    RETURN NEW;
END;
$$;


--
-- Name: trg_validate_students_regex_rules(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."trg_validate_students_regex_rules"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    PERFORM validate_entity_regex_rules('students', to_jsonb(NEW));
    RETURN NEW;
END;
$$;


--
-- Name: validate_entity_regex_rules("text", "jsonb"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."validate_entity_regex_rules"("v_entity_key" "text", "v_payload" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


SET default_table_access_method = "heap";

--
-- Name: app_data_type_ui_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_data_type_ui_profiles" (
    "data_type" character varying(100) NOT NULL,
    "control" character varying(20),
    "input_type" character varying(50),
    "parser" character varying(30),
    "step" character varying(20)
);


--
-- Name: app_data_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_data_types" (
    "data_type" character varying(100) NOT NULL,
    "label_es" character varying(200) NOT NULL,
    "label_en" character varying(200) NOT NULL
);


--
-- Name: app_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_entities" (
    "entity_key" character varying(100) NOT NULL,
    "table_name" character varying(100) NOT NULL,
    "singular_es" character varying(200) NOT NULL,
    "singular_en" character varying(200) NOT NULL,
    "plural_es" character varying(200) NOT NULL,
    "plural_en" character varying(200) NOT NULL,
    "is_allowed" boolean DEFAULT true NOT NULL
);


--
-- Name: app_entity_column_nullability; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."app_entity_column_nullability" AS
 SELECT "e"."entity_key",
    "c"."column_name"
   FROM ("public"."app_entities" "e"
     JOIN "information_schema"."columns" "c" ON (((("c"."table_schema")::"name" = 'public'::"name") AND (("c"."table_name")::"name" = ("e"."table_name")::"text"))))
  WHERE (("c"."is_nullable")::"text" = 'YES'::"text");


--
-- Name: app_entity_column_uniqueness; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."app_entity_column_uniqueness" AS
 SELECT "e"."entity_key",
    "a"."attname" AS "column_name"
   FROM (((("public"."app_entities" "e"
     JOIN "pg_class" "rel" ON (("rel"."relname" = ("e"."table_name")::"text")))
     JOIN "pg_namespace" "ns" ON ((("ns"."oid" = "rel"."relnamespace") AND ("ns"."nspname" = 'public'::"name"))))
     JOIN "pg_constraint" "con" ON ((("con"."conrelid" = "rel"."oid") AND ("con"."contype" = 'u'::"char"))))
     JOIN "pg_attribute" "a" ON ((("a"."attrelid" = "rel"."oid") AND ("a"."attnum" = "con"."conkey"[1]))))
  WHERE ("array_length"("con"."conkey", 1) = 1);


--
-- Name: app_entity_column_validations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_entity_column_validations" (
    "entity_key" character varying(100) NOT NULL,
    "column_name" character varying(100) NOT NULL,
    "validation_key" character varying(100) NOT NULL
);


--
-- Name: app_entity_columns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_entity_columns" (
    "entity_key" character varying(100) NOT NULL,
    "column_name" character varying(100) NOT NULL,
    "data_type" character varying(100) NOT NULL,
    "label_es" character varying(200) NOT NULL,
    "label_en" character varying(200) NOT NULL
);


--
-- Name: app_entity_foreign_keys; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."app_entity_foreign_keys" AS
 SELECT "source_entity"."entity_key",
    ("con"."conname")::character varying(100) AS "foreign_key_key",
    ("source_cols"."ordinality")::integer AS "position",
    "source_attr"."attname" AS "column_name",
    "referenced_entity"."entity_key" AS "referenced_entity_key",
    "referenced_attr"."attname" AS "referenced_column_name"
   FROM (((((((((("pg_constraint" "con"
     JOIN "pg_class" "source_table" ON (("source_table"."oid" = "con"."conrelid")))
     JOIN "pg_namespace" "source_ns" ON ((("source_ns"."oid" = "source_table"."relnamespace") AND ("source_ns"."nspname" = 'public'::"name"))))
     JOIN "pg_class" "referenced_table" ON (("referenced_table"."oid" = "con"."confrelid")))
     JOIN "pg_namespace" "referenced_ns" ON ((("referenced_ns"."oid" = "referenced_table"."relnamespace") AND ("referenced_ns"."nspname" = 'public'::"name"))))
     JOIN "public"."app_entities" "source_entity" ON ((("source_entity"."table_name")::"text" = "source_table"."relname")))
     JOIN "public"."app_entities" "referenced_entity" ON ((("referenced_entity"."table_name")::"text" = "referenced_table"."relname")))
     JOIN LATERAL "unnest"("con"."conkey") WITH ORDINALITY "source_cols"("attnum", "ordinality") ON (true))
     JOIN LATERAL "unnest"("con"."confkey") WITH ORDINALITY "referenced_cols"("attnum", "ordinality") ON (("referenced_cols"."ordinality" = "source_cols"."ordinality")))
     JOIN "pg_attribute" "source_attr" ON ((("source_attr"."attrelid" = "source_table"."oid") AND ("source_attr"."attnum" = "source_cols"."attnum"))))
     JOIN "pg_attribute" "referenced_attr" ON ((("referenced_attr"."attrelid" = "referenced_table"."oid") AND ("referenced_attr"."attnum" = "referenced_cols"."attnum"))))
  WHERE ("con"."contype" = 'f'::"char");


--
-- Name: app_entity_foreign_key_dependencies; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."app_entity_foreign_key_dependencies" AS
 WITH "fk_local_sets" AS (
         SELECT "app_entity_foreign_keys"."entity_key",
            "app_entity_foreign_keys"."foreign_key_key",
            "array_agg"("app_entity_foreign_keys"."column_name" ORDER BY "app_entity_foreign_keys"."position") AS "local_columns"
           FROM "public"."app_entity_foreign_keys"
          GROUP BY "app_entity_foreign_keys"."entity_key", "app_entity_foreign_keys"."foreign_key_key"
        )
 SELECT "child"."entity_key",
    "child"."foreign_key_key" AS "dependent_foreign_key_key",
    "parent"."foreign_key_key" AS "required_foreign_key_key"
   FROM ("fk_local_sets" "child"
     JOIN "fk_local_sets" "parent" ON (((("parent"."entity_key")::"text" = ("child"."entity_key")::"text") AND (("parent"."foreign_key_key")::"text" <> ("child"."foreign_key_key")::"text"))))
  WHERE (("parent"."local_columns" <@ "child"."local_columns") AND ("parent"."local_columns" <> "child"."local_columns"));


--
-- Name: app_entity_foreign_key_dependency_mappings; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."app_entity_foreign_key_dependency_mappings" AS
 SELECT "dependency"."entity_key",
    "dependency"."dependent_foreign_key_key",
    "dependency"."required_foreign_key_key",
    "child_col"."column_name" AS "shared_local_column_name"
   FROM (("public"."app_entity_foreign_key_dependencies" "dependency"
     JOIN "public"."app_entity_foreign_keys" "child_col" ON (((("child_col"."entity_key")::"text" = ("dependency"."entity_key")::"text") AND (("child_col"."foreign_key_key")::"text" = ("dependency"."dependent_foreign_key_key")::"text"))))
     JOIN "public"."app_entity_foreign_keys" "parent_col" ON (((("parent_col"."entity_key")::"text" = ("dependency"."entity_key")::"text") AND (("parent_col"."foreign_key_key")::"text" = ("dependency"."required_foreign_key_key")::"text") AND ("parent_col"."column_name" = "child_col"."column_name"))));


--
-- Name: app_entity_foreign_key_groups; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."app_entity_foreign_key_groups" AS
 SELECT "source_entity"."entity_key",
    ("con"."conname")::character varying(100) AS "foreign_key_key",
    "referenced_entity"."entity_key" AS "referenced_entity_key",
    (
        CASE "con"."confupdtype"
            WHEN 'a'::"char" THEN 'NO ACTION'::"text"
            WHEN 'r'::"char" THEN 'RESTRICT'::"text"
            WHEN 'c'::"char" THEN 'CASCADE'::"text"
            WHEN 'n'::"char" THEN 'SET NULL'::"text"
            WHEN 'd'::"char" THEN 'SET DEFAULT'::"text"
            ELSE 'NO ACTION'::"text"
        END)::character varying(20) AS "on_update_action",
    (
        CASE "con"."confdeltype"
            WHEN 'a'::"char" THEN 'NO ACTION'::"text"
            WHEN 'r'::"char" THEN 'RESTRICT'::"text"
            WHEN 'c'::"char" THEN 'CASCADE'::"text"
            WHEN 'n'::"char" THEN 'SET NULL'::"text"
            WHEN 'd'::"char" THEN 'SET DEFAULT'::"text"
            ELSE 'NO ACTION'::"text"
        END)::character varying(20) AS "on_delete_action"
   FROM (((((("pg_constraint" "con"
     JOIN "pg_class" "source_table" ON (("source_table"."oid" = "con"."conrelid")))
     JOIN "pg_namespace" "source_ns" ON ((("source_ns"."oid" = "source_table"."relnamespace") AND ("source_ns"."nspname" = 'public'::"name"))))
     JOIN "pg_class" "referenced_table" ON (("referenced_table"."oid" = "con"."confrelid")))
     JOIN "pg_namespace" "referenced_ns" ON ((("referenced_ns"."oid" = "referenced_table"."relnamespace") AND ("referenced_ns"."nspname" = 'public'::"name"))))
     JOIN "public"."app_entities" "source_entity" ON ((("source_entity"."table_name")::"text" = "source_table"."relname")))
     JOIN "public"."app_entities" "referenced_entity" ON ((("referenced_entity"."table_name")::"text" = "referenced_table"."relname")))
  WHERE ("con"."contype" = 'f'::"char");


--
-- Name: app_entity_hidden_columns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_entity_hidden_columns" (
    "entity_key" character varying(100) NOT NULL,
    "column_name" character varying(100) NOT NULL
);


--
-- Name: app_entity_index_columns; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."app_entity_index_columns" AS
 SELECT "e"."entity_key",
    ("idx_name"."relname")::character varying(100) AS "index_name",
    ("key_col"."ordinality")::integer AS "position",
    "a"."attname" AS "column_name"
   FROM (((((("pg_index" "idx"
     JOIN "pg_class" "tbl" ON (("tbl"."oid" = "idx"."indrelid")))
     JOIN "pg_namespace" "ns" ON ((("ns"."oid" = "tbl"."relnamespace") AND ("ns"."nspname" = 'public'::"name"))))
     JOIN "pg_class" "idx_name" ON (("idx_name"."oid" = "idx"."indexrelid")))
     JOIN "public"."app_entities" "e" ON ((("e"."table_name")::"text" = "tbl"."relname")))
     JOIN LATERAL "unnest"("idx"."indkey") WITH ORDINALITY "key_col"("attnum", "ordinality") ON (("key_col"."attnum" > 0)))
     JOIN "pg_attribute" "a" ON ((("a"."attrelid" = "tbl"."oid") AND ("a"."attnum" = "key_col"."attnum"))))
  WHERE (("idx"."indisprimary" = false) AND (NOT (EXISTS ( SELECT 1
           FROM "pg_constraint" "con"
          WHERE ("con"."conindid" = "idx"."indexrelid")))));


--
-- Name: app_entity_indexes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."app_entity_indexes" AS
 SELECT "e"."entity_key",
    ("idx_name"."relname")::character varying(100) AS "index_name",
    "idx"."indisunique" AS "is_unique"
   FROM (((("pg_index" "idx"
     JOIN "pg_class" "tbl" ON (("tbl"."oid" = "idx"."indrelid")))
     JOIN "pg_namespace" "ns" ON ((("ns"."oid" = "tbl"."relnamespace") AND ("ns"."nspname" = 'public'::"name"))))
     JOIN "pg_class" "idx_name" ON (("idx_name"."oid" = "idx"."indexrelid")))
     JOIN "public"."app_entities" "e" ON ((("e"."table_name")::"text" = "tbl"."relname")))
  WHERE (("idx"."indisprimary" = false) AND (NOT (EXISTS ( SELECT 1
           FROM "pg_constraint" "con"
          WHERE ("con"."conindid" = "idx"."indexrelid")))));


--
-- Name: app_entity_primary_keys; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."app_entity_primary_keys" AS
 SELECT "e"."entity_key",
    ("key_col"."ordinality")::integer AS "position",
    "a"."attname" AS "column_name"
   FROM ((((("public"."app_entities" "e"
     JOIN "pg_class" "rel" ON (("rel"."relname" = ("e"."table_name")::"text")))
     JOIN "pg_namespace" "ns" ON ((("ns"."oid" = "rel"."relnamespace") AND ("ns"."nspname" = 'public'::"name"))))
     JOIN "pg_constraint" "con" ON ((("con"."conrelid" = "rel"."oid") AND ("con"."contype" = 'p'::"char"))))
     JOIN LATERAL "unnest"("con"."conkey") WITH ORDINALITY "key_col"("attnum", "ordinality") ON (true))
     JOIN "pg_attribute" "a" ON ((("a"."attrelid" = "rel"."oid") AND ("a"."attnum" = "key_col"."attnum"))));


--
-- Name: app_option_set_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_option_set_definitions" (
    "option_set_key" character varying(100) NOT NULL,
    "source_kind" character varying(50) NOT NULL,
    "label_es" character varying(200) NOT NULL,
    "label_en" character varying(200) NOT NULL
);


--
-- Name: app_referential_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_referential_actions" (
    "action_key" character varying(20) NOT NULL,
    "label_es" character varying(100) NOT NULL,
    "label_en" character varying(100) NOT NULL
);


--
-- Name: app_shown_referenced_entity_columns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_shown_referenced_entity_columns" (
    "entity_key" character varying(100) NOT NULL,
    "referenced_entity_key" character varying(100) NOT NULL,
    "displayed_entity_column" character varying(100) NOT NULL
);


--
-- Name: app_submenu_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_submenu_entities" (
    "submenu_key" character varying(100) NOT NULL,
    "entity_key" character varying(100) NOT NULL
);


--
-- Name: app_submenus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_submenus" (
    "submenu_key" character varying(100) NOT NULL,
    "label_es" character varying(200) NOT NULL,
    "label_en" character varying(200) NOT NULL
);


--
-- Name: app_ui_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_ui_messages" (
    "message_key" character varying(100) NOT NULL,
    "text_es" character varying(300) NOT NULL,
    "text_en" character varying(300) NOT NULL
);


--
-- Name: app_validation_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."app_validation_rules" (
    "validation_key" character varying(100) NOT NULL,
    "regex_pattern" "text" NOT NULL,
    "label_es" character varying(200) NOT NULL,
    "label_en" character varying(200) NOT NULL,
    "error_es" character varying(300) NOT NULL,
    "error_en" character varying(300) NOT NULL
);


--
-- Name: enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."enrollments" (
    "numero_libreta" character varying NOT NULL,
    "cod_mat" character varying NOT NULL,
    "enrollment_date" "date" NOT NULL,
    "grade" numeric,
    "status" character varying
);


--
-- Name: enrollments_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."enrollments_statuses" (
    "status_key" character varying(50) NOT NULL,
    "label_es" character varying(200) NOT NULL,
    "label_en" character varying(200) NOT NULL
);


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."students" (
    "numero_libreta" character varying NOT NULL,
    "dni" character varying NOT NULL,
    "first_name" character varying NOT NULL,
    "last_name" character varying NOT NULL,
    "email" character varying,
    "enrollment_date" "date",
    "status" character varying
);


--
-- Name: students_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."students_statuses" (
    "status_key" character varying(50) NOT NULL,
    "label_es" character varying(200) NOT NULL,
    "label_en" character varying(200) NOT NULL
);


--
-- Name: subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."subjects" (
    "cod_mat" character varying(20) NOT NULL,
    "name" character varying(200) NOT NULL,
    "description" "text",
    "credits" integer,
    "department" character varying(100)
);


--
-- Name: ui_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."ui_actions" (
    "action_key" character varying(100) NOT NULL,
    "label_es" character varying(200) NOT NULL,
    "label_en" character varying(200) NOT NULL
);


--
-- Name: app_data_type_ui_profiles app_data_type_ui_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_data_type_ui_profiles"
    ADD CONSTRAINT "app_data_type_ui_profiles_pkey" PRIMARY KEY ("data_type");


--
-- Name: app_data_types app_data_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_data_types"
    ADD CONSTRAINT "app_data_types_pkey" PRIMARY KEY ("data_type");


--
-- Name: app_entities app_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entities"
    ADD CONSTRAINT "app_entities_pkey" PRIMARY KEY ("entity_key");


--
-- Name: app_entities app_entities_table_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entities"
    ADD CONSTRAINT "app_entities_table_name_key" UNIQUE ("table_name");


--
-- Name: app_entity_column_validations app_entity_column_validations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entity_column_validations"
    ADD CONSTRAINT "app_entity_column_validations_pkey" PRIMARY KEY ("entity_key", "column_name", "validation_key");


--
-- Name: app_entity_columns app_entity_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entity_columns"
    ADD CONSTRAINT "app_entity_columns_pkey" PRIMARY KEY ("entity_key", "column_name");


--
-- Name: app_entity_hidden_columns app_entity_hidden_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entity_hidden_columns"
    ADD CONSTRAINT "app_entity_hidden_columns_pkey" PRIMARY KEY ("entity_key", "column_name");


--
-- Name: app_option_set_definitions app_option_set_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_option_set_definitions"
    ADD CONSTRAINT "app_option_set_definitions_pkey" PRIMARY KEY ("option_set_key");


--
-- Name: app_referential_actions app_referential_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_referential_actions"
    ADD CONSTRAINT "app_referential_actions_pkey" PRIMARY KEY ("action_key");


--
-- Name: app_shown_referenced_entity_columns app_shown_referenced_entity_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_shown_referenced_entity_columns"
    ADD CONSTRAINT "app_shown_referenced_entity_columns_pkey" PRIMARY KEY ("entity_key", "referenced_entity_key", "displayed_entity_column");


--
-- Name: app_submenu_entities app_submenu_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_submenu_entities"
    ADD CONSTRAINT "app_submenu_entities_pkey" PRIMARY KEY ("submenu_key", "entity_key");


--
-- Name: app_submenus app_submenus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_submenus"
    ADD CONSTRAINT "app_submenus_pkey" PRIMARY KEY ("submenu_key");


--
-- Name: app_ui_messages app_ui_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_ui_messages"
    ADD CONSTRAINT "app_ui_messages_pkey" PRIMARY KEY ("message_key");


--
-- Name: app_validation_rules app_validation_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_validation_rules"
    ADD CONSTRAINT "app_validation_rules_pkey" PRIMARY KEY ("validation_key");


--
-- Name: enrollments_statuses enrollments_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."enrollments_statuses"
    ADD CONSTRAINT "enrollments_statuses_pkey" PRIMARY KEY ("status_key");


--
-- Name: enrollments pk_meta_enrollments; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."enrollments"
    ADD CONSTRAINT "pk_meta_enrollments" PRIMARY KEY ("numero_libreta", "cod_mat");


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_pkey" PRIMARY KEY ("numero_libreta");


--
-- Name: students_statuses students_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."students_statuses"
    ADD CONSTRAINT "students_statuses_pkey" PRIMARY KEY ("status_key");


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."subjects"
    ADD CONSTRAINT "subjects_pkey" PRIMARY KEY ("cod_mat");


--
-- Name: ui_actions ui_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."ui_actions"
    ADD CONSTRAINT "ui_actions_pkey" PRIMARY KEY ("action_key");


--
-- Name: idx_meta_enrollments_idx_enrollments_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_meta_enrollments_idx_enrollments_status" ON "public"."enrollments" USING "btree" ("status");


--
-- Name: idx_meta_students_idx_students_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_meta_students_idx_students_status" ON "public"."students" USING "btree" ("status");


--
-- Name: app_data_type_ui_profiles trg_guard_app_data_type_ui_profiles; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_data_type_ui_profiles" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_data_type_ui_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_data_types trg_guard_app_data_types; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_data_types" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_data_types" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_entities trg_guard_app_entities; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_entities" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_entities" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_entity_column_validations trg_guard_app_entity_column_validations; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_entity_column_validations" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_entity_column_validations" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_entity_columns trg_guard_app_entity_columns; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_entity_columns" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_entity_columns" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_entity_hidden_columns trg_guard_app_entity_hidden_columns; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_entity_hidden_columns" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_entity_hidden_columns" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_option_set_definitions trg_guard_app_option_set_definitions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_option_set_definitions" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_option_set_definitions" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_referential_actions trg_guard_app_referential_actions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_referential_actions" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_referential_actions" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_shown_referenced_entity_columns trg_guard_app_shown_referenced_entity_columns; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_shown_referenced_entity_columns" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_shown_referenced_entity_columns" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_submenu_entities trg_guard_app_submenu_entities; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_submenu_entities" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_submenu_entities" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_submenus trg_guard_app_submenus; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_submenus" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_submenus" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_ui_messages trg_guard_app_ui_messages; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_ui_messages" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_ui_messages" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_validation_rules trg_guard_app_validation_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_app_validation_rules" BEFORE INSERT OR DELETE OR UPDATE ON "public"."app_validation_rules" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: ui_actions trg_guard_ui_actions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_guard_ui_actions" BEFORE INSERT OR DELETE OR UPDATE ON "public"."ui_actions" FOR EACH ROW EXECUTE FUNCTION "public"."guard_metadata_writes_for_app_user"();


--
-- Name: app_entity_columns trg_normalize_app_entity_column_labels; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_normalize_app_entity_column_labels" BEFORE INSERT OR UPDATE ON "public"."app_entity_columns" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_app_entity_column_labels"();


--
-- Name: app_entities trg_normalize_app_entity_labels; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_normalize_app_entity_labels" BEFORE INSERT OR UPDATE ON "public"."app_entities" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_app_entity_labels"();


--
-- Name: students trg_students_regex_validation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "trg_students_regex_validation" BEFORE INSERT OR UPDATE ON "public"."students" FOR EACH ROW EXECUTE FUNCTION "public"."trg_validate_students_regex_rules"();


--
-- Name: app_data_type_ui_profiles app_data_type_ui_profiles_data_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_data_type_ui_profiles"
    ADD CONSTRAINT "app_data_type_ui_profiles_data_type_fkey" FOREIGN KEY ("data_type") REFERENCES "public"."app_data_types"("data_type") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: app_entity_column_validations app_entity_column_validations_entity_key_column_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entity_column_validations"
    ADD CONSTRAINT "app_entity_column_validations_entity_key_column_name_fkey" FOREIGN KEY ("entity_key", "column_name") REFERENCES "public"."app_entity_columns"("entity_key", "column_name") ON DELETE CASCADE;


--
-- Name: app_entity_column_validations app_entity_column_validations_validation_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entity_column_validations"
    ADD CONSTRAINT "app_entity_column_validations_validation_key_fkey" FOREIGN KEY ("validation_key") REFERENCES "public"."app_validation_rules"("validation_key") ON DELETE CASCADE;


--
-- Name: app_entity_columns app_entity_columns_data_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entity_columns"
    ADD CONSTRAINT "app_entity_columns_data_type_fkey" FOREIGN KEY ("data_type") REFERENCES "public"."app_data_types"("data_type") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: app_entity_columns app_entity_columns_entity_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entity_columns"
    ADD CONSTRAINT "app_entity_columns_entity_key_fkey" FOREIGN KEY ("entity_key") REFERENCES "public"."app_entities"("entity_key") ON DELETE CASCADE;


--
-- Name: app_entity_hidden_columns app_entity_hidden_columns_entity_key_column_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entity_hidden_columns"
    ADD CONSTRAINT "app_entity_hidden_columns_entity_key_column_name_fkey" FOREIGN KEY ("entity_key", "column_name") REFERENCES "public"."app_entity_columns"("entity_key", "column_name") ON DELETE CASCADE;


--
-- Name: app_entity_hidden_columns app_entity_hidden_columns_entity_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_entity_hidden_columns"
    ADD CONSTRAINT "app_entity_hidden_columns_entity_key_fkey" FOREIGN KEY ("entity_key") REFERENCES "public"."app_entities"("entity_key") ON DELETE CASCADE;


--
-- Name: app_shown_referenced_entity_columns app_shown_referenced_entity_c_referenced_entity_key_displa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_shown_referenced_entity_columns"
    ADD CONSTRAINT "app_shown_referenced_entity_c_referenced_entity_key_displa_fkey" FOREIGN KEY ("referenced_entity_key", "displayed_entity_column") REFERENCES "public"."app_entity_columns"("entity_key", "column_name") ON DELETE CASCADE;


--
-- Name: app_shown_referenced_entity_columns app_shown_referenced_entity_columns_entity_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_shown_referenced_entity_columns"
    ADD CONSTRAINT "app_shown_referenced_entity_columns_entity_key_fkey" FOREIGN KEY ("entity_key") REFERENCES "public"."app_entities"("entity_key") ON DELETE CASCADE;


--
-- Name: app_shown_referenced_entity_columns app_shown_referenced_entity_columns_referenced_entity_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_shown_referenced_entity_columns"
    ADD CONSTRAINT "app_shown_referenced_entity_columns_referenced_entity_key_fkey" FOREIGN KEY ("referenced_entity_key") REFERENCES "public"."app_entities"("entity_key") ON DELETE CASCADE;


--
-- Name: app_submenu_entities app_submenu_entities_entity_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_submenu_entities"
    ADD CONSTRAINT "app_submenu_entities_entity_key_fkey" FOREIGN KEY ("entity_key") REFERENCES "public"."app_entities"("entity_key") ON DELETE CASCADE;


--
-- Name: app_submenu_entities app_submenu_entities_submenu_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."app_submenu_entities"
    ADD CONSTRAINT "app_submenu_entities_submenu_key_fkey" FOREIGN KEY ("submenu_key") REFERENCES "public"."app_submenus"("submenu_key") ON DELETE CASCADE;


--
-- Name: enrollments enrollments_cod_mat_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."enrollments"
    ADD CONSTRAINT "enrollments_cod_mat_fkey" FOREIGN KEY ("cod_mat") REFERENCES "public"."subjects"("cod_mat") ON UPDATE CASCADE;


--
-- Name: enrollments enrollments_numero_libreta_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."enrollments"
    ADD CONSTRAINT "enrollments_numero_libreta_fkey" FOREIGN KEY ("numero_libreta") REFERENCES "public"."students"("numero_libreta") ON UPDATE CASCADE;


--
-- Name: enrollments enrollments_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."enrollments"
    ADD CONSTRAINT "enrollments_status_fkey" FOREIGN KEY ("status") REFERENCES "public"."enrollments_statuses"("status_key") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: students students_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_status_fkey" FOREIGN KEY ("status") REFERENCES "public"."students_statuses"("status_key") ON UPDATE CASCADE ON DELETE RESTRICT;


--
--


