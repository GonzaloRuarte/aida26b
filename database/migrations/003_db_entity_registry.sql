-- Deprecated migration retained for history.
-- This migration previously introduced legacy metadata (list_relation_name, ui_* label tables,
-- and list SQL relation metadata) that has been replaced by canonical metadata columns.
--
-- Current normalized model:
--   - app_entities contains entity labels (singular/plural, es/en)
--   - app_entity_columns contains column labels (es/en)
--   - nullability/uniqueness are modeled in app_entity_column_nullability and app_entity_column_uniqueness
--   - list projection uses all entity columns minus app_entity_hidden_columns, then adds app_shown_referenced_entity_columns
--   - app_entity_* tables keep PK/FK/order/filter/index metadata
--
-- No-op by design to avoid reintroducing deprecated structures.
DO $$
BEGIN
  RAISE NOTICE 'Migration 003_db_entity_registry.sql is deprecated and intentionally does nothing.';
END $$;
