-- Limit structural sync triggers so non-structural metadata edits (labels) do not
-- trigger physical table/PK reconciliation.

DROP TRIGGER IF EXISTS trg_sync_entity_tables_on_entities ON app_entities;
DROP TRIGGER IF EXISTS trg_sync_entity_tables_on_columns ON app_entity_columns;

CREATE TRIGGER trg_sync_entity_tables_on_entities
AFTER INSERT OR DELETE OR UPDATE OF entity_key, table_name ON app_entities
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_tables_from_entities();

CREATE TRIGGER trg_sync_entity_tables_on_columns
AFTER INSERT OR DELETE OR UPDATE OF entity_key, column_name, data_type ON app_entity_columns
FOR EACH ROW
EXECUTE FUNCTION trg_sync_entity_tables_from_columns_or_pk();
