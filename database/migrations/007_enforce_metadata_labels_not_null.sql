-- Enforce non-null labels for app_entities and app_entity_columns
-- with normalization triggers that fill defaults when values are null/blank.

CREATE OR REPLACE FUNCTION normalize_app_entity_labels()
RETURNS TRIGGER AS $$
BEGIN
    NEW.singular_es := COALESCE(NULLIF(trim(NEW.singular_es), ''), initcap(replace(NEW.entity_key, '_', ' ')));
    NEW.singular_en := COALESCE(NULLIF(trim(NEW.singular_en), ''), initcap(replace(NEW.entity_key, '_', ' ')));
    NEW.plural_es := COALESCE(NULLIF(trim(NEW.plural_es), ''), NEW.singular_es || 's');
    NEW.plural_en := COALESCE(NULLIF(trim(NEW.plural_en), ''), NEW.singular_en || 's');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION normalize_app_entity_column_labels()
RETURNS TRIGGER AS $$
BEGIN
    NEW.label_es := COALESCE(NULLIF(trim(NEW.label_es), ''), initcap(replace(NEW.column_name, '_', ' ')));
    NEW.label_en := COALESCE(NULLIF(trim(NEW.label_en), ''), initcap(replace(NEW.column_name, '_', ' ')));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_app_entity_labels ON app_entities;
DROP TRIGGER IF EXISTS trg_normalize_app_entity_column_labels ON app_entity_columns;

CREATE TRIGGER trg_normalize_app_entity_labels
BEFORE INSERT OR UPDATE ON app_entities
FOR EACH ROW
EXECUTE FUNCTION normalize_app_entity_labels();

CREATE TRIGGER trg_normalize_app_entity_column_labels
BEFORE INSERT OR UPDATE ON app_entity_columns
FOR EACH ROW
EXECUTE FUNCTION normalize_app_entity_column_labels();

-- Normalize existing rows.
UPDATE app_entities
SET
    singular_es = COALESCE(NULLIF(trim(singular_es), ''), initcap(replace(entity_key, '_', ' '))),
    singular_en = COALESCE(NULLIF(trim(singular_en), ''), initcap(replace(entity_key, '_', ' '))),
    plural_es = COALESCE(NULLIF(trim(plural_es), ''), COALESCE(NULLIF(trim(singular_es), ''), initcap(replace(entity_key, '_', ' '))) || 's'),
    plural_en = COALESCE(NULLIF(trim(plural_en), ''), COALESCE(NULLIF(trim(singular_en), ''), initcap(replace(entity_key, '_', ' '))) || 's')
WHERE NULLIF(trim(singular_es), '') IS NULL
    OR NULLIF(trim(singular_en), '') IS NULL
    OR NULLIF(trim(plural_es), '') IS NULL
    OR NULLIF(trim(plural_en), '') IS NULL;

UPDATE app_entity_columns
SET
    label_es = COALESCE(NULLIF(trim(label_es), ''), initcap(replace(column_name, '_', ' '))),
    label_en = COALESCE(NULLIF(trim(label_en), ''), initcap(replace(column_name, '_', ' ')))
WHERE NULLIF(trim(label_es), '') IS NULL
    OR NULLIF(trim(label_en), '') IS NULL;

-- Keep app_entity_column_nullability aligned with intended non-null behavior.
DELETE FROM app_entity_column_nullability
WHERE (entity_key = 'app_entities' AND column_name IN ('singular_es', 'singular_en', 'plural_es', 'plural_en'))
   OR (entity_key = 'app_entity_columns' AND column_name IN ('label_es', 'label_en'));

ALTER TABLE app_entities ALTER COLUMN singular_es SET NOT NULL;
ALTER TABLE app_entities ALTER COLUMN singular_en SET NOT NULL;
ALTER TABLE app_entities ALTER COLUMN plural_es SET NOT NULL;
ALTER TABLE app_entities ALTER COLUMN plural_en SET NOT NULL;

ALTER TABLE app_entity_columns ALTER COLUMN label_es SET NOT NULL;
ALTER TABLE app_entity_columns ALTER COLUMN label_en SET NOT NULL;
