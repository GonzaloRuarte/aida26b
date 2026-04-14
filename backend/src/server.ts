import express from 'express';
import cors from 'cors';
import { Pool } from 'pg';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const DEFAULT_REFERENTIAL_ACTION = 'NO ACTION';
const REFERENTIAL_ACTIONS = ['NO ACTION', 'RESTRICT', 'CASCADE', 'SET NULL', 'SET DEFAULT'] as const;
const REFERENTIAL_ACTION_SET = new Set<string>(REFERENTIAL_ACTIONS);

const schemaStudioDbUser = process.env.SCHEMA_STUDIO_DB_USER;
const schemaStudioDbPassword = process.env.SCHEMA_STUDIO_DB_PASSWORD;

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

const schemaStudioPool = schemaStudioDbUser && schemaStudioDbPassword
  ? new Pool({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME,
    user: schemaStudioDbUser,
    password: schemaStudioDbPassword,
  })
  : null;

app.use(cors());
app.use(express.json());

type LocaleText = { es: string; en: string };

type OptionItem = {
  value: string;
  label: LocaleText;
};

type ColumnInfo = {
  columnName: string;
  dataType: string;
  isNullable: boolean;
};

type EntityRegistryRecord = {
  entityKey: string;
  tableName: string;
  singular: LocaleText;
  plural: LocaleText;
};

type EntityHiddenColumnRecord = {
  entityKey: string;
  columnName: string;
};

type ShownReferencedEntityColumnRecord = {
  entityKey: string;
  referencedEntityKey: string;
  displayedEntityColumn: string;
};

type EntityColumnMetaRecord = {
  entityKey: string;
  columnName: string;
  label: LocaleText;
};

type EntityPrimaryKeyRecord = {
  entityKey: string;
  position: number;
  columnName: string;
};

type DataTypeUIProfileRecord = {
  dataType: string;
  control?: string;
  inputType?: string;
  parser?: string;
  step?: string;
};

type EntityForeignKeyRecord = {
  entityKey: string;
  foreignKeyKey: string;
  referencedEntityKey: string;
  onUpdateAction: string;
  onDeleteAction: string;
  columns: Array<{
    position: number;
    columnName: string;
    referencedColumnName: string;
  }>;
};

type ForeignKeyDependencyRecord = {
  entityKey: string;
  dependentForeignKeyKey: string;
  requiredForeignKeyKey: string;
  mappings: Array<{
    sharedLocalColumnName: string;
  }>;
};

type ForeignKeyOptionRow = {
  value: string;
  label: LocaleText;
  referencedValues: Record<string, string>;
};

type RuntimeEntityConfig = {
  entityName: string;
  tableName: string;
  primaryKeyColumns: string[];
  writeColumns: string[];
  listColumns: string[];
  foreignKeys: EntityForeignKeyRecord[];
};

type ListDataTypeKind = 'string' | 'number' | 'boolean' | 'date';

type ListFilterCondition = {
  field: string;
  operator: string;
  value: string;
  group: number;
};

type ListSortCondition = {
  field: string;
  direction: 'ASC' | 'DESC';
};

type ListQueryOptions = {
  filters: ListFilterCondition[];
  filterLogic: 'AND' | 'OR';
  groupLogic: 'AND' | 'OR';
  sorts: ListSortCondition[];
  page: number;
  pageSize: number;
  includeMeta: boolean;
};

type OptionSetDefinitionRecord = {
  optionSetKey: string;
  sourceKind: string;
  label: LocaleText;
};

type SchemaStudioColumnInput = {
  originalColumnName?: string;
  columnName: string;
  dataType: string;
  labelEs: string;
  labelEn: string;
  nullable: boolean;
  primaryKey: boolean;
  primaryKeyPosition: number;
};

type SchemaStudioForeignKeyInput = {
  constraintName?: string;
  columns: string[];
  referencedTable: string;
  referencedColumns: string[];
  onUpdateAction: string;
  onDeleteAction: string;
};

type SchemaStudioIndexInput = {
  indexName: string;
  columns: string[];
  isUnique: boolean;
};

type SchemaStudioEntityModel = {
  entityKey: string;
  tableName: string;
  dataTypes: string[];
  referencedTables: string[];
  columns: SchemaStudioColumnInput[];
  foreignKeys: SchemaStudioForeignKeyInput[];
  indexes: SchemaStudioIndexInput[];
};

const API_ERROR_MESSAGES = {
  entityNotFound: 'Entity not found',
  invalidPrimaryKeyFormat: 'Invalid primary key format',
  recordNotFound: 'Record not found',
  noFieldsProvidedForInsert: 'No fields provided for insert',
  noFieldsProvidedForUpdate: 'No fields provided for update',
  invalidListQuery: 'Invalid list query parameters',
} as const;

type FrontendMetadataBundle = {
  app_entities: Array<Record<string, any>>;
  app_entity_hidden_columns: Array<Record<string, any>>;
  app_shown_referenced_entity_columns: Array<Record<string, any>>;
  app_entity_columns: Array<Record<string, any>>;
  app_entity_primary_keys: Array<Record<string, any>>;
  app_data_type_ui_profiles: Array<Record<string, any>>;
  app_entity_foreign_keys: Array<Record<string, any>>;
  app_entity_foreign_key_groups: Array<Record<string, any>>;
  app_entity_foreign_key_dependencies: Array<Record<string, any>>;
  app_entity_foreign_key_dependency_mappings: Array<Record<string, any>>;
  app_option_set_definitions: Array<Record<string, any>>;
  app_validation_rules: Array<Record<string, any>>;
  app_entity_column_validations: Array<Record<string, any>>;
  app_ui_messages: Array<Record<string, any>>;
  app_submenus: Array<Record<string, any>>;
  app_submenu_entities: Array<Record<string, any>>;
  ui_actions: Array<Record<string, any>>;
};

function createEmptyFrontendMetadataBundle(): FrontendMetadataBundle {
  return {
    app_entities: [],
    app_entity_hidden_columns: [],
    app_shown_referenced_entity_columns: [],
    app_entity_columns: [],
    app_entity_primary_keys: [],
    app_data_type_ui_profiles: [],
    app_entity_foreign_keys: [],
    app_entity_foreign_key_groups: [],
    app_entity_foreign_key_dependencies: [],
    app_entity_foreign_key_dependency_mappings: [],
    app_option_set_definitions: [],
    app_validation_rules: [],
    app_entity_column_validations: [],
    app_ui_messages: [],
    app_submenus: [],
    app_submenu_entities: [],
    ui_actions: [],
  };
}

async function getFrontendMetadataBundle(): Promise<FrontendMetadataBundle> {
  const result = await pool.query<{ bundle: FrontendMetadataBundle }>('SELECT api_frontend_metadata_bundle() AS bundle');
  return result.rows[0]?.bundle || createEmptyFrontendMetadataBundle();
}

function quoteIdentifier(identifier: string): string {
  return `"${identifier.replace(/"/g, '""')}"`;
}

function isSafeIdentifier(identifier: string): boolean {
  return /^[A-Za-z_][A-Za-z0-9_]*$/.test(identifier);
}

function normalizeConstraintAction(action: string): string {
  const normalized = action.trim().toUpperCase();
  if (!REFERENTIAL_ACTION_SET.has(normalized)) {
    throw new Error(`Unsupported referential action: ${action}`);
  }
  return normalized;
}

function splitCsvColumns(value: string): string[] {
  return value
    .split(',')
    .map(entry => entry.trim())
    .filter(entry => entry.length > 0);
}

function ensureValidIdentifiers(identifiers: string[], contextLabel: string) {
  for (const identifier of identifiers) {
    if (!isSafeIdentifier(identifier)) {
      throw new Error(`Invalid identifier in ${contextLabel}: ${identifier}`);
    }
  }
}

async function getAllowedSchemaStudioDataTypes(): Promise<Set<string>> {
  const rows = await queryRowsOrEmpty<{ data_type: string }>(
    `
      SELECT data_type
      FROM app_data_types
      ORDER BY data_type
    `
  );
  return new Set(rows.map(row => row.data_type.toLowerCase()));
}

async function resolveSchemaStudioEntityTableName(entityKey: string): Promise<string | null> {
  const row = await pool.query<{ table_name: string }>(
    `
      SELECT table_name
      FROM app_entities
      WHERE entity_key = $1
        AND entity_key NOT LIKE 'app_%'
        AND entity_key <> 'ui_actions'
      LIMIT 1
    `,
    [entityKey]
  );
  return row.rows[0]?.table_name || null;
}

async function getSchemaStudioEntityModel(entityKey: string): Promise<SchemaStudioEntityModel | null> {
  const tableName = await resolveSchemaStudioEntityTableName(entityKey);
  if (!tableName) {
    return null;
  }

  const dataTypeRows = await queryRowsOrEmpty<{ data_type: string }>(
    `
      SELECT data_type
      FROM app_data_types
      ORDER BY data_type
    `
  );

  const referencedTableRows = await queryRowsOrEmpty<{ table_name: string }>(
    `
      SELECT DISTINCT table_name
      FROM app_entities
      WHERE entity_key NOT LIKE 'app_%'
        AND entity_key <> 'ui_actions'
      ORDER BY table_name
    `
  );

  const columns = await queryRowsOrEmpty<{
    column_name: string;
    data_type: string;
    is_nullable: string;
    label_es: string | null;
    label_en: string | null;
  }>(
    `
      SELECT
        c.column_name,
        c.data_type,
        c.is_nullable,
        m.label_es,
        m.label_en
      FROM information_schema.columns c
      LEFT JOIN app_entity_columns m
        ON m.entity_key = $1
       AND m.column_name = c.column_name
      WHERE c.table_schema = 'public'
        AND c.table_name = $2
      ORDER BY c.ordinal_position
    `,
    [entityKey, tableName]
  );

  const pkRows = await queryRowsOrEmpty<{
    position: number;
    column_name: string;
  }>(
    `
      SELECT
        key_col.ordinality::integer AS position,
        a.attname AS column_name
      FROM pg_constraint con
      JOIN pg_class rel
        ON rel.oid = con.conrelid
      JOIN pg_namespace ns
        ON ns.oid = rel.relnamespace
       AND ns.nspname = 'public'
      JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS key_col(attnum, ordinality)
        ON TRUE
      JOIN pg_attribute a
        ON a.attrelid = rel.oid
       AND a.attnum = key_col.attnum
      WHERE con.contype = 'p'
        AND rel.relname = $1
      ORDER BY key_col.ordinality
    `,
    [tableName]
  );
  const pkPositionMap = new Map(pkRows.map(row => [row.column_name, row.position]));

  const fkRows = await queryRowsOrEmpty<{
    constraint_name: string;
    referenced_table_name: string;
    on_update_action: string;
    on_delete_action: string;
    position: number;
    column_name: string;
    referenced_column_name: string;
  }>(
    `
      SELECT
        con.conname AS constraint_name,
        ref.relname AS referenced_table_name,
        CASE con.confupdtype
          WHEN 'a' THEN 'NO ACTION'
          WHEN 'r' THEN 'RESTRICT'
          WHEN 'c' THEN 'CASCADE'
          WHEN 'n' THEN 'SET NULL'
          WHEN 'd' THEN 'SET DEFAULT'
          ELSE 'NO ACTION'
        END AS on_update_action,
        CASE con.confdeltype
          WHEN 'a' THEN 'NO ACTION'
          WHEN 'r' THEN 'RESTRICT'
          WHEN 'c' THEN 'CASCADE'
          WHEN 'n' THEN 'SET NULL'
          WHEN 'd' THEN 'SET DEFAULT'
          ELSE 'NO ACTION'
        END AS on_delete_action,
        source_cols.ordinality::integer AS position,
        source_attr.attname AS column_name,
        referenced_attr.attname AS referenced_column_name
      FROM pg_constraint con
      JOIN pg_class src
        ON src.oid = con.conrelid
      JOIN pg_namespace src_ns
        ON src_ns.oid = src.relnamespace
       AND src_ns.nspname = 'public'
      JOIN pg_class ref
        ON ref.oid = con.confrelid
      JOIN pg_namespace ref_ns
        ON ref_ns.oid = ref.relnamespace
       AND ref_ns.nspname = 'public'
      JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS source_cols(attnum, ordinality)
        ON TRUE
      JOIN LATERAL unnest(con.confkey) WITH ORDINALITY AS ref_cols(attnum, ordinality)
        ON ref_cols.ordinality = source_cols.ordinality
      JOIN pg_attribute source_attr
        ON source_attr.attrelid = src.oid
       AND source_attr.attnum = source_cols.attnum
      JOIN pg_attribute referenced_attr
        ON referenced_attr.attrelid = ref.oid
       AND referenced_attr.attnum = ref_cols.attnum
      WHERE con.contype = 'f'
        AND src.relname = $1
      ORDER BY con.conname, source_cols.ordinality
    `,
    [tableName]
  );

  const fkByName = new Map<string, SchemaStudioForeignKeyInput>();
  for (const row of fkRows) {
    const existing = fkByName.get(row.constraint_name);
    if (existing) {
      existing.columns.push(row.column_name);
      existing.referencedColumns.push(row.referenced_column_name);
      continue;
    }

    fkByName.set(row.constraint_name, {
      constraintName: row.constraint_name,
      columns: [row.column_name],
      referencedTable: row.referenced_table_name,
      referencedColumns: [row.referenced_column_name],
      onUpdateAction: row.on_update_action,
      onDeleteAction: row.on_delete_action,
    });
  }

  const indexRows = await queryRowsOrEmpty<{
    index_name: string;
    is_unique: boolean;
    position: number;
    column_name: string;
  }>(
    `
      SELECT
        idx_name.relname AS index_name,
        idx.indisunique AS is_unique,
        key_col.ordinality::integer AS position,
        a.attname AS column_name
      FROM pg_index idx
      JOIN pg_class tbl
        ON tbl.oid = idx.indrelid
      JOIN pg_namespace ns
        ON ns.oid = tbl.relnamespace
       AND ns.nspname = 'public'
      JOIN pg_class idx_name
        ON idx_name.oid = idx.indexrelid
      JOIN LATERAL unnest(idx.indkey) WITH ORDINALITY AS key_col(attnum, ordinality)
        ON key_col.attnum > 0
      JOIN pg_attribute a
        ON a.attrelid = tbl.oid
       AND a.attnum = key_col.attnum
      WHERE tbl.relname = $1
        AND idx.indisprimary = FALSE
        AND NOT EXISTS (
          SELECT 1
          FROM pg_constraint con
          WHERE con.conindid = idx.indexrelid
        )
      ORDER BY idx_name.relname, key_col.ordinality
    `,
    [tableName]
  );

  const indexByName = new Map<string, SchemaStudioIndexInput>();
  for (const row of indexRows) {
    const existing = indexByName.get(row.index_name);
    if (existing) {
      existing.columns.push(row.column_name);
      continue;
    }

    indexByName.set(row.index_name, {
      indexName: row.index_name,
      isUnique: row.is_unique,
      columns: [row.column_name],
    });
  }

  return {
    entityKey,
    tableName,
    dataTypes: dataTypeRows.map(row => row.data_type),
    referencedTables: referencedTableRows.map(row => row.table_name),
    columns: columns.map(column => ({
      originalColumnName: column.column_name,
      columnName: column.column_name,
      dataType: column.data_type,
      labelEs: column.label_es || column.column_name,
      labelEn: column.label_en || column.column_name,
      nullable: column.is_nullable === 'YES',
      primaryKey: pkPositionMap.has(column.column_name),
      primaryKeyPosition: pkPositionMap.get(column.column_name) || 0,
    })),
    foreignKeys: Array.from(fkByName.values()),
    indexes: Array.from(indexByName.values()),
  };
}

function parseSchemaStudioColumnInputs(payloadColumns: any[]): SchemaStudioColumnInput[] {
  return payloadColumns.map((column, index) => {
    const columnName = String(column?.columnName || '').trim();
    const dataType = String(column?.dataType || '').trim();
    const labelEs = String(column?.labelEs || columnName).trim();
    const labelEn = String(column?.labelEn || columnName).trim();
    const originalColumnName = column?.originalColumnName ? String(column.originalColumnName).trim() : '';
    const nullable = Boolean(column?.nullable);
    const primaryKey = Boolean(column?.primaryKey);
    const primaryKeyPositionCandidate = Number(column?.primaryKeyPosition || 0);
    const primaryKeyPosition = Number.isInteger(primaryKeyPositionCandidate) && primaryKeyPositionCandidate > 0
      ? primaryKeyPositionCandidate
      : 0;

    if (!columnName) {
      throw new Error(`Missing column name at index ${index}`);
    }

    return {
      originalColumnName,
      columnName,
      dataType,
      labelEs,
      labelEn,
      nullable,
      primaryKey,
      primaryKeyPosition,
    };
  });
}

function parseSchemaStudioForeignKeyInputs(payloadForeignKeys: any[]): SchemaStudioForeignKeyInput[] {
  return payloadForeignKeys
    .map((foreignKey, index) => {
      const constraintName = String(foreignKey?.constraintName || '').trim();
      const columns = Array.isArray(foreignKey?.columns)
        ? foreignKey.columns.map((entry: any) => String(entry || '').trim()).filter((entry: string) => entry.length > 0)
        : splitCsvColumns(String(foreignKey?.columnsCsv || ''));
      const referencedTable = String(foreignKey?.referencedTable || '').trim();
      const referencedColumns = Array.isArray(foreignKey?.referencedColumns)
        ? foreignKey.referencedColumns.map((entry: any) => String(entry || '').trim()).filter((entry: string) => entry.length > 0)
        : splitCsvColumns(String(foreignKey?.referencedColumnsCsv || ''));
      const onUpdateAction = normalizeConstraintAction(String(foreignKey?.onUpdateAction || DEFAULT_REFERENTIAL_ACTION));
      const onDeleteAction = normalizeConstraintAction(String(foreignKey?.onDeleteAction || DEFAULT_REFERENTIAL_ACTION));

      if (!referencedTable || columns.length === 0 || referencedColumns.length === 0) {
        throw new Error(`Invalid foreign key row at index ${index}`);
      }

      if (columns.length !== referencedColumns.length) {
        throw new Error(`Foreign key column count mismatch at index ${index}`);
      }

      return {
        constraintName,
        columns,
        referencedTable,
        referencedColumns,
        onUpdateAction,
        onDeleteAction,
      };
    })
    .filter(foreignKey => foreignKey.columns.length > 0);
}

function parseSchemaStudioIndexInputs(payloadIndexes: any[]): SchemaStudioIndexInput[] {
  return payloadIndexes
    .map((indexRow, index) => {
      const indexName = String(indexRow?.indexName || '').trim();
      const columns = Array.isArray(indexRow?.columns)
        ? indexRow.columns.map((entry: any) => String(entry || '').trim()).filter((entry: string) => entry.length > 0)
        : splitCsvColumns(String(indexRow?.columnsCsv || ''));
      const isUnique = Boolean(indexRow?.isUnique);

      if (!indexName || columns.length === 0) {
        throw new Error(`Invalid index row at index ${index}`);
      }

      return { indexName, columns, isUnique };
    })
    .filter(indexRow => indexRow.columns.length > 0);
}

async function applySchemaStudioEntityModel(entityKey: string, model: {
  columns: SchemaStudioColumnInput[];
  foreignKeys: SchemaStudioForeignKeyInput[];
  indexes: SchemaStudioIndexInput[];
}): Promise<void> {
  if (!schemaStudioPool) {
    throw new Error('Schema Studio credentials are not configured. Set SCHEMA_STUDIO_DB_USER and SCHEMA_STUDIO_DB_PASSWORD.');
  }

  const tableName = await resolveSchemaStudioEntityTableName(entityKey);
  if (!tableName) {
    throw new Error('Entity not found');
  }

  const columnNameSet = new Set(model.columns.map(column => column.columnName));
  if (columnNameSet.size !== model.columns.length) {
    throw new Error('Duplicate column names are not allowed');
  }

  const allowedDataTypes = await getAllowedSchemaStudioDataTypes();
  for (const column of model.columns) {
    if (!column.dataType || !allowedDataTypes.has(column.dataType.toLowerCase())) {
      throw new Error(`Unsupported data type for column ${column.columnName}: ${column.dataType}`);
    }
  }

  const primaryKeyColumns = model.columns
    .filter(column => column.primaryKey)
    .sort((left, right) => left.primaryKeyPosition - right.primaryKeyPosition || left.columnName.localeCompare(right.columnName))
    .map(column => column.columnName);

  if (primaryKeyColumns.length === 0) {
    throw new Error('At least one primary key column is required');
  }

  for (const foreignKey of model.foreignKeys) {
    ensureValidIdentifiers(foreignKey.columns, 'foreign key local columns');
    ensureValidIdentifiers(foreignKey.referencedColumns, 'foreign key referenced columns');
    if (!columnNameSet.has(foreignKey.columns[0])) {
      throw new Error(`Foreign key references unknown local column: ${foreignKey.columns[0]}`);
    }
    for (const localColumn of foreignKey.columns) {
      if (!columnNameSet.has(localColumn)) {
        throw new Error(`Foreign key references unknown local column: ${localColumn}`);
      }
    }
  }

  for (const indexRow of model.indexes) {
    ensureValidIdentifiers(indexRow.columns, 'index columns');
    for (const localColumn of indexRow.columns) {
      if (!columnNameSet.has(localColumn)) {
        throw new Error(`Index references unknown local column: ${localColumn}`);
      }
    }
  }

  ensureValidIdentifiers(model.columns.map(column => column.columnName), 'column names');
  ensureValidIdentifiers(
    model.columns.map(column => column.originalColumnName || '').filter(name => name.length > 0),
    'original column names'
  );
  ensureValidIdentifiers(model.foreignKeys.map(foreignKey => foreignKey.referencedTable), 'foreign key referenced tables');
  ensureValidIdentifiers(
    model.foreignKeys.map(foreignKey => foreignKey.constraintName || '').filter(name => name.length > 0),
    'foreign key constraint names'
  );
  ensureValidIdentifiers(model.indexes.map(indexRow => indexRow.indexName), 'index names');

  const client = await schemaStudioPool.connect();
  try {
    await client.query('BEGIN');

    const currentColumnsResult = await client.query<{ column_name: string }>(
      `
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = $1
        ORDER BY ordinal_position
      `,
      [tableName]
    );
    const currentColumnSet = new Set<string>(currentColumnsResult.rows.map((row: { column_name: string }) => row.column_name));

    const fkConstraintResult = await client.query<{ conname: string }>(
      `
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel
          ON rel.oid = con.conrelid
        JOIN pg_namespace ns
          ON ns.oid = rel.relnamespace
         AND ns.nspname = 'public'
        WHERE con.contype = 'f'
          AND rel.relname = $1
      `,
      [tableName]
    );
    for (const row of fkConstraintResult.rows) {
      await client.query(`ALTER TABLE ${quoteIdentifier(tableName)} DROP CONSTRAINT ${quoteIdentifier(row.conname)}`);
    }

    const currentPkColumnsResult = await client.query<{ column_name: string; position: number }>(
      `
        SELECT
          a.attname AS column_name,
          key_col.ordinality::integer AS position
        FROM pg_constraint con
        JOIN pg_class rel
          ON rel.oid = con.conrelid
        JOIN pg_namespace ns
          ON ns.oid = rel.relnamespace
         AND ns.nspname = 'public'
        JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS key_col(attnum, ordinality)
          ON TRUE
        JOIN pg_attribute a
          ON a.attrelid = rel.oid
         AND a.attnum = key_col.attnum
        WHERE con.contype = 'p'
          AND rel.relname = $1
        ORDER BY key_col.ordinality
      `,
      [tableName]
    );
    const currentPrimaryKeyColumns = currentPkColumnsResult.rows
      .sort((left, right) => left.position - right.position)
      .map(row => row.column_name);
    const primaryKeyChanged = currentPrimaryKeyColumns.length !== primaryKeyColumns.length
      || currentPrimaryKeyColumns.some((columnName, index) => columnName !== primaryKeyColumns[index]);

    const pkConstraintResult = await client.query<{ conname: string }>(
      `
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel
          ON rel.oid = con.conrelid
        JOIN pg_namespace ns
          ON ns.oid = rel.relnamespace
         AND ns.nspname = 'public'
        WHERE con.contype = 'p'
          AND rel.relname = $1
      `,
      [tableName]
    );
    if (primaryKeyChanged) {
      for (const row of pkConstraintResult.rows) {
        await client.query(`ALTER TABLE ${quoteIdentifier(tableName)} DROP CONSTRAINT ${quoteIdentifier(row.conname)}`);
      }
    }

    const indexRows = await client.query<{ index_name: string }>(
      `
        SELECT idx_name.relname AS index_name
        FROM pg_index idx
        JOIN pg_class tbl
          ON tbl.oid = idx.indrelid
        JOIN pg_namespace ns
          ON ns.oid = tbl.relnamespace
         AND ns.nspname = 'public'
        JOIN pg_class idx_name
          ON idx_name.oid = idx.indexrelid
        WHERE tbl.relname = $1
          AND idx.indisprimary = FALSE
          AND NOT EXISTS (
            SELECT 1
            FROM pg_constraint con
            WHERE con.conindid = idx.indexrelid
          )
      `,
      [tableName]
    );
    for (const row of indexRows.rows) {
      await client.query(`DROP INDEX ${quoteIdentifier(row.index_name)}`);
    }

    for (const column of model.columns) {
      if (!column.originalColumnName || column.originalColumnName === column.columnName) {
        continue;
      }

      if (currentColumnSet.has(column.originalColumnName)) {
        await client.query(
          `ALTER TABLE ${quoteIdentifier(tableName)} RENAME COLUMN ${quoteIdentifier(column.originalColumnName)} TO ${quoteIdentifier(column.columnName)}`
        );
        currentColumnSet.delete(column.originalColumnName);
        currentColumnSet.add(column.columnName);
      }
    }

    for (const column of model.columns) {
      if (currentColumnSet.has(column.columnName)) {
        continue;
      }

      await client.query(
        `ALTER TABLE ${quoteIdentifier(tableName)} ADD COLUMN ${quoteIdentifier(column.columnName)} ${column.dataType}`
      );
      currentColumnSet.add(column.columnName);
    }

    for (const column of model.columns) {
      await client.query(
        `ALTER TABLE ${quoteIdentifier(tableName)} ALTER COLUMN ${quoteIdentifier(column.columnName)} TYPE ${column.dataType}`
      );
      await client.query(
        `ALTER TABLE ${quoteIdentifier(tableName)} ALTER COLUMN ${quoteIdentifier(column.columnName)} ${column.nullable ? 'DROP NOT NULL' : 'SET NOT NULL'}`
      );
    }

    for (const currentColumnName of Array.from(currentColumnSet.values()) as string[]) {
      if (columnNameSet.has(currentColumnName)) {
        continue;
      }

      await client.query(
        `ALTER TABLE ${quoteIdentifier(tableName)} DROP COLUMN ${quoteIdentifier(currentColumnName)}`
      );
    }

    if (primaryKeyChanged) {
      const pkConstraintName = `pk_${tableName}`;
      await client.query(
        `ALTER TABLE ${quoteIdentifier(tableName)} ADD CONSTRAINT ${quoteIdentifier(pkConstraintName)} PRIMARY KEY (${primaryKeyColumns.map(column => quoteIdentifier(column)).join(', ')})`
      );
    }

    for (let index = 0; index < model.foreignKeys.length; index += 1) {
      const foreignKey = model.foreignKeys[index];
      const constraintName = foreignKey.constraintName && foreignKey.constraintName.length > 0
        ? foreignKey.constraintName
        : `fk_${tableName}_${index + 1}`;

      await client.query(
        `ALTER TABLE ${quoteIdentifier(tableName)} ADD CONSTRAINT ${quoteIdentifier(constraintName)} FOREIGN KEY (${foreignKey.columns.map(column => quoteIdentifier(column)).join(', ')}) REFERENCES ${quoteIdentifier(foreignKey.referencedTable)} (${foreignKey.referencedColumns.map(column => quoteIdentifier(column)).join(', ')}) ON UPDATE ${foreignKey.onUpdateAction} ON DELETE ${foreignKey.onDeleteAction}`
      );
    }

    for (const indexRow of model.indexes) {
      await client.query(
        `CREATE ${indexRow.isUnique ? 'UNIQUE ' : ''}INDEX ${quoteIdentifier(indexRow.indexName)} ON ${quoteIdentifier(tableName)} (${indexRow.columns.map(column => quoteIdentifier(column)).join(', ')})`
      );
    }

    for (const column of model.columns) {
      await client.query(
        `
          INSERT INTO app_entity_columns (entity_key, column_name, data_type, label_es, label_en)
          VALUES ($1, $2, $3, $4, $5)
          ON CONFLICT (entity_key, column_name)
          DO UPDATE SET
            data_type = EXCLUDED.data_type,
            label_es = EXCLUDED.label_es,
            label_en = EXCLUDED.label_en
        `,
        [entityKey, column.columnName, column.dataType, column.labelEs || column.columnName, column.labelEn || column.columnName]
      );
    }

    const metadataColumnsResult = await client.query<{ column_name: string }>(
      `
        SELECT column_name
        FROM app_entity_columns
        WHERE entity_key = $1
      `,
      [entityKey]
    );

    for (const row of metadataColumnsResult.rows) {
      if (columnNameSet.has(row.column_name)) {
        continue;
      }

      await client.query(
        `DELETE FROM app_entity_columns WHERE entity_key = $1 AND column_name = $2`,
        [entityKey, row.column_name]
      );
    }

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

function parsePrimaryKeyToken(primaryKeyToken: string, expectedCount: number): string[] | null {
  try {
    const decoded = decodeURIComponent(primaryKeyToken);
    const values = JSON.parse(decoded);

    if (!Array.isArray(values) || values.length !== expectedCount || values.some(value => typeof value !== 'string')) {
      return null;
    }

    return values;
  } catch {
    return null;
  }
}

function buildPrimaryKeyWhereClause(primaryKeyColumns: string[], startIndex = 1): string {
  return primaryKeyColumns
    .map((column, index) => `${quoteIdentifier(column)} = $${startIndex + index}`)
    .join(' AND ');
}

function handleDatabaseError(error: any, res: express.Response) {
  if (error?.code === '23505') {
    return res.status(409).json({ error: 'Unique constraint violation' });
  }

  if (error?.code === '23503') {
    return res.status(409).json({ error: 'Foreign key constraint violation' });
  }

  if (error?.code === '23502') {
    return res.status(400).json({ error: 'Not-null constraint violation' });
  }

  return res.status(500).json({ error: 'Internal server error' });
}

function isTableNotFoundError(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: string }).code === '42P01';
}

function isInsufficientPrivilegeError(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: string }).code === '42501';
}

function logAndSendErrorResponse(action: string, entityName: string, error: unknown, res: express.Response) {
  console.error(`Error ${action} ${entityName}:`, error);
  handleDatabaseError(error, res);
}

function rowsToMap<Row extends Record<string, any>, Value>(
  rows: Row[],
  getKey: (row: Row) => string,
  getValue: (row: Row) => Value
): Map<string, Value> {
  const result = new Map<string, Value>();
  for (const row of rows) {
    result.set(getKey(row), getValue(row));
  }
  return result;
}

function rowsToGroupedMap<Row extends Record<string, any>, Value>(
  rows: Row[],
  getKey: (row: Row) => string,
  getValue: (row: Row) => Value
): Map<string, Value[]> {
  const result = new Map<string, Value[]>();
  for (const row of rows) {
    const key = getKey(row);
    const entries = result.get(key) || [];
    entries.push(getValue(row));
    result.set(key, entries);
  }
  return result;
}

async function queryRowsOrEmpty<Row extends Record<string, any>>(
  queryText: string,
  params: any[] = []
): Promise<Row[]> {
  try {
    const result = await pool.query<Row>(queryText, params);
    return result.rows;
  } catch (error) {
    if (isTableNotFoundError(error)) {
      return [];
    }
    throw error;
  }
}

async function selectOrderedRowsOrEmpty<Row extends Record<string, any>>(
  tableName: string,
  columns: string[],
  orderByColumns: string[]
): Promise<Row[]> {
  const selectColumns = columns.map(quoteIdentifier).join(', ');
  const orderBy = orderByColumns.map(quoteIdentifier).join(', ');

  return queryRowsOrEmpty<Row>(`
    SELECT ${selectColumns}
    FROM ${quoteIdentifier(tableName)}
    ORDER BY ${orderBy}
  `);
}

async function selectOrderedMapOrEmpty<Row extends Record<string, any>, Value>(
  tableName: string,
  columns: string[],
  orderByColumns: string[],
  getKey: (row: Row) => string,
  getValue: (row: Row) => Value
): Promise<Map<string, Value>> {
  const rows = await selectOrderedRowsOrEmpty<Row>(tableName, columns, orderByColumns);
  return rowsToMap(rows, getKey, getValue);
}

async function selectOrderedGroupedMapOrEmpty<Row extends Record<string, any>, Value>(
  tableName: string,
  columns: string[],
  orderByColumns: string[],
  getKey: (row: Row) => string,
  getValue: (row: Row) => Value
): Promise<Map<string, Value[]>> {
  const rows = await selectOrderedRowsOrEmpty<Row>(tableName, columns, orderByColumns);
  return rowsToGroupedMap(rows, getKey, getValue);
}

async function getRelationColumns(relationName: string): Promise<ColumnInfo[]> {
  const result = await pool.query<{ column_name: string; data_type: string; is_nullable: string }>(
    `
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = $1
      ORDER BY ordinal_position
    `,
    [relationName]
  );

  return result.rows.map((row: { column_name: string; data_type: string; is_nullable: string }) => ({
    columnName: row.column_name,
    dataType: row.data_type,
    isNullable: row.is_nullable === 'YES',
  }));
}

const relationColumnsCache = new Map<string, ColumnInfo[]>();

async function getCachedRelationColumns(relationName: string): Promise<ColumnInfo[]> {
  const cachedColumns = relationColumnsCache.get(relationName);
  if (cachedColumns) {
    return cachedColumns;
  }

  const columns = await getRelationColumns(relationName);
  relationColumnsCache.set(relationName, columns);
  return columns;
}

async function getRelationColumnNameSet(relationName: string): Promise<Set<string>> {
  const columns = await getRelationColumns(relationName);
  return new Set(columns.map(column => column.columnName));
}

async function getEntityRegistryMap(): Promise<Map<string, EntityRegistryRecord>> {
  return selectOrderedMapOrEmpty<{
    entity_key: string;
    table_name: string;
    singular_es: string;
    singular_en: string;
    plural_es: string;
    plural_en: string;
  }, EntityRegistryRecord>(
    'app_entities',
    ['entity_key', 'table_name', 'singular_es', 'singular_en', 'plural_es', 'plural_en'],
    ['entity_key'],
    row => row.entity_key,
    row => ({
      entityKey: row.entity_key,
      tableName: row.table_name,
      singular: { es: row.singular_es, en: row.singular_en },
      plural: { es: row.plural_es, en: row.plural_en },
    })
  );
}

async function getEntityHiddenColumnMap(): Promise<Map<string, EntityHiddenColumnRecord[]>> {
  return selectOrderedGroupedMapOrEmpty<{
    entity_key: string;
    column_name: string;
  }, EntityHiddenColumnRecord>(
    'app_entity_hidden_columns',
    ['entity_key', 'column_name'],
    ['entity_key', 'column_name'],
    row => row.entity_key,
    row => ({
      entityKey: row.entity_key,
      columnName: row.column_name,
    })
  );
}

async function getShownReferencedEntityColumnMap(): Promise<Map<string, ShownReferencedEntityColumnRecord[]>> {
  return selectOrderedGroupedMapOrEmpty<{
    entity_key: string;
    referenced_entity_key: string;
    displayed_entity_column: string;
  }, ShownReferencedEntityColumnRecord>(
    'app_shown_referenced_entity_columns',
    ['entity_key', 'referenced_entity_key', 'displayed_entity_column'],
    ['entity_key', 'referenced_entity_key', 'displayed_entity_column'],
    row => row.entity_key,
    row => ({
      entityKey: row.entity_key,
      referencedEntityKey: row.referenced_entity_key,
      displayedEntityColumn: row.displayed_entity_column,
    })
  );
}

async function getEntityColumnMetaMap(): Promise<Map<string, EntityColumnMetaRecord[]>> {
  return selectOrderedGroupedMapOrEmpty<{
    entity_key: string;
    column_name: string;
    label_es: string | null;
    label_en: string | null;
  }, EntityColumnMetaRecord>(
    'app_entity_columns',
    ['entity_key', 'column_name', 'label_es', 'label_en'],
    ['entity_key', 'column_name'],
    row => row.entity_key,
    row => ({
      entityKey: row.entity_key,
      columnName: row.column_name,
      label: {
        es: row.label_es || row.column_name,
        en: row.label_en || row.column_name,
      },
    })
  );
}

async function getEntityPrimaryKeyMap(): Promise<Map<string, EntityPrimaryKeyRecord[]>> {
  return selectOrderedGroupedMapOrEmpty<{
    entity_key: string;
    position: number;
    column_name: string;
  }, EntityPrimaryKeyRecord>(
    'app_entity_primary_keys',
    ['entity_key', 'position', 'column_name'],
    ['entity_key', 'position'],
    row => row.entity_key,
    row => ({
      entityKey: row.entity_key,
      position: row.position,
      columnName: row.column_name,
    })
  );
}

async function getDataTypeUIProfileMap(): Promise<Map<string, DataTypeUIProfileRecord>> {
  return selectOrderedMapOrEmpty<{
    data_type: string;
    control: string | null;
    input_type: string | null;
    parser: string | null;
    step: string | null;
  }, DataTypeUIProfileRecord>(
    'app_data_type_ui_profiles',
    ['data_type', 'control', 'input_type', 'parser', 'step'],
    ['data_type'],
    row => row.data_type,
    row => ({
      dataType: row.data_type,
      ...(row.control ? { control: row.control } : {}),
      ...(row.input_type ? { inputType: row.input_type } : {}),
      ...(row.parser ? { parser: row.parser } : {}),
      ...(row.step ? { step: row.step } : {}),
    })
  );
}

async function getEntityForeignKeyMap(): Promise<Map<string, EntityForeignKeyRecord[]>> {
  const rows = await queryRowsOrEmpty<{
    entity_key: string;
    foreign_key_key: string;
    position: number;
    column_name: string;
    referenced_entity_key: string;
    referenced_column_name: string;
    on_update_action: string;
    on_delete_action: string;
  }>(
    `
      SELECT
        fk.entity_key,
        fk.foreign_key_key,
        fk.position,
        fk.column_name,
        fk.referenced_entity_key,
        fk.referenced_column_name,
        fkg.on_update_action,
        fkg.on_delete_action
      FROM app_entity_foreign_keys fk
      JOIN app_entity_foreign_key_groups fkg
        ON fkg.entity_key = fk.entity_key
       AND fkg.foreign_key_key = fk.foreign_key_key
      ORDER BY fk.entity_key, fk.foreign_key_key, fk.position
    `
  );

    const byEntity = new Map<string, Map<string, EntityForeignKeyRecord>>();

    for (const row of rows) {
      const entityMap = byEntity.get(row.entity_key) || new Map<string, EntityForeignKeyRecord>();
      byEntity.set(row.entity_key, entityMap);

      const existing = entityMap.get(row.foreign_key_key);
      if (existing) {
        existing.columns.push({
          position: row.position,
          columnName: row.column_name,
          referencedColumnName: row.referenced_column_name,
        });
        continue;
      }

      entityMap.set(row.foreign_key_key, {
        entityKey: row.entity_key,
        foreignKeyKey: row.foreign_key_key,
        referencedEntityKey: row.referenced_entity_key,
        onUpdateAction: row.on_update_action,
        onDeleteAction: row.on_delete_action,
        columns: [{
          position: row.position,
          columnName: row.column_name,
          referencedColumnName: row.referenced_column_name,
        }],
      });
    }

    const grouped = new Map<string, EntityForeignKeyRecord[]>();
    for (const [entityKey, foreignKeys] of byEntity.entries()) {
      grouped.set(
        entityKey,
        Array.from(foreignKeys.values())
          .map(foreignKey => ({
            ...foreignKey,
            columns: foreignKey.columns.slice().sort((left, right) => left.position - right.position),
          }))
          .sort((left, right) => left.foreignKeyKey.localeCompare(right.foreignKeyKey))
      );
    }

    return grouped;
}

async function getDynamicOptionSets(
  optionSetDefinitionMap: Map<string, OptionSetDefinitionRecord>
): Promise<Record<string, OptionItem[]>> {
  const optionSets: Record<string, OptionItem[]> = {};

  if (optionSetDefinitionMap.size === 0) {
    throw new Error('Missing option set definitions in app_option_set_definitions');
  }

  const definitions = Array.from(optionSetDefinitionMap.values())
    .sort((left, right) => left.optionSetKey.localeCompare(right.optionSetKey));

  for (const definition of definitions) {
    const result = await pool.query<{ value: string; label_es: string; label_en: string }>(
      `SELECT value, label_es, label_en FROM api_option_set_items($1)`,
      [definition.optionSetKey]
    );

    optionSets[definition.optionSetKey] = result.rows.map((row: { value: string; label_es: string; label_en: string }) => ({
      value: row.value,
      label: { es: row.label_es, en: row.label_en },
    }));
  }

  return optionSets;
}

function buildForeignKeyOptionSetKey(entityName: string, columnName: string): string {
  return `fk_${entityName}_${columnName}`;
}

async function getForeignKeyAutoOptionSets(
  entityRegistryMap: Map<string, EntityRegistryRecord>
): Promise<{
  optionSets: Record<string, OptionItem[]>;
  byField: Map<string, string>;
  rowsByField: Map<string, ForeignKeyOptionRow[]>;
}> {
  const optionSets: Record<string, OptionItem[]> = {};
  const byField = new Map<string, string>();
  const rowsByField = new Map<string, ForeignKeyOptionRow[]>();
  const runtimeConfigCache = new Map<string, RuntimeEntityConfig | null>();
  const relationColumnNameSetCache = new Map<string, Set<string>>();

  const getRuntimeConfig = async (entityName: string): Promise<RuntimeEntityConfig | null> => {
    if (runtimeConfigCache.has(entityName)) {
      return runtimeConfigCache.get(entityName) || null;
    }

    const runtimeConfig = await resolveRuntimeEntityConfig(entityName, entityRegistryMap);
    runtimeConfigCache.set(entityName, runtimeConfig);
    return runtimeConfig;
  };

  for (const entityName of Array.from(entityRegistryMap.keys())) {
    const runtimeConfig = await getRuntimeConfig(entityName);
    if (!runtimeConfig) {
      continue;
    }

    for (const foreignKey of runtimeConfig.foreignKeys) {
      const referencedRuntimeConfig = await getRuntimeConfig(foreignKey.referencedEntityKey);
      if (!referencedRuntimeConfig) {
        continue;
      }

      const referencedTable = referencedRuntimeConfig.tableName;
      let columnNameSet = relationColumnNameSetCache.get(referencedTable);
      if (!columnNameSet) {
        columnNameSet = await getRelationColumnNameSet(referencedTable);
        relationColumnNameSetCache.set(referencedTable, columnNameSet);
      }
      const hasLabelEs = columnNameSet.has('label_es');
      const hasLabelEn = columnNameSet.has('label_en');

      const referencedColumns = Array.from(new Set(foreignKey.columns
        .slice()
        .sort((left, right) => left.position - right.position)
        .map(column => column.referencedColumnName)));
      const referencedValueJsonArgs = referencedColumns
        .flatMap(column => [`'${column.replace(/'/g, "''")}'`, `${quoteIdentifier(column)}::text`])
        .join(', ');
      const referencedSelect = referencedColumns
        .map(column => `${quoteIdentifier(column)} AS ${quoteIdentifier(`ref__${column}`)}`)
        .join(', ');
      const orderBy = referencedColumns
        .map(column => `${quoteIdentifier(column)} ASC`)
        .join(', ');

      const query = hasLabelEs || hasLabelEn
        ? `
          SELECT DISTINCT
            ${referencedSelect},
            ${hasLabelEs ? "COALESCE(label_es::text, '')" : "''"} AS label_es,
            ${hasLabelEn ? "COALESCE(label_en::text, '')" : "''"} AS label_en,
            jsonb_build_object(${referencedValueJsonArgs}) AS referenced_values
          FROM ${quoteIdentifier(referencedTable)}
          ORDER BY ${orderBy}
        `
        : `
          SELECT DISTINCT
            ${referencedSelect},
            '' AS label_es,
            '' AS label_en,
            jsonb_build_object(${referencedValueJsonArgs}) AS referenced_values
          FROM ${quoteIdentifier(referencedTable)}
          ORDER BY ${orderBy}
        `;

      const result = await pool.query<Record<string, unknown>>(query);

      for (const columnMapping of foreignKey.columns) {
        const fieldMapKey = `${entityName}.${columnMapping.columnName}`;
        const valueColumnAlias = `ref__${columnMapping.referencedColumnName}`;

        const optionSetKey = buildForeignKeyOptionSetKey(entityName, columnMapping.columnName);
        const optionRows: ForeignKeyOptionRow[] = result.rows
          .map((row: Record<string, unknown>) => {
            const rawValue = row[valueColumnAlias];
            if (rawValue === null || rawValue === undefined) {
              return null;
            }

            const labelEs = typeof row.label_es === 'string' && row.label_es.length > 0
              ? row.label_es
              : String(rawValue);
            const labelEn = typeof row.label_en === 'string' && row.label_en.length > 0
              ? row.label_en
              : String(rawValue);

            return {
              value: String(rawValue),
              label: { es: labelEs, en: labelEn },
              referencedValues: Object.fromEntries(
                Object.entries((row.referenced_values as Record<string, unknown>) || {}).map(([key, value]) => [key, String(value)])
              ),
            };
          })
          .filter((row: ForeignKeyOptionRow | null): row is ForeignKeyOptionRow => row !== null);
        const options = optionRows.map(row => ({
          value: row.value,
          label: row.label,
        }));

        optionSets[optionSetKey] = options;
        rowsByField.set(fieldMapKey, optionRows);
        byField.set(fieldMapKey, optionSetKey);
      }
    }
  }

  return { optionSets, byField, rowsByField };
}

function getInputTypeAndParser(
  dataType: string,
  dataTypeUiProfileMap: Map<string, DataTypeUIProfileRecord>
): { inputType?: string; parser?: string; control?: string; step?: string } {
  const profile = dataTypeUiProfileMap.get(dataType);
  if (!profile) {
    return {};
  }

  return {
    ...(profile.control ? { control: profile.control } : {}),
    ...(profile.inputType ? { inputType: profile.inputType } : {}),
    ...(profile.parser ? { parser: profile.parser } : {}),
    ...(profile.step ? { step: profile.step } : {}),
  };
}

async function resolveRuntimeEntityConfig(
  entityName: string,
  registryMap?: Map<string, EntityRegistryRecord>,
  primaryKeyMap?: Map<string, EntityPrimaryKeyRecord[]>,
  foreignKeyMap?: Map<string, EntityForeignKeyRecord[]>
): Promise<RuntimeEntityConfig | null> {
  const effectiveRegistryMap = registryMap || (await getEntityRegistryMap());
  const registry = effectiveRegistryMap.get(entityName);

  if (!registry) {
    return null;
  }

  const effectivePrimaryKeyMap = primaryKeyMap || (await getEntityPrimaryKeyMap());
  const effectiveForeignKeyMap = foreignKeyMap || (await getEntityForeignKeyMap());

  const primaryKeyEntries = (effectivePrimaryKeyMap.get(entityName) || []).slice();
  const primaryKeyColumns = primaryKeyEntries.map(row => row.columnName);

  if (primaryKeyColumns.length === 0) {
    // Entities without PK metadata are not manageable by generic CRUD endpoints.
    // Skip them instead of failing the entire metadata build.
    return null;
  }

  const writeColumnInfo = await getCachedRelationColumns(registry.tableName);

  const foreignKeys = (effectiveForeignKeyMap.get(entityName) || [])
    .slice()
    .sort((left, right) => left.foreignKeyKey.localeCompare(right.foreignKeyKey));

  return {
    entityName,
    tableName: registry.tableName,
    primaryKeyColumns,
    writeColumns: writeColumnInfo.map(column => column.columnName),
    listColumns: writeColumnInfo.map(column => column.columnName),
    foreignKeys,
  };
}

function resolveFieldLabel(entityName: string, fieldKey: string, columnMetaMap: Map<string, EntityColumnMetaRecord[]>): LocaleText {
  const metadata = (columnMetaMap.get(entityName) || []).find(entry => entry.columnName === fieldKey);
  return metadata?.label || { es: fieldKey, en: fieldKey };
}

function buildFieldSpec(params: {
  fieldKey: string;
  columnInfo?: ColumnInfo;
  dataTypeUiProfileMap: Map<string, DataTypeUIProfileRecord>;
  primaryKeyColumns: string[];
  showInForm?: boolean;
  optionSetKey?: string;
  pattern?: string;
}): Record<string, any> {
  if (!params.columnInfo) {
    return {
      ...(params.optionSetKey ? { optionsKey: params.optionSetKey } : {}),
      ...(params.pattern ? { pattern: params.pattern } : {}),
      ...(params.showInForm !== undefined ? { showInForm: params.showInForm } : {}),
    };
  }

  const typeInfo = getInputTypeAndParser(params.columnInfo.dataType, params.dataTypeUiProfileMap);
  return {
    ...(params.primaryKeyColumns.includes(params.fieldKey) ? { required: true } : {}),
    ...(!params.columnInfo.isNullable ? { required: true } : {}),
    ...(typeInfo.control ? { control: typeInfo.control } : {}),
    ...(typeInfo.inputType ? { inputType: typeInfo.inputType } : {}),
    ...(typeInfo.parser ? { parser: typeInfo.parser } : {}),
    ...(typeInfo.step ? { step: typeInfo.step } : {}),
    ...(params.optionSetKey ? { optionsKey: params.optionSetKey } : {}),
    ...(params.pattern ? { pattern: params.pattern } : {}),
    ...(params.showInForm !== undefined ? { showInForm: params.showInForm } : {}),
  };
}

function buildEntityColumnRegexPatternMap(bundle: FrontendMetadataBundle): Map<string, string> {
  const rulesByKey = rowsToMap(
    bundle.app_validation_rules,
    row => String(row.validation_key),
    row => String(row.regex_pattern)
  );

  return rowsToMap(
    bundle.app_entity_column_validations,
    row => `${String(row.entity_key)}.${String(row.column_name)}`,
    row => rulesByKey.get(String(row.validation_key)) || ''
  );
}

async function getEntityColumnRegexPatternMap(entityName: string): Promise<Map<string, string>> {
  const rows = await queryRowsOrEmpty<{
    column_name: string;
    regex_pattern: string;
  }>(
    `
      SELECT ecv.column_name, vr.regex_pattern
      FROM app_entity_column_validations ecv
      JOIN app_validation_rules vr
        ON vr.validation_key = ecv.validation_key
      WHERE ecv.entity_key = $1
      ORDER BY ecv.column_name
    `,
    [entityName]
  );

  return rowsToMap(
    rows,
    row => row.column_name,
    row => row.regex_pattern
  );
}

async function validateEntityRegexRules(entityName: string, payload: Record<string, any>, columns: string[]): Promise<string[]> {
  const patternMap = await getEntityColumnRegexPatternMap(entityName);
  if (patternMap.size === 0) {
    return [];
  }

  const errors: string[] = [];
  for (const columnName of columns) {
    const pattern = patternMap.get(columnName);
    if (!pattern) {
      continue;
    }

    const rawValue = payload[columnName];
    if (rawValue === null || rawValue === undefined || rawValue === '') {
      continue;
    }

    let regex: RegExp;
    try {
      regex = new RegExp(pattern);
    } catch {
      throw new Error(`Invalid regex pattern configured for ${entityName}.${columnName}`);
    }
    if (!regex.test(String(rawValue))) {
      errors.push(`${columnName} does not match regex validation rule`);
    }
  }

  return errors;
}

function buildListProjectionPlan(
  runtimeConfig: RuntimeEntityConfig,
  entityRegistryMap: Map<string, EntityRegistryRecord>,
  columnMetaMap: Map<string, EntityColumnMetaRecord[]>,
  hiddenColumnMap: Map<string, EntityHiddenColumnRecord[]>,
  shownReferencedColumnMap: Map<string, ShownReferencedEntityColumnRecord[]>
): {
  query: string;
  projectedFields: Array<{ key: string; label: LocaleText; isProjection: boolean }>;
  selectClause: string;
  baseAlias: string;
  fromClause: string;
  defaultOrderBy: string;
  filterableColumns: string[];
} {
  const baseAlias = 'base';
  const hiddenColumns = new Set((hiddenColumnMap.get(runtimeConfig.entityName) || []).map(row => row.columnName));
  const localColumns = runtimeConfig.listColumns.filter(columnName => !hiddenColumns.has(columnName));

  const selectFragments: string[] = localColumns.map(columnName => `${baseAlias}.${quoteIdentifier(columnName)} AS ${quoteIdentifier(columnName)}`);
  const projectedFields: Array<{ key: string; label: LocaleText; isProjection: boolean }> = localColumns.map(columnName => ({
    key: columnName,
    label: resolveFieldLabel(runtimeConfig.entityName, columnName, columnMetaMap),
    isProjection: false,
  }));

  const joins: string[] = [];
  let aliasIndex = 0;
  const shownByReferencedEntity = (shownReferencedColumnMap.get(runtimeConfig.entityName) || []).reduce((acc, row) => {
    const current = acc.get(row.referencedEntityKey) || [];
    current.push(row.displayedEntityColumn);
    acc.set(row.referencedEntityKey, current);
    return acc;
  }, new Map<string, string[]>());

  for (const foreignKey of runtimeConfig.foreignKeys) {
    const shownReferencedColumns = Array.from(new Set(shownByReferencedEntity.get(foreignKey.referencedEntityKey) || []));
    if (shownReferencedColumns.length === 0) continue;

    const referencedRegistry = entityRegistryMap.get(foreignKey.referencedEntityKey);
    if (!referencedRegistry) {
      continue;
    }

    const joinAlias = `fk_${aliasIndex++}`;
    const joinConditions = foreignKey.columns
      .slice()
      .sort((left, right) => left.position - right.position)
      .map(column => `${baseAlias}.${quoteIdentifier(column.columnName)} = ${joinAlias}.${quoteIdentifier(column.referencedColumnName)}`)
      .join(' AND ');

    joins.push(
      `LEFT JOIN ${quoteIdentifier(referencedRegistry.tableName)} ${joinAlias} ON ${joinConditions}`
    );

    for (const displayColumn of shownReferencedColumns) {
      const projectionKey = `${foreignKey.foreignKeyKey}__${displayColumn}`;
      selectFragments.push(`${joinAlias}.${quoteIdentifier(displayColumn)} AS ${quoteIdentifier(projectionKey)}`);
      const displayLabel = resolveFieldLabel(foreignKey.referencedEntityKey, displayColumn, columnMetaMap);
      projectedFields.push({
        key: projectionKey,
        label: {
          es: `${foreignKey.referencedEntityKey} / ${displayLabel.es}`,
          en: `${foreignKey.referencedEntityKey} / ${displayLabel.en}`,
        },
        isProjection: true,
      });
    }
  }

  const fallbackOrderBy = runtimeConfig.primaryKeyColumns
    .map(columnName => `${baseAlias}.${quoteIdentifier(columnName)} ASC`)
    .join(', ');
  const selectClause = `SELECT ${selectFragments.join(', ')}`;
  const fromClause = `FROM ${quoteIdentifier(runtimeConfig.tableName)} ${baseAlias}${joins.length > 0 ? ` ${joins.join(' ')}` : ''}`;
  const query = `${selectClause} ${fromClause} ORDER BY ${fallbackOrderBy}`;

  return {
    query,
    projectedFields,
    selectClause,
    baseAlias,
    fromClause,
    defaultOrderBy: fallbackOrderBy,
    filterableColumns: localColumns,
  };
}

function getListDataTypeKind(dataType: string): ListDataTypeKind {
  const normalized = dataType.toLowerCase();
  if (normalized === 'boolean') return 'boolean';
  if (normalized === 'date' || normalized.includes('timestamp')) return 'date';
  if (
    normalized === 'smallint'
    || normalized === 'integer'
    || normalized === 'bigint'
    || normalized === 'numeric'
    || normalized === 'real'
    || normalized === 'double precision'
    || normalized === 'decimal'
  ) {
    return 'number';
  }
  return 'string';
}

function parseListQueryOptions(req: express.Request): ListQueryOptions {
  const getQueryString = (key: string): string | undefined => {
    const value = req.query[key];
    return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
  };

  const parsePositiveInt = (value: string | undefined, defaultValue: number, key: string): number => {
    if (!value) {
      return defaultValue;
    }

    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed <= 0) {
      throw new Error(`Invalid ${key} parameter`);
    }

    return parsed;
  };

  const sortDirectionRaw = getQueryString('sortDir');
  const normalizedSortDirection: 'ASC' | 'DESC' = sortDirectionRaw?.toUpperCase() === 'DESC' ? 'DESC' : 'ASC';
  const page = parsePositiveInt(getQueryString('page'), 1, 'page');
  const pageSize = Math.min(parsePositiveInt(getQueryString('pageSize'), 25, 'pageSize'), 200);
  const includeMetaRaw = getQueryString('includeMeta');
  const includeMeta = includeMetaRaw === '1' || includeMetaRaw?.toLowerCase() === 'true';
  const filterLogicRaw = getQueryString('filterLogic') || getQueryString('filterWithinGroupLogic');
  const filterLogic: 'AND' | 'OR' = filterLogicRaw?.toUpperCase() === 'OR' ? 'OR' : 'AND';
  const groupLogicRaw = getQueryString('groupLogic') || getQueryString('filterBetweenGroupsLogic');
  const groupLogic: 'AND' | 'OR' = groupLogicRaw?.toUpperCase() === 'OR' ? 'OR' : 'AND';

  const parseJsonArray = (value: string | undefined, key: string): any[] => {
    if (!value) {
      return [];
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(value);
    } catch {
      throw new Error(`Invalid ${key} parameter`);
    }

    if (!Array.isArray(parsed)) {
      throw new Error(`Invalid ${key} parameter`);
    }

    return parsed;
  };

  const rawFilters = parseJsonArray(getQueryString('filters'), 'filters');
  const rawSorts = parseJsonArray(getQueryString('sorts'), 'sorts');

  const parsedFilters = rawFilters.map((entry, index) => {
    if (!entry || typeof entry !== 'object') {
      throw new Error(`Invalid filters[${index}]`);
    }

    const field = String((entry as any).field || '').trim();
    const operator = String((entry as any).operator || '').trim();
    const value = String((entry as any).value ?? '').trim();
    const groupCandidate = Number((entry as any).group ?? 1);
    const group = Number.isInteger(groupCandidate) && groupCandidate > 0 ? groupCandidate : 1;
    if (!field || !operator || value.length === 0) {
      throw new Error(`Incomplete filters[${index}]`);
    }

    return { field, operator, value, group } as ListFilterCondition;
  });

  const parsedSorts = rawSorts.map((entry, index) => {
    if (!entry || typeof entry !== 'object') {
      throw new Error(`Invalid sorts[${index}]`);
    }

    const field = String((entry as any).field || '').trim();
    const direction: 'ASC' | 'DESC' = String((entry as any).direction || '').toUpperCase() === 'DESC' ? 'DESC' : 'ASC';
    if (!field) {
      throw new Error(`Incomplete sorts[${index}]`);
    }

    return { field, direction } as ListSortCondition;
  });

  const legacyFilterField = getQueryString('filterField');
  const legacyFilterOperator = getQueryString('filterOp');
  const legacyFilterValue = getQueryString('filterValue');
  const legacySortField = getQueryString('sortField');

  const filters = parsedFilters.length > 0
    ? parsedFilters
    : (legacyFilterField && legacyFilterOperator && legacyFilterValue
      ? [{ field: legacyFilterField, operator: legacyFilterOperator, value: legacyFilterValue, group: 1 }]
      : []);

  const sorts = parsedSorts.length > 0
    ? parsedSorts
    : (legacySortField
      ? [{ field: legacySortField, direction: normalizedSortDirection }]
      : []);

  return {
    filters,
    filterLogic,
    groupLogic,
    sorts,
    page,
    pageSize,
    includeMeta,
  };
}

function buildTypedFilterClause(
  filters: ListFilterCondition[],
  filterLogic: 'AND' | 'OR',
  groupLogic: 'AND' | 'OR',
  baseAlias: string,
  columnInfoByName: Map<string, ColumnInfo>,
  allowedColumns: Set<string>,
  startParameterIndex: number
): { clause: string; values: any[] } | null {
  if (filters.length === 0) {
    return null;
  }

  const clausesByGroup = new Map<number, string[]>();
  const values: any[] = [];

  for (let filterIndex = 0; filterIndex < filters.length; filterIndex += 1) {
    const filter = filters[filterIndex];
    if (!filter.field || !filter.operator) {
      throw new Error('Incomplete filter parameters');
    }

    if (!allowedColumns.has(filter.field)) {
      throw new Error('Filter field is not allowed');
    }

    const columnInfo = columnInfoByName.get(filter.field);
    if (!columnInfo) {
      throw new Error('Filter field metadata not found');
    }

    const rawValue = filter.value;
    if (rawValue === undefined) {
      throw new Error('Filter value is required');
    }

    const dataTypeKind = getListDataTypeKind(columnInfo.dataType);
    const columnExpr = `${baseAlias}.${quoteIdentifier(filter.field)}`;
    const valuePlaceholder = `$${startParameterIndex + values.length}`;

    if (dataTypeKind === 'string') {
      if (filter.operator === 'contains') {
        const groupClauses = clausesByGroup.get(filter.group) || [];
        groupClauses.push(`${columnExpr} ILIKE ${valuePlaceholder}`);
        clausesByGroup.set(filter.group, groupClauses);
        values.push(`%${rawValue}%`);
        continue;
      }
      if (filter.operator === 'startsWith') {
        const groupClauses = clausesByGroup.get(filter.group) || [];
        groupClauses.push(`${columnExpr} ILIKE ${valuePlaceholder}`);
        clausesByGroup.set(filter.group, groupClauses);
        values.push(`${rawValue}%`);
        continue;
      }
      if (filter.operator === 'endsWith') {
        const groupClauses = clausesByGroup.get(filter.group) || [];
        groupClauses.push(`${columnExpr} ILIKE ${valuePlaceholder}`);
        clausesByGroup.set(filter.group, groupClauses);
        values.push(`%${rawValue}`);
        continue;
      }
      if (filter.operator === 'eq') {
        const groupClauses = clausesByGroup.get(filter.group) || [];
        groupClauses.push(`${columnExpr} = ${valuePlaceholder}`);
        clausesByGroup.set(filter.group, groupClauses);
        values.push(rawValue);
        continue;
      }
      throw new Error('Invalid operator for string filter');
    }

    if (dataTypeKind === 'number') {
      const numericValue = Number(rawValue);
      if (!Number.isFinite(numericValue)) {
        throw new Error('Filter value must be numeric');
      }

      const operatorMap: Record<string, string> = {
        eq: '=',
        gt: '>',
        gte: '>=',
        lt: '<',
        lte: '<=',
      };
      const sqlOperator = operatorMap[filter.operator];
      if (!sqlOperator) {
        throw new Error('Invalid operator for numeric filter');
      }

      const groupClauses = clausesByGroup.get(filter.group) || [];
      groupClauses.push(`${columnExpr} ${sqlOperator} ${valuePlaceholder}`);
      clausesByGroup.set(filter.group, groupClauses);
      values.push(numericValue);
      continue;
    }

    if (dataTypeKind === 'boolean') {
      if (filter.operator !== 'eq') {
        throw new Error('Invalid operator for boolean filter');
      }

      const normalized = rawValue.toLowerCase();
      if (normalized !== 'true' && normalized !== 'false' && normalized !== '1' && normalized !== '0') {
        throw new Error('Filter value must be boolean');
      }

      const groupClauses = clausesByGroup.get(filter.group) || [];
      groupClauses.push(`${columnExpr} = ${valuePlaceholder}`);
      clausesByGroup.set(filter.group, groupClauses);
      values.push(normalized === 'true' || normalized === '1');
      continue;
    }

    const dateValue = rawValue;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateValue)) {
      throw new Error('Filter value must be a date (YYYY-MM-DD)');
    }

    const dateOperatorMap: Record<string, string> = {
      eq: '=',
      before: '<',
      after: '>',
      onOrBefore: '<=',
      onOrAfter: '>=',
    };
    const dateOperator = dateOperatorMap[filter.operator];
    if (!dateOperator) {
      throw new Error('Invalid operator for date filter');
    }

    const groupClauses = clausesByGroup.get(filter.group) || [];
    groupClauses.push(`${columnExpr}::date ${dateOperator} ${valuePlaceholder}::date`);
    clausesByGroup.set(filter.group, groupClauses);
    values.push(dateValue);
  }

  const innerConnector = filterLogic === 'OR' ? ' OR ' : ' AND ';
  const outerConnector = groupLogic === 'OR' ? ' OR ' : ' AND ';
  const groupedClauses = Array.from(clausesByGroup.entries())
    .sort((left, right) => left[0] - right[0])
    .map(([, groupClauses]) => `(${groupClauses.map(clause => `(${clause})`).join(innerConnector)})`);

  return { clause: groupedClauses.join(outerConnector), values };
}

function buildSafeOrderByClause(
  sorts: ListSortCondition[],
  baseAlias: string,
  allowedColumns: Set<string>,
  defaultOrderBy: string
): string {
  if (sorts.length === 0) {
    return defaultOrderBy;
  }

  const orderFragments: string[] = [];
  for (const sort of sorts) {
    if (!allowedColumns.has(sort.field)) {
      throw new Error('Sort field is not allowed');
    }

    const direction = sort.direction === 'DESC' ? 'DESC' : 'ASC';
    orderFragments.push(`${baseAlias}.${quoteIdentifier(sort.field)} ${direction}`);
  }

  return `${orderFragments.join(', ')}, ${defaultOrderBy}`;
}

function buildEntityForeignKeyMapFromBundle(bundle: FrontendMetadataBundle): Map<string, EntityForeignKeyRecord[]> {
  const byEntity = new Map<string, Map<string, EntityForeignKeyRecord>>();

  for (const row of bundle.app_entity_foreign_keys) {
    const entityKey = String(row.entity_key);
    const foreignKeyKey = String(row.foreign_key_key);
    const entityMap = byEntity.get(entityKey) || new Map<string, EntityForeignKeyRecord>();
    byEntity.set(entityKey, entityMap);

    const existing = entityMap.get(foreignKeyKey);
    const columnEntry = {
      position: Number(row.position),
      columnName: String(row.column_name),
      referencedColumnName: String(row.referenced_column_name),
    };

    if (existing) {
      existing.columns.push(columnEntry);
      continue;
    }

    const group = bundle.app_entity_foreign_key_groups.find(groupRow =>
      String(groupRow.entity_key) === entityKey && String(groupRow.foreign_key_key) === foreignKeyKey
    );

    entityMap.set(foreignKeyKey, {
      entityKey,
      foreignKeyKey,
      referencedEntityKey: String(row.referenced_entity_key),
      onUpdateAction: String(group?.on_update_action || ''),
      onDeleteAction: String(group?.on_delete_action || ''),
      columns: [columnEntry],
    });
  }

  const grouped = new Map<string, EntityForeignKeyRecord[]>();
  for (const [entityKey, foreignKeys] of byEntity.entries()) {
    grouped.set(
      entityKey,
      Array.from(foreignKeys.values())
        .map(foreignKey => ({
          ...foreignKey,
          columns: foreignKey.columns.slice().sort((left, right) => left.position - right.position),
        }))
        .sort((left, right) => left.foreignKeyKey.localeCompare(right.foreignKeyKey))
    );
  }

  return grouped;
}

function buildForeignKeyDependencyMapFromBundle(bundle: FrontendMetadataBundle): Map<string, ForeignKeyDependencyRecord[]> {
  const byEntity = new Map<string, Map<string, ForeignKeyDependencyRecord>>();

  for (const row of bundle.app_entity_foreign_key_dependency_mappings) {
    const entityKey = String(row.entity_key);
    const dependentForeignKeyKey = String(row.dependent_foreign_key_key);
    const requiredForeignKeyKey = String(row.required_foreign_key_key);
    const key = `${dependentForeignKeyKey}__${requiredForeignKeyKey}`;
    const entityMap = byEntity.get(entityKey) || new Map<string, ForeignKeyDependencyRecord>();
    byEntity.set(entityKey, entityMap);

    const existing = entityMap.get(key);
    if (existing) {
      existing.mappings.push({
        sharedLocalColumnName: String(row.shared_local_column_name),
      });
      continue;
    }

    entityMap.set(key, {
      entityKey,
      dependentForeignKeyKey,
      requiredForeignKeyKey,
      mappings: [{
        sharedLocalColumnName: String(row.shared_local_column_name),
      }],
    });
  }

  const grouped = new Map<string, ForeignKeyDependencyRecord[]>();
  for (const [entityKey, dependencies] of byEntity.entries()) {
    grouped.set(
      entityKey,
      Array.from(dependencies.values())
        .map(dependency => ({
          ...dependency,
          mappings: dependency.mappings
            .slice()
            .sort((left, right) => left.sharedLocalColumnName.localeCompare(right.sharedLocalColumnName)),
        }))
        .sort((left, right) => left.dependentForeignKeyKey.localeCompare(right.dependentForeignKeyKey))
    );
  }

  return grouped;
}

async function buildFrontendSchema() {
  const bundle = await getFrontendMetadataBundle();

  const entityRegistryMap = rowsToMap(
    bundle.app_entities,
    row => String(row.entity_key),
    row => ({
      entityKey: String(row.entity_key),
      tableName: String(row.table_name),
      singular: { es: String(row.singular_es), en: String(row.singular_en) },
      plural: { es: String(row.plural_es), en: String(row.plural_en) },
    })
  );

  const dataTypeUiProfileMap = rowsToMap(
    bundle.app_data_type_ui_profiles,
    row => String(row.data_type),
    row => ({
      dataType: String(row.data_type),
      ...(row.control ? { control: String(row.control) } : {}),
      ...(row.input_type ? { inputType: String(row.input_type) } : {}),
      ...(row.parser ? { parser: String(row.parser) } : {}),
      ...(row.step ? { step: String(row.step) } : {}),
    })
  );

  const optionSetDefinitionMap = rowsToMap(
    bundle.app_option_set_definitions,
    row => String(row.option_set_key),
    row => ({
      optionSetKey: String(row.option_set_key),
      sourceKind: String(row.source_kind),
      label: { es: String(row.label_es), en: String(row.label_en) },
    })
  );
  const regexPatternMap = buildEntityColumnRegexPatternMap(bundle);

  const foreignKeyMap = buildEntityForeignKeyMapFromBundle(bundle);
  const foreignKeyDependencyMap = buildForeignKeyDependencyMapFromBundle(bundle);

  const hiddenColumnMap = rowsToGroupedMap(
    bundle.app_entity_hidden_columns,
    row => String(row.entity_key),
    row => ({
      entityKey: String(row.entity_key),
      columnName: String(row.column_name),
    })
  );

  const shownReferencedColumnMap = rowsToGroupedMap(
    bundle.app_shown_referenced_entity_columns,
    row => String(row.entity_key),
    row => ({
      entityKey: String(row.entity_key),
      referencedEntityKey: String(row.referenced_entity_key),
      displayedEntityColumn: String(row.displayed_entity_column),
    })
  );

  const columnMetaMap = rowsToGroupedMap(
    bundle.app_entity_columns,
    row => String(row.entity_key),
    row => ({
      entityKey: String(row.entity_key),
      columnName: String(row.column_name),
      label: {
        es: String(row.label_es || row.column_name),
        en: String(row.label_en || row.column_name),
      },
    })
  );

  const primaryKeyMap = rowsToGroupedMap(
    bundle.app_entity_primary_keys,
    row => String(row.entity_key),
    row => ({
      entityKey: String(row.entity_key),
      position: Number(row.position),
      columnName: String(row.column_name),
    })
  );

  const dynamicOptionSets = await getDynamicOptionSets(optionSetDefinitionMap);
  const foreignKeyAutoOptions = await getForeignKeyAutoOptionSets(entityRegistryMap);
  const submenuMap = rowsToMap(
    bundle.app_submenus,
    row => String(row.submenu_key),
    row => ({
      submenuKey: String(row.submenu_key),
      label: { es: String(row.label_es), en: String(row.label_en) },
    })
  );
  const submenuEntityMap = rowsToGroupedMap(
    bundle.app_submenu_entities,
    row => String(row.submenu_key),
    row => ({
      submenuKey: String(row.submenu_key),
      entityKey: String(row.entity_key),
    })
  );
  const uiActionsMap = rowsToMap(
    bundle.ui_actions,
    row => String(row.action_key),
    row => ({
      actionKey: String(row.action_key),
      label: { es: String(row.label_es), en: String(row.label_en) },
    })
  );
  const uiMessageMap = rowsToMap(
    bundle.app_ui_messages,
    row => String(row.message_key),
    row => ({
      messageKey: String(row.message_key),
      text: { es: String(row.text_es), en: String(row.text_en) },
    })
  );

  const i18nFieldLabels = Array.from(columnMetaMap.entries()).reduce((acc, [entityKey, columns]) => {
    for (const column of columns) {
      acc[`${entityKey}.${column.columnName}`] = column.label;
    }
    return acc;
  }, {} as Record<string, LocaleText>);

  const entities = {} as Record<string, any>;

  for (const entityName of Array.from(entityRegistryMap.keys())) {
    const runtimeConfig = await resolveRuntimeEntityConfig(entityName, entityRegistryMap, primaryKeyMap, foreignKeyMap);
    if (!runtimeConfig) {
      continue;
    }

    const writeColumnInfo = await getCachedRelationColumns(runtimeConfig.tableName);
    const writeColumnMap = Object.fromEntries(
      writeColumnInfo.map(column => [column.columnName, column])
    ) as Record<string, ColumnInfo>;
    const listProjectionPlan = buildListProjectionPlan(
      runtimeConfig,
      entityRegistryMap,
      columnMetaMap,
      hiddenColumnMap,
      shownReferencedColumnMap
    );

    const fields = {} as Record<string, any>;

    listProjectionPlan.projectedFields.forEach(field => {
      const pattern = regexPatternMap.get(`${entityName}.${field.key}`);
      fields[field.key] = buildFieldSpec({
        fieldKey: field.key,
        columnInfo: writeColumnMap[field.key],
        dataTypeUiProfileMap,
        primaryKeyColumns: runtimeConfig.primaryKeyColumns,
        pattern,
        showInForm: false,
      });
    });

    runtimeConfig.listColumns.forEach(columnName => {
      const optionSetKey = foreignKeyAutoOptions.byField.get(`${entityName}.${columnName}`);
      const columnInfo = writeColumnMap[columnName];
      const pattern = regexPatternMap.get(`${entityName}.${columnName}`);
      fields[columnName] = buildFieldSpec({
        fieldKey: columnName,
        columnInfo,
        dataTypeUiProfileMap,
        primaryKeyColumns: runtimeConfig.primaryKeyColumns,
        optionSetKey,
        pattern,
        ...(columnInfo ? {} : { showInForm: false }),
      });
    });

    runtimeConfig.writeColumns.forEach(columnName => {
      if (fields[columnName]) {
        return;
      }

      const resolvedOptionSetKey = foreignKeyAutoOptions.byField.get(`${entityName}.${columnName}`);
      const pattern = regexPatternMap.get(`${entityName}.${columnName}`);
      fields[columnName] = buildFieldSpec({
        fieldKey: columnName,
        columnInfo: writeColumnMap[columnName],
        dataTypeUiProfileMap,
        primaryKeyColumns: runtimeConfig.primaryKeyColumns,
        optionSetKey: resolvedOptionSetKey,
        pattern,
        ...(writeColumnMap[columnName] ? {} : { showInForm: true }),
      });
    });

    const registry = entityRegistryMap.get(entityName);

    entities[entityName] = {
      names: registry ? { singular: registry.singular, plural: registry.plural } : { singular: { es: entityName, en: entityName }, plural: { es: entityName, en: entityName } },
      primaryKeyFields: runtimeConfig.primaryKeyColumns,
      fieldOrder: listProjectionPlan.projectedFields.map(field => field.key),
      formOrder: runtimeConfig.writeColumns,
      foreignKeys: runtimeConfig.foreignKeys,
      foreignKeyDependencies: foreignKeyDependencyMap.get(entityName) || [],
      fields,
    };
  }

  const foreignKeyOptionRowsByField = Object.fromEntries(foreignKeyAutoOptions.rowsByField.entries());

  const submenuGroups = Array.from(submenuMap.values())
    .map(submenu => ({
      key: submenu.submenuKey,
      label: submenu.label,
      entities: (submenuEntityMap.get(submenu.submenuKey) || [])
        .map(row => row.entityKey)
        .filter(entityKey => entityRegistryMap.has(entityKey))
        .sort((left, right) => left.localeCompare(right)),
    }))
    .filter(group => group.entities.length > 0);

  const navigation = { groups: submenuGroups };

  const i18nMessages = Object.fromEntries(
    Array.from(uiMessageMap.values()).map(message => [message.messageKey, message.text])
  );
  const uiActionLabels = Object.fromEntries(
    Array.from(uiActionsMap.values()).map(action => [action.actionKey, action.label])
  );

  return {
    i18n: {
      fieldLabels: i18nFieldLabels,
      optionSets: {
        ...dynamicOptionSets,
        ...foreignKeyAutoOptions.optionSets,
      },
      messages: i18nMessages,
      uiActionLabels,
      foreignKeyOptionRowsByField,
    },
    navigation,
    entities,
  };
}

app.get('/api/meta', async (_req, res) => {
  try {
    res.json(await buildFrontendSchema());
  } catch (error) {
    logAndSendErrorResponse('building metadata for', 'meta', error, res);
  }
});

app.get('/api/schema-studio/entities', async (_req, res) => {
  try {
    const rows = await queryRowsOrEmpty<{
      entity_key: string;
      table_name: string;
      singular_es: string;
      singular_en: string;
    }>(
      `
        SELECT entity_key, table_name, singular_es, singular_en
        FROM app_entities
        WHERE entity_key NOT LIKE 'app_%'
          AND entity_key <> 'ui_actions'
        ORDER BY entity_key
      `
    );

    res.json(rows.map(row => ({
      entityKey: row.entity_key,
      tableName: row.table_name,
      labelEs: row.singular_es,
      labelEn: row.singular_en,
    })));
  } catch (error) {
    logAndSendErrorResponse('listing schema studio entities for', 'schema-studio', error, res);
  }
});

app.get('/api/schema-studio/:entity', async (req, res) => {
  const entityKey = req.params.entity;
  if (!entityKey) {
    return res.status(400).json({ error: 'Missing entity key' });
  }

  try {
    const model = await getSchemaStudioEntityModel(entityKey);
    if (!model) {
      return res.status(404).json({ error: 'Entity not found' });
    }

    res.json(model);
  } catch (error) {
    logAndSendErrorResponse('reading schema studio model for', entityKey, error, res);
  }
});

app.put('/api/schema-studio/:entity', async (req, res) => {
  const entityKey = req.params.entity;
  if (!entityKey) {
    return res.status(400).json({ error: 'Missing entity key' });
  }

  try {
    const payload = req.body || {};
    const columns = parseSchemaStudioColumnInputs(Array.isArray(payload.columns) ? payload.columns : []);
    const foreignKeys = parseSchemaStudioForeignKeyInputs(Array.isArray(payload.foreignKeys) ? payload.foreignKeys : []);
    const indexes = parseSchemaStudioIndexInputs(Array.isArray(payload.indexes) ? payload.indexes : []);

    await applySchemaStudioEntityModel(entityKey, { columns, foreignKeys, indexes });
    const refreshedModel = await getSchemaStudioEntityModel(entityKey);

    res.json({
      message: 'Schema updated successfully',
      model: refreshedModel,
    });
  } catch (error) {
    if (isInsufficientPrivilegeError(error)) {
      return res.status(403).json({
        error: 'Schema Studio lacks DDL privileges. Configure SCHEMA_STUDIO_DB_USER and SCHEMA_STUDIO_DB_PASSWORD with a role that can ALTER TABLE.',
      });
    }

    if (error instanceof Error) {
      return res.status(400).json({ error: error.message });
    }
    logAndSendErrorResponse('saving schema studio model for', entityKey, error, res);
  }
});

async function resolveRuntimeConfigForRequest(
  req: express.Request,
  res: express.Response
): Promise<RuntimeEntityConfig | null> {
  const entityName = req.params.entity;
  if (!entityName) {
    res.status(404).json({ error: API_ERROR_MESSAGES.entityNotFound });
    return null;
  }

  try {
    const runtimeConfig = await resolveRuntimeEntityConfig(entityName);
    if (!runtimeConfig) {
      res.status(404).json({ error: API_ERROR_MESSAGES.entityNotFound });
      return null;
    }

    return runtimeConfig;
  } catch (error) {
    logAndSendErrorResponse('resolving entity config for', entityName, error, res);
    return null;
  }
}

app.get('/api/:entity', async (req, res) => {
  const runtimeConfig = await resolveRuntimeConfigForRequest(req, res);
  if (!runtimeConfig) {
    return;
  }

  try {
    const primaryKeyToken = typeof req.query.pk === 'string' ? req.query.pk : null;

    if (primaryKeyToken) {
      const primaryKeyValues = parsePrimaryKeyToken(primaryKeyToken, runtimeConfig.primaryKeyColumns.length);
      if (!primaryKeyValues) {
        return res.status(400).json({ error: API_ERROR_MESSAGES.invalidPrimaryKeyFormat });
      }

      const where = buildPrimaryKeyWhereClause(runtimeConfig.primaryKeyColumns);
      const query = `SELECT * FROM ${quoteIdentifier(runtimeConfig.tableName)} WHERE ${where}`;
      const result = await pool.query(query, primaryKeyValues);

      if (result.rows.length === 0) {
        return res.status(404).json({ error: API_ERROR_MESSAGES.recordNotFound });
      }

      return res.json(result.rows[0]);
    }

    const [entityRegistryMap, columnMetaMap, hiddenColumnMap, shownReferencedColumnMap] = await Promise.all([
      getEntityRegistryMap(),
      getEntityColumnMetaMap(),
      getEntityHiddenColumnMap(),
      getShownReferencedEntityColumnMap(),
    ]);

    const listProjectionPlan = buildListProjectionPlan(
      runtimeConfig,
      entityRegistryMap,
      columnMetaMap,
      hiddenColumnMap,
      shownReferencedColumnMap
    );

    const queryOptions = parseListQueryOptions(req);
    const columnInfoByName = new Map((await getCachedRelationColumns(runtimeConfig.tableName))
      .map(columnInfo => [columnInfo.columnName, columnInfo] as const));
    const allowedColumns = new Set(listProjectionPlan.filterableColumns);

    let parameterValues: any[] = [];
    let whereClause = '';

    const typedFilter = buildTypedFilterClause(
      queryOptions.filters,
      queryOptions.filterLogic,
      queryOptions.groupLogic,
      listProjectionPlan.baseAlias,
      columnInfoByName,
      allowedColumns,
      1
    );

    if (typedFilter) {
      whereClause = ` WHERE ${typedFilter.clause}`;
      parameterValues = typedFilter.values;
    }

    const orderByClause = buildSafeOrderByClause(
      queryOptions.sorts,
      listProjectionPlan.baseAlias,
      allowedColumns,
      listProjectionPlan.defaultOrderBy
    );

    const paginationStart = parameterValues.length + 1;
    const limitPlaceholder = `$${paginationStart}`;
    const offsetPlaceholder = `$${paginationStart + 1}`;
    const offset = (queryOptions.page - 1) * queryOptions.pageSize;

    const finalQuery = `${listProjectionPlan.selectClause} ${listProjectionPlan.fromClause}${whereClause} ORDER BY ${orderByClause} LIMIT ${limitPlaceholder} OFFSET ${offsetPlaceholder}`;
    const result = await pool.query(finalQuery, [...parameterValues, queryOptions.pageSize, offset]);

    if (queryOptions.includeMeta) {
      const countQuery = `SELECT COUNT(*)::int AS total ${listProjectionPlan.fromClause}${whereClause}`;
      const countResult = await pool.query<{ total: number }>(countQuery, parameterValues);
      const total = countResult.rows[0]?.total || 0;
      const totalPages = Math.max(1, Math.ceil(total / queryOptions.pageSize));
      return res.json({
        rows: result.rows,
        total,
        page: queryOptions.page,
        pageSize: queryOptions.pageSize,
        totalPages,
      });
    }

    res.json(result.rows);
  } catch (error) {
    if (
      error instanceof Error
      && (
        error.message.toLowerCase().includes('filter')
        || error.message.toLowerCase().includes('sort')
        || error.message.toLowerCase().includes('page')
      )
    ) {
      return res.status(400).json({ error: API_ERROR_MESSAGES.invalidListQuery, details: [error.message] });
    }
    logAndSendErrorResponse('listing', runtimeConfig.entityName, error, res);
  }
});

app.post('/api/:entity', async (req, res) => {
  const runtimeConfig = await resolveRuntimeConfigForRequest(req, res);
  if (!runtimeConfig) {
    return;
  }

  const providedColumns = runtimeConfig.writeColumns.filter(column => req.body[column] !== undefined);
  if (providedColumns.length === 0) {
    return res.status(400).json({ error: API_ERROR_MESSAGES.noFieldsProvidedForInsert });
  }

  try {
    const regexValidationErrors = await validateEntityRegexRules(runtimeConfig.entityName, req.body, providedColumns);
    if (regexValidationErrors.length > 0) {
      return res.status(400).json({
        error: 'Regex validation failed',
        details: regexValidationErrors,
      });
    }

    const placeholders = providedColumns.map((_, index) => `$${index + 1}`).join(', ');
    const values = providedColumns.map(column => req.body[column]);
    const query = `
      INSERT INTO ${quoteIdentifier(runtimeConfig.tableName)} (${providedColumns.map(quoteIdentifier).join(', ')})
      VALUES (${placeholders})
      RETURNING *
    `;

    const result = await pool.query(query, values);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    logAndSendErrorResponse('creating', runtimeConfig.entityName, error, res);
  }
});

app.put('/api/:entity', async (req, res) => {
  const runtimeConfig = await resolveRuntimeConfigForRequest(req, res);
  if (!runtimeConfig) {
    return;
  }

  const primaryKeyToken = typeof req.query.pk === 'string' ? req.query.pk : null;
  const originalPrimaryKeyValues = primaryKeyToken ? parsePrimaryKeyToken(primaryKeyToken, runtimeConfig.primaryKeyColumns.length) : null;
  if (!originalPrimaryKeyValues) {
    return res.status(400).json({ error: API_ERROR_MESSAGES.invalidPrimaryKeyFormat });
  }

  const updatableColumns = runtimeConfig.writeColumns.filter(column => req.body[column] !== undefined);
  if (updatableColumns.length === 0) {
    return res.status(400).json({ error: API_ERROR_MESSAGES.noFieldsProvidedForUpdate });
  }

  try {
    const regexValidationErrors = await validateEntityRegexRules(runtimeConfig.entityName, req.body, updatableColumns);
    if (regexValidationErrors.length > 0) {
      return res.status(400).json({
        error: 'Regex validation failed',
        details: regexValidationErrors,
      });
    }

    const setClause = updatableColumns
      .map((column, index) => `${quoteIdentifier(column)} = $${index + 1}`)
      .join(', ');
    const whereClause = buildPrimaryKeyWhereClause(runtimeConfig.primaryKeyColumns, updatableColumns.length + 1);
    const values = updatableColumns.map(column => req.body[column]).concat(originalPrimaryKeyValues);

    const query = `
      UPDATE ${quoteIdentifier(runtimeConfig.tableName)}
      SET ${setClause}
      WHERE ${whereClause}
      RETURNING *
    `;

    const result = await pool.query(query, values);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: API_ERROR_MESSAGES.recordNotFound });
    }

    res.json(result.rows[0]);
  } catch (error) {
    logAndSendErrorResponse('updating', runtimeConfig.entityName, error, res);
  }
});

app.delete('/api/:entity', async (req, res) => {
  const runtimeConfig = await resolveRuntimeConfigForRequest(req, res);
  if (!runtimeConfig) {
    return;
  }

  const primaryKeyToken = typeof req.query.pk === 'string' ? req.query.pk : null;
  const primaryKeyValues = primaryKeyToken ? parsePrimaryKeyToken(primaryKeyToken, runtimeConfig.primaryKeyColumns.length) : null;
  if (!primaryKeyValues) {
    return res.status(400).json({ error: API_ERROR_MESSAGES.invalidPrimaryKeyFormat });
  }

  try {
    const whereClause = buildPrimaryKeyWhereClause(runtimeConfig.primaryKeyColumns);
    const query = `DELETE FROM ${quoteIdentifier(runtimeConfig.tableName)} WHERE ${whereClause} RETURNING *`;
    const result = await pool.query(query, primaryKeyValues);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: API_ERROR_MESSAGES.recordNotFound });
    }

    res.json({ message: 'Record deleted successfully' });
  } catch (error) {
    logAndSendErrorResponse('deleting', runtimeConfig.entityName, error, res);
  }
});

app.use(express.static(path.join(__dirname, '../../frontend/dist')));

app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, '../../frontend/dist/index.html'));
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
