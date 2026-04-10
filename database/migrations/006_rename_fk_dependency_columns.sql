-- Rename dependency metadata columns to readable names and sync metadata references.
-- Safe to run on databases that already have the new names.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'app_entity_foreign_key_dependencies'
          AND column_name = 'child_foreign_key_key'
    ) THEN
        EXECUTE 'ALTER TABLE app_entity_foreign_key_dependencies RENAME COLUMN child_foreign_key_key TO dependent_foreign_key_key';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'app_entity_foreign_key_dependencies'
          AND column_name = 'parent_foreign_key_key'
    ) THEN
        EXECUTE 'ALTER TABLE app_entity_foreign_key_dependencies RENAME COLUMN parent_foreign_key_key TO required_foreign_key_key';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'app_entity_foreign_key_dependency_mappings'
          AND column_name = 'child_foreign_key_key'
    ) THEN
        EXECUTE 'ALTER TABLE app_entity_foreign_key_dependency_mappings RENAME COLUMN child_foreign_key_key TO dependent_foreign_key_key';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'app_entity_foreign_key_dependency_mappings'
          AND column_name = 'parent_foreign_key_key'
    ) THEN
        EXECUTE 'ALTER TABLE app_entity_foreign_key_dependency_mappings RENAME COLUMN parent_foreign_key_key TO required_foreign_key_key';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'app_entity_foreign_key_dependency_mappings'
          AND column_name = 'child_position'
    ) THEN
        EXECUTE 'ALTER TABLE app_entity_foreign_key_dependency_mappings RENAME COLUMN child_position TO shared_local_column_name';
    END IF;
END $$;

-- If the old parent_position still exists, migrate to shared_local_column_name by joining FK metadata.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'app_entity_foreign_key_dependency_mappings'
          AND column_name = 'parent_position'
    ) THEN
        -- Convert numeric position currently stored in shared_local_column_name into the real local column name.
        UPDATE app_entity_foreign_key_dependency_mappings mapping
        SET shared_local_column_name = fk.column_name
        FROM app_entity_foreign_keys fk
        WHERE fk.entity_key = mapping.entity_key
          AND fk.foreign_key_key = mapping.dependent_foreign_key_key
          AND fk.position::text = mapping.shared_local_column_name;

        EXECUTE 'ALTER TABLE app_entity_foreign_key_dependency_mappings DROP COLUMN parent_position';
    END IF;
END $$;

-- Sync metadata rows that track column names in metadata tables.
UPDATE app_entity_columns
SET column_name = 'dependent_foreign_key_key'
WHERE entity_key IN ('app_entity_foreign_key_dependencies', 'app_entity_foreign_key_dependency_mappings')
  AND column_name = 'child_foreign_key_key';

UPDATE app_entity_columns
SET column_name = 'required_foreign_key_key'
WHERE entity_key IN ('app_entity_foreign_key_dependencies', 'app_entity_foreign_key_dependency_mappings')
  AND column_name = 'parent_foreign_key_key';

UPDATE app_entity_columns
SET column_name = 'shared_local_column_name'
WHERE entity_key = 'app_entity_foreign_key_dependency_mappings'
  AND column_name IN ('child_position', 'parent_position');

UPDATE app_entity_primary_keys
SET column_name = 'dependent_foreign_key_key'
WHERE entity_key IN ('app_entity_foreign_key_dependencies', 'app_entity_foreign_key_dependency_mappings')
  AND column_name = 'child_foreign_key_key';

UPDATE app_entity_primary_keys
SET column_name = 'required_foreign_key_key'
WHERE entity_key IN ('app_entity_foreign_key_dependencies', 'app_entity_foreign_key_dependency_mappings')
  AND column_name = 'parent_foreign_key_key';

UPDATE app_entity_primary_keys
SET column_name = 'shared_local_column_name'
WHERE entity_key = 'app_entity_foreign_key_dependency_mappings'
  AND column_name IN ('child_position', 'parent_position');

UPDATE app_entity_column_nullability
SET column_name = 'dependent_foreign_key_key'
WHERE entity_key IN ('app_entity_foreign_key_dependencies', 'app_entity_foreign_key_dependency_mappings')
  AND column_name = 'child_foreign_key_key';

UPDATE app_entity_column_nullability
SET column_name = 'required_foreign_key_key'
WHERE entity_key IN ('app_entity_foreign_key_dependencies', 'app_entity_foreign_key_dependency_mappings')
  AND column_name = 'parent_foreign_key_key';

UPDATE app_entity_column_nullability
SET column_name = 'shared_local_column_name'
WHERE entity_key = 'app_entity_foreign_key_dependency_mappings'
  AND column_name IN ('child_position', 'parent_position');

UPDATE app_entity_foreign_keys
SET column_name = 'dependent_foreign_key_key'
WHERE entity_key = 'app_entity_foreign_key_dependency_mappings'
  AND column_name = 'child_foreign_key_key';

UPDATE app_entity_foreign_keys
SET column_name = 'required_foreign_key_key'
WHERE entity_key = 'app_entity_foreign_key_dependency_mappings'
  AND column_name = 'parent_foreign_key_key';

UPDATE app_entity_foreign_keys
SET column_name = 'shared_local_column_name'
WHERE entity_key = 'app_entity_foreign_key_dependency_mappings'
  AND column_name IN ('child_position', 'parent_position');

UPDATE app_entity_foreign_keys
SET referenced_column_name = 'dependent_foreign_key_key'
WHERE referenced_entity_key = 'app_entity_foreign_key_dependencies'
  AND referenced_column_name = 'child_foreign_key_key';

UPDATE app_entity_foreign_keys
SET referenced_column_name = 'required_foreign_key_key'
WHERE referenced_entity_key = 'app_entity_foreign_key_dependencies'
  AND referenced_column_name = 'parent_foreign_key_key';

UPDATE app_entity_foreign_keys
SET referenced_column_name = 'dependent_foreign_key_key'
WHERE referenced_entity_key = 'app_entity_foreign_key_dependency_mappings'
  AND referenced_column_name = 'child_foreign_key_key';

UPDATE app_entity_foreign_keys
SET referenced_column_name = 'required_foreign_key_key'
WHERE referenced_entity_key = 'app_entity_foreign_key_dependency_mappings'
  AND referenced_column_name = 'parent_foreign_key_key';

UPDATE app_entity_foreign_keys
SET referenced_column_name = 'shared_local_column_name'
WHERE referenced_entity_key = 'app_entity_foreign_key_dependency_mappings'
  AND referenced_column_name IN ('child_position', 'parent_position');

-- Remove duplicate PK metadata rows if both old and new names existed during transition.
DELETE FROM app_entity_primary_keys a
USING app_entity_primary_keys b
WHERE a.ctid < b.ctid
  AND a.entity_key = b.entity_key
  AND a.column_name = b.column_name;
