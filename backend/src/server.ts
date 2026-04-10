import express from 'express';
import cors from 'cors';
import { Pool } from 'pg';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

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

type SubmenuRecord = {
  submenuKey: string;
  label: LocaleText;
};

type SubmenuEntityRecord = {
  submenuKey: string;
  entityKey: string;
};

type UIActionRecord = {
  actionKey: string;
  label: LocaleText;
};

type OptionSetDefinitionRecord = {
  optionSetKey: string;
  sourceKind: string;
  label: LocaleText;
};

type UIMessageRecord = {
  messageKey: string;
  text: LocaleText;
};

function quoteIdentifier(identifier: string): string {
  return `"${identifier.replace(/"/g, '""')}"`;
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

async function getRelationColumnNameSet(relationName: string): Promise<Set<string>> {
  const columns = await getRelationColumns(relationName);
  return new Set(columns.map(column => column.columnName));
}

async function getEntityRegistryMap(): Promise<Map<string, EntityRegistryRecord>> {
  const rows = await queryRowsOrEmpty<{
    entity_key: string;
    table_name: string;
    singular_es: string;
    singular_en: string;
    plural_es: string;
    plural_en: string;
  }>(
    `
      SELECT entity_key, table_name, singular_es, singular_en, plural_es, plural_en
      FROM app_entities
      WHERE is_allowed = TRUE
      ORDER BY entity_key
    `
  );

  return rowsToMap(
    rows,
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
  const rows = await queryRowsOrEmpty<{
    entity_key: string;
    column_name: string;
  }>(
    `
      SELECT entity_key, column_name
      FROM app_entity_hidden_columns
      ORDER BY entity_key, column_name
    `
  );

  return rowsToGroupedMap(
    rows,
    row => row.entity_key,
    row => ({
      entityKey: row.entity_key,
      columnName: row.column_name,
    })
  );
}

async function getShownReferencedEntityColumnMap(): Promise<Map<string, ShownReferencedEntityColumnRecord[]>> {
  const rows = await queryRowsOrEmpty<{
    entity_key: string;
    referenced_entity_key: string;
    displayed_entity_column: string;
  }>(
    `
      SELECT entity_key, referenced_entity_key, displayed_entity_column
      FROM app_shown_referenced_entity_columns
      ORDER BY entity_key, referenced_entity_key, displayed_entity_column
    `
  );

  return rowsToGroupedMap(
    rows,
    row => row.entity_key,
    row => ({
      entityKey: row.entity_key,
      referencedEntityKey: row.referenced_entity_key,
      displayedEntityColumn: row.displayed_entity_column,
    })
  );
}

async function getEntityColumnMetaMap(): Promise<Map<string, EntityColumnMetaRecord[]>> {
  const rows = await queryRowsOrEmpty<{
    entity_key: string;
    column_name: string;
    label_es: string | null;
    label_en: string | null;
  }>(
    `
      SELECT entity_key, column_name, label_es, label_en
      FROM app_entity_columns
      ORDER BY entity_key, column_name
    `
  );

  return rowsToGroupedMap(
    rows,
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
  const rows = await queryRowsOrEmpty<{
    entity_key: string;
    position: number;
    column_name: string;
  }>(
    `
      SELECT entity_key, position, column_name
      FROM app_entity_primary_keys
      ORDER BY entity_key, position
    `
  );

  return rowsToGroupedMap(
    rows,
    row => row.entity_key,
    row => ({
      entityKey: row.entity_key,
      position: row.position,
      columnName: row.column_name,
    })
  );
}

async function getDataTypeUIProfileMap(): Promise<Map<string, DataTypeUIProfileRecord>> {
  const rows = await queryRowsOrEmpty<{
    data_type: string;
    control: string | null;
    input_type: string | null;
    parser: string | null;
    step: string | null;
  }>(
    `
      SELECT data_type, control, input_type, parser, step
      FROM app_data_type_ui_profiles
      ORDER BY data_type
    `
  );

  return rowsToMap(
    rows,
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

async function getForeignKeyDependencyMap(): Promise<Map<string, ForeignKeyDependencyRecord[]>> {
  const rows = await queryRowsOrEmpty<{
    entity_key: string;
    dependent_foreign_key_key: string;
    required_foreign_key_key: string;
    shared_local_column_name: string;
  }>(
    `
      SELECT
        d.entity_key,
        d.dependent_foreign_key_key,
        d.required_foreign_key_key,
        m.shared_local_column_name
      FROM app_entity_foreign_key_dependencies d
      JOIN app_entity_foreign_key_dependency_mappings m
        ON m.entity_key = d.entity_key
       AND m.dependent_foreign_key_key = d.dependent_foreign_key_key
       AND m.required_foreign_key_key = d.required_foreign_key_key
      ORDER BY d.entity_key, d.dependent_foreign_key_key, d.required_foreign_key_key, m.shared_local_column_name
    `
  );

    const byEntity = new Map<string, Map<string, ForeignKeyDependencyRecord>>();

    for (const row of rows) {
      const entityMap = byEntity.get(row.entity_key) || new Map<string, ForeignKeyDependencyRecord>();
      byEntity.set(row.entity_key, entityMap);

      const key = `${row.dependent_foreign_key_key}__${row.required_foreign_key_key}`;
      const existing = entityMap.get(key);
      if (existing) {
        existing.mappings.push({
          sharedLocalColumnName: row.shared_local_column_name,
        });
        continue;
      }

      entityMap.set(key, {
        entityKey: row.entity_key,
        dependentForeignKeyKey: row.dependent_foreign_key_key,
        requiredForeignKeyKey: row.required_foreign_key_key,
        mappings: [{
          sharedLocalColumnName: row.shared_local_column_name,
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

async function getOptionSetDefinitionMap(): Promise<Map<string, OptionSetDefinitionRecord>> {
  const rows = await queryRowsOrEmpty<{
    option_set_key: string;
    source_kind: string;
    label_es: string;
    label_en: string;
  }>(
    `
      SELECT option_set_key, source_kind, label_es, label_en
      FROM app_option_set_definitions
      ORDER BY option_set_key
    `
  );

  return rowsToMap(
    rows,
    row => row.option_set_key,
    row => ({
      optionSetKey: row.option_set_key,
      sourceKind: row.source_kind,
      label: { es: row.label_es, en: row.label_en },
    })
  );
}

async function getUIMessageMap(): Promise<Map<string, UIMessageRecord>> {
  const rows = await queryRowsOrEmpty<{
    message_key: string;
    text_es: string;
    text_en: string;
  }>(
    `
      SELECT message_key, text_es, text_en
      FROM app_ui_messages
      ORDER BY message_key
    `
  );

  return rowsToMap(
    rows,
    row => row.message_key,
    row => ({
      messageKey: row.message_key,
      text: { es: row.text_es, en: row.text_en },
    })
  );
}

async function getDynamicOptionSets(
  entityRegistryMap: Map<string, EntityRegistryRecord>,
  optionSetDefinitionMap: Map<string, OptionSetDefinitionRecord>
): Promise<Record<string, OptionItem[]>> {
  const optionSets: Record<string, OptionItem[]> = {};

  const fetchLabeledOptions = async (query: string): Promise<OptionItem[]> => {
    const result = await pool.query<{ value: string; label_es: string; label_en: string }>(query);
    return result.rows.map((row: { value: string; label_es: string; label_en: string }) => ({
      value: row.value,
      label: { es: row.label_es, en: row.label_en },
    }));
  };

  const defaultDefinitions: OptionSetDefinitionRecord[] = [
    { optionSetKey: 'appEntities', sourceKind: 'entities', label: { es: 'Entidades de app', en: 'App entities' } },
    { optionSetKey: 'databaseTables', sourceKind: 'tables', label: { es: 'Tablas', en: 'Tables' } },
    { optionSetKey: 'referentialActions', sourceKind: 'referential_actions', label: { es: 'Acciones referenciales', en: 'Referential actions' } },
    { optionSetKey: 'uiActions', sourceKind: 'ui_actions', label: { es: 'Acciones de UI', en: 'UI actions' } },
  ];
  const definitions = optionSetDefinitionMap.size > 0
    ? Array.from(optionSetDefinitionMap.values()).sort((left, right) => left.optionSetKey.localeCompare(right.optionSetKey))
    : defaultDefinitions;

  for (const definition of definitions) {
    if (definition.sourceKind === 'entities') {
      optionSets[definition.optionSetKey] = Array.from(entityRegistryMap.values())
        .sort((left, right) => left.entityKey.localeCompare(right.entityKey))
        .map(registry => ({
          value: registry.entityKey,
          label: registry.singular,
        }));
      continue;
    }

    if (definition.sourceKind === 'tables') {
      optionSets[definition.optionSetKey] = Array.from(entityRegistryMap.values())
        .sort((left, right) => left.entityKey.localeCompare(right.entityKey))
        .reduce((acc, registry) => {
          if (acc.some(option => option.value === registry.tableName)) {
            return acc;
          }

          acc.push({
            value: registry.tableName,
            label: registry.singular,
          });
          return acc;
        }, [] as OptionItem[]);
      continue;
    }

    if (definition.sourceKind === 'referential_actions') {
      optionSets[definition.optionSetKey] = await fetchLabeledOptions(`
        SELECT action_key AS value, label_es, label_en
        FROM app_referential_actions
        ORDER BY action_key
      `);
      continue;
    }

    if (definition.sourceKind === 'ui_actions') {
      optionSets[definition.optionSetKey] = await fetchLabeledOptions(`
        SELECT action_key AS value, label_es, label_en
        FROM ui_actions
        ORDER BY action_key
      `);
    }
  }

  return optionSets;
}

async function getSubmenuMap(): Promise<Map<string, SubmenuRecord>> {
  try {
    const result = await pool.query<{
      submenu_key: string;
      label_es: string;
      label_en: string;
    }>(
      `
        SELECT submenu_key, label_es, label_en
        FROM app_submenus
        ORDER BY submenu_key
      `
    );

    return rowsToMap(
      result.rows,
      row => row.submenu_key,
      row => ({
        submenuKey: row.submenu_key,
        label: { es: row.label_es, en: row.label_en },
      })
    );
  } catch (error) {
    if (isTableNotFoundError(error)) {
      return new Map<string, SubmenuRecord>();
    }
    throw error;
  }
}

async function getSubmenuEntityMap(): Promise<Map<string, SubmenuEntityRecord[]>> {
  try {
    const result = await pool.query<{
      submenu_key: string;
      entity_key: string;
    }>(
      `
        SELECT submenu_key, entity_key
        FROM app_submenu_entities
        ORDER BY submenu_key, entity_key
      `
    );

    return rowsToGroupedMap(
      result.rows,
      row => row.submenu_key,
      row => ({
        submenuKey: row.submenu_key,
        entityKey: row.entity_key,
      })
    );
  } catch (error) {
    if (isTableNotFoundError(error)) {
      return new Map<string, SubmenuEntityRecord[]>();
    }
    throw error;
  }
}

async function getUIActionsMap(): Promise<Map<string, UIActionRecord>> {
  try {
    const result = await pool.query<{
      action_key: string;
      label_es: string;
      label_en: string;
    }>(
      `
        SELECT action_key, label_es, label_en
        FROM ui_actions
        ORDER BY action_key
      `
    );

    return rowsToMap(
      result.rows,
      row => row.action_key,
      row => ({
        actionKey: row.action_key,
        label: { es: row.label_es, en: row.label_en },
      })
    );
  } catch (error) {
    if (isTableNotFoundError(error)) {
      return new Map<string, UIActionRecord>();
    }
    throw error;
  }
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
  registryMap?: Map<string, EntityRegistryRecord>
): Promise<RuntimeEntityConfig | null> {
  const effectiveRegistryMap = registryMap || (await getEntityRegistryMap());
  const registry = effectiveRegistryMap.get(entityName);

  if (!registry) {
    return null;
  }

  const [primaryKeyMap, foreignKeyMap] = await Promise.all([
    getEntityPrimaryKeyMap(),
    getEntityForeignKeyMap(),
  ]);

  const primaryKeyEntries = (primaryKeyMap.get(entityName) || []).slice();
  const primaryKeyColumns = primaryKeyEntries.map(row => row.columnName);

  if (primaryKeyColumns.length === 0) {
    // Entities without PK metadata are not manageable by generic CRUD endpoints.
    // Skip them instead of failing the entire metadata build.
    return null;
  }

  const writeColumnInfo = await getRelationColumns(registry.tableName);

  const foreignKeys = (foreignKeyMap.get(entityName) || [])
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

function buildListProjectionPlan(
  runtimeConfig: RuntimeEntityConfig,
  entityRegistryMap: Map<string, EntityRegistryRecord>,
  columnMetaMap: Map<string, EntityColumnMetaRecord[]>,
  hiddenColumnMap: Map<string, EntityHiddenColumnRecord[]>,
  shownReferencedColumnMap: Map<string, ShownReferencedEntityColumnRecord[]>
): {
  query: string;
  projectedFields: Array<{ key: string; label: LocaleText; isProjection: boolean }>;
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
  const query = `SELECT ${selectFragments.join(', ')} FROM ${quoteIdentifier(runtimeConfig.tableName)} ${baseAlias}${joins.length > 0 ? ` ${joins.join(' ')}` : ''} ORDER BY ${fallbackOrderBy}`;

  return { query, projectedFields };
}

async function buildFrontendSchema() {
  const entityRegistryMap = await getEntityRegistryMap();
  const dataTypeUiProfileMap = await getDataTypeUIProfileMap();
  const optionSetDefinitionMap = await getOptionSetDefinitionMap();
  const dynamicOptionSets = await getDynamicOptionSets(entityRegistryMap, optionSetDefinitionMap);
  const foreignKeyAutoOptions = await getForeignKeyAutoOptionSets(entityRegistryMap);
  const foreignKeyDependencyMap = await getForeignKeyDependencyMap();
  const hiddenColumnMap = await getEntityHiddenColumnMap();
  const shownReferencedColumnMap = await getShownReferencedEntityColumnMap();
  const columnMetaMap = await getEntityColumnMetaMap();
  const submenuMap = await getSubmenuMap();
  const submenuEntityMap = await getSubmenuEntityMap();
  const uiMessageMap = await getUIMessageMap();

  const i18nFieldLabels = Array.from(columnMetaMap.entries()).reduce((acc, [entityKey, columns]) => {
    for (const column of columns) {
      acc[`${entityKey}.${column.columnName}`] = column.label;
    }
    return acc;
  }, {} as Record<string, LocaleText>);

  const entities = {} as Record<string, any>;

  for (const entityName of Array.from(entityRegistryMap.keys())) {
    const runtimeConfig = await resolveRuntimeEntityConfig(entityName, entityRegistryMap);
    if (!runtimeConfig) {
      continue;
    }

    const writeColumnInfo = await getRelationColumns(runtimeConfig.tableName);
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
      const fromWriteTable = writeColumnMap[field.key];
      if (!fromWriteTable) {
        fields[field.key] = {
          showInForm: false,
        };
        return;
      }

      const typeInfo = getInputTypeAndParser(fromWriteTable.dataType, dataTypeUiProfileMap);
      fields[field.key] = {
        ...(runtimeConfig.primaryKeyColumns.includes(field.key) ? { required: true } : {}),
        ...(!fromWriteTable.isNullable ? { required: true } : {}),
        ...(typeInfo.control ? { control: typeInfo.control } : {}),
        ...(typeInfo.inputType ? { inputType: typeInfo.inputType } : {}),
        ...(typeInfo.parser ? { parser: typeInfo.parser } : {}),
        ...(typeInfo.step ? { step: typeInfo.step } : {}),
        showInForm: false,
      };
    });

    runtimeConfig.listColumns.forEach(columnName => {
      const fromWriteTable = writeColumnMap[columnName];
      const optionSetKey = foreignKeyAutoOptions.byField.get(`${entityName}.${columnName}`);

      if (!fromWriteTable) {
        fields[columnName] = {
          ...(optionSetKey ? { optionsKey: optionSetKey } : {}),
          showInForm: false,
        };
        return;
      }

      const typeInfo = getInputTypeAndParser(fromWriteTable.dataType, dataTypeUiProfileMap);
      fields[columnName] = {
        ...(runtimeConfig.primaryKeyColumns.includes(columnName) ? { required: true } : {}),
        ...(!fromWriteTable.isNullable ? { required: true } : {}),
        ...(typeInfo.control ? { control: typeInfo.control } : {}),
        ...(typeInfo.inputType ? { inputType: typeInfo.inputType } : {}),
        ...(typeInfo.parser ? { parser: typeInfo.parser } : {}),
        ...(typeInfo.step ? { step: typeInfo.step } : {}),
        ...(optionSetKey ? { optionsKey: optionSetKey } : {}),
      };
    });

    runtimeConfig.writeColumns.forEach(columnName => {
      if (fields[columnName]) {
        return;
      }

      const columnInfo = writeColumnMap[columnName];
      if (!columnInfo) {
        fields[columnName] = { showInForm: true };
        return;
      }

      const resolvedOptionSetKey = foreignKeyAutoOptions.byField.get(`${entityName}.${columnName}`);
      const typeInfo = getInputTypeAndParser(columnInfo.dataType, dataTypeUiProfileMap);

      fields[columnName] = {
        ...(runtimeConfig.primaryKeyColumns.includes(columnName) ? { required: true } : {}),
        ...(!columnInfo.isNullable ? { required: true } : {}),
        ...(typeInfo.control ? { control: typeInfo.control } : {}),
        ...(typeInfo.inputType ? { inputType: typeInfo.inputType } : {}),
        ...(typeInfo.parser ? { parser: typeInfo.parser } : {}),
        ...(typeInfo.step ? { step: typeInfo.step } : {}),
        ...(resolvedOptionSetKey ? { optionsKey: resolvedOptionSetKey } : {}),
      };
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

  return {
    i18n: {
      fieldLabels: i18nFieldLabels,
      optionSets: {
        ...dynamicOptionSets,
        ...foreignKeyAutoOptions.optionSets,
      },
      messages: i18nMessages,
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

async function resolveRuntimeConfigForRequest(
  req: express.Request,
  res: express.Response
): Promise<RuntimeEntityConfig | null> {
  const entityName = req.params.entity;
  if (!entityName) {
    res.status(404).json({ error: 'Entity not found' });
    return null;
  }

  try {
    const runtimeConfig = await resolveRuntimeEntityConfig(entityName);
    if (!runtimeConfig) {
      res.status(404).json({ error: 'Entity not found' });
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
        return res.status(400).json({ error: 'Invalid primary key format' });
      }

      const where = buildPrimaryKeyWhereClause(runtimeConfig.primaryKeyColumns);
      const query = `SELECT * FROM ${quoteIdentifier(runtimeConfig.tableName)} WHERE ${where}`;
      const result = await pool.query(query, primaryKeyValues);

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Record not found' });
      }

      return res.json(result.rows[0]);
    }

    const [entityRegistryMap, columnMetaMap, hiddenColumnMap, shownReferencedColumnMap] = await Promise.all([
      getEntityRegistryMap(),
      getEntityColumnMetaMap(),
      getEntityHiddenColumnMap(),
      getShownReferencedEntityColumnMap(),
    ]);

    const { query } = buildListProjectionPlan(
      runtimeConfig,
      entityRegistryMap,
      columnMetaMap,
      hiddenColumnMap,
      shownReferencedColumnMap
    );
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (error) {
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
    return res.status(400).json({ error: 'No fields provided for insert' });
  }

  try {
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
    return res.status(400).json({ error: 'Invalid primary key format' });
  }

  const updatableColumns = runtimeConfig.writeColumns.filter(column => req.body[column] !== undefined);
  if (updatableColumns.length === 0) {
    return res.status(400).json({ error: 'No fields provided for update' });
  }

  try {
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
      return res.status(404).json({ error: 'Record not found' });
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
    return res.status(400).json({ error: 'Invalid primary key format' });
  }

  try {
    const whereClause = buildPrimaryKeyWhereClause(runtimeConfig.primaryKeyColumns);
    const query = `DELETE FROM ${quoteIdentifier(runtimeConfig.tableName)} WHERE ${whereClause} RETURNING *`;
    const result = await pool.query(query, primaryKeyValues);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Record not found' });
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
