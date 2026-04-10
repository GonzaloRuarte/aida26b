-- Harden index sync by namespacing physical index names.
-- Avoid collisions when two entities reuse the same metadata index_name.

CREATE OR REPLACE FUNCTION metadata_managed_index_name(target_entity_key TEXT, target_index_name TEXT)
RETURNS TEXT AS $$
DECLARE
    physical_name TEXT;
BEGIN
    physical_name := format('idx_meta_%s_%s', target_entity_key, target_index_name);
    IF length(physical_name) > 63 THEN
        physical_name := 'idxm_' || substr(md5(target_entity_key || '_' || target_index_name), 1, 58);
    END IF;
    RETURN physical_name;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION sync_entity_index(target_entity_key TEXT, target_index_name TEXT)
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DO $$
DECLARE
    index_record RECORD;
    column_list TEXT;
    table_name_value TEXT;
    physical_index_name TEXT;
BEGIN
    FOR index_record IN
        SELECT entity_key, index_name, is_unique
        FROM app_entity_indexes
        ORDER BY entity_key, index_name
    LOOP
        SELECT table_name INTO table_name_value
        FROM app_entities
        WHERE entity_key = index_record.entity_key;

        IF table_name_value IS NULL THEN
            CONTINUE;
        END IF;

        SELECT string_agg(format('%I', column_name), ', ' ORDER BY position)
          INTO column_list
        FROM app_entity_index_columns
        WHERE entity_key = index_record.entity_key
          AND index_name = index_record.index_name;

        physical_index_name := metadata_managed_index_name(index_record.entity_key, index_record.index_name);

        EXECUTE format('DROP INDEX IF EXISTS %I', physical_index_name);
        EXECUTE format('DROP INDEX IF EXISTS %I', index_record.index_name);

        IF column_list IS NOT NULL THEN
            EXECUTE format(
                'CREATE %sINDEX %I ON %I (%s)',
                CASE WHEN index_record.is_unique THEN 'UNIQUE ' ELSE '' END,
                physical_index_name,
                table_name_value,
                column_list
            );
        END IF;
    END LOOP;
END $$;
