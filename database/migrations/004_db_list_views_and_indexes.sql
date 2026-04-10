-- Deprecated migration retained for history.
-- This migration previously created app_entity_list_relations (stored SQL list metadata)
-- and related legacy bindings that are now replaced by normalized metadata tables.
--
-- Current normalized list model:
--   - base list columns come from all columns in the entity table
--   - app_entity_hidden_columns: local columns excluded from list output
--   - app_shown_referenced_entity_columns: referenced columns explicitly projected for each entity
--   - backend generates list projection SQL dynamically from metadata
--
-- No-op by design to avoid restoring deprecated structures.
DO $$
BEGIN
  RAISE NOTICE 'Migration 004_db_list_views_and_indexes.sql is deprecated and intentionally does nothing.';
END $$;
