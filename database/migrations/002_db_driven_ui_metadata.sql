-- Deprecated migration retained for history.
-- This migration previously created ui_* metadata and option-set tables
-- (ui_entity_meta, ui_field_meta, ui_entity_field_meta, ui_option_sets, ui_option_items)
-- that are no longer part of the normalized model.
--
-- Current normalized model stores canonical metadata in:
--   - app_entities
--   - app_entity_columns
--   - app_entity_primary_keys
--   - app_entity_foreign_keys
--   - app_entity_ordering / app_entity_filters
--
-- No-op by design to avoid reintroducing deprecated structures.
DO $$
BEGIN
  RAISE NOTICE 'Migration 002_db_driven_ui_metadata.sql is deprecated and intentionally does nothing.';
END $$;
