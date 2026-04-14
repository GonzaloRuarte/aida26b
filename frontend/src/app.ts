// Main application file
// Code and comments in English

const API_BASE = '/api';

const REQUIRED_MESSAGE_KEYS = [
  'validationErrors',
  'deleteConfirm',
  'required',
  'invalidFormat',
  'mustBeAtLeast',
  'mustBeAtMost',
] as const;

const I18N: {
  messages: Record<string, LocaleText>;
} = {
  messages: {},
};

const UI_METADATA: {
  fieldLabels: Record<string, LocaleText>;
  optionSets: Record<string, { value: string; label: LocaleText }[]>;
  foreignKeyOptionRowsByField: Record<string, Array<{
    value: string;
    label: LocaleText;
    referencedValues: Record<string, string>;
  }>>;
} = {
  fieldLabels: {},
  optionSets: {},
  foreignKeyOptionRowsByField: {},
};

const UI_NAVIGATION: {
  groups: Array<{
    key: string;
    label: LocaleText;
    entities: EntityKey[];
  }>;
} = {
  groups: [],
};

const UI_ACTIONS: {
  actionLabels: Record<string, LocaleText>;
} = {
  actionLabels: {},
};

const DEFAULT_REFERENTIAL_ACTION = 'NO ACTION';
const FALLBACK_REFERENTIAL_ACTIONS = ['NO ACTION', 'RESTRICT', 'CASCADE', 'SET NULL', 'SET DEFAULT'];

type LocaleText = { es: string; en: string };
type FieldControl = 'input' | 'textarea' | 'select' | 'checkbox';
type FieldParser = 'string' | 'int' | 'intOrNull' | 'float' | 'floatOrNull' | 'boolean';
type MessageKey = typeof REQUIRED_MESSAGE_KEYS[number];

type RawFieldObject = {
  labelKey?: string;
  control?: FieldControl;
  inputType?: string;
  required?: boolean;
  readOnlyOnEdit?: boolean;
  step?: string;
  optionsKey?: string;
  parser?: FieldParser;
  min?: number;
  max?: number;
  pattern?: string;
  showInTable?: boolean;
  showInForm?: boolean;
};

type RawFieldSpec = true | RawFieldObject;

type RawEntity = {
  names: {
    singular: LocaleText;
    plural: LocaleText;
  };
  primaryKeyFields?: string[];
  fields: Record<string, RawFieldSpec>;
  fieldOrder?: string[];
  formOrder?: string[];
  rowActions?: Array<{
    key: string;
    kind: 'openEntityFromField';
    targetField: string;
  }>;
  foreignKeys?: Array<{
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
  }>;
  foreignKeyDependencies?: Array<{
    entityKey: string;
    dependentForeignKeyKey: string;
    requiredForeignKeyKey: string;
    mappings: Array<{
      sharedLocalColumnName: string;
    }>;
  }>;
};

type ResolvedOption = {
  value: string;
  label: string;
};

type CompiledField = {
  id: string;
  label: string;
  control: FieldControl;
  inputType: string;
  required: boolean;
  readOnlyOnEdit: boolean;
  step?: string;
  options: ResolvedOption[];
  parser: FieldParser;
  min?: number;
  max?: number;
  pattern?: string;
};

type CompiledEntity = {
  key: EntityKey;
  primaryKeyFields: string[];
  foreignKeys: NonNullable<RawEntity['foreignKeys']>;
  foreignKeyDependencies: NonNullable<RawEntity['foreignKeyDependencies']>;
  rowActions: Array<{
    key: string;
    kind: 'openEntityFromField';
    targetField: string;
  }>;
  ui: {
    singular: string;
    plural: string;
    add: string;
    edit: string;
    update: string;
    cancel: string;
    actions: string;
  };
  tableFields: CompiledField[];
  formFields: CompiledField[];
};

const ENTITY_SCHEMA: { entities: Record<string, RawEntity> } = { entities: {} };

type EntityKey = string;
type EntityRecord = Record<string, any>;

type EntityDOM = {
  navButton: HTMLButtonElement;
  section: HTMLElement;
  addButton: HTMLButtonElement;
  listControls: HTMLElement;
  queryPanel: HTMLDetailsElement;
  listStateBar: HTMLElement;
  listStateChips: HTMLElement;
  listError: HTMLElement;
  viewSelect: HTMLSelectElement;
  viewNameInput: HTMLInputElement;
  saveViewButton: HTMLButtonElement;
  deleteViewButton: HTMLButtonElement;
  filtersHost: HTMLElement;
  addFilterButton: HTMLButtonElement;
  filterLogicSelect: HTMLSelectElement;
  groupLogicSelect: HTMLSelectElement;
  sortsHost: HTMLElement;
  addSortButton: HTMLButtonElement;
  applyFiltersButton: HTMLButtonElement;
  clearFiltersButton: HTMLButtonElement;
  pageInfo: HTMLElement;
  prevPageButton: HTMLButtonElement;
  nextPageButton: HTMLButtonElement;
  pageSizeSelect: HTMLSelectElement;
  columnPickerToggle: HTMLButtonElement;
  columnPickerPanel: HTMLElement;
  tableHeadRow: HTMLTableRowElement;
  formContainer: HTMLElement;
  tableWrap: HTMLElement;
  tableBody: HTMLTableSectionElement;
};

type EntityListState = {
  filters: Array<{ field: string; operator: string; value: string; group: number }>;
  filterLogic: 'AND' | 'OR';
  groupLogic: 'AND' | 'OR';
  sorts: Array<{ field: string; direction: 'ASC' | 'DESC' }>;
  page: number;
  pageSize: number;
  visibleColumns: string[];
};

type SavedListView = {
  name: string;
  state: EntityListState;
};

type SchemaStudioColumnRow = {
  originalColumnName: string;
  columnName: string;
  dataType: string;
  labelEs: string;
  labelEn: string;
  nullable: boolean;
  primaryKey: boolean;
  primaryKeyPosition: number;
};

type SchemaStudioForeignKeyRow = {
  constraintName: string;
  columnsCsv: string;
  referencedTable: string;
  referencedColumnsCsv: string;
  onUpdateAction: string;
  onDeleteAction: string;
};

type SchemaStudioIndexRow = {
  indexName: string;
  columnsCsv: string;
  isUnique: boolean;
};

type SchemaStudioDOM = {
  navButton: HTMLButtonElement;
  section: HTMLElement;
  entitySelect: HTMLSelectElement;
  rowsHost: HTMLElement;
  addColumnButton: HTMLButtonElement;
  foreignKeysHost: HTMLElement;
  addForeignKeyButton: HTMLButtonElement;
  indexesHost: HTMLElement;
  addIndexButton: HTMLButtonElement;
  reloadButton: HTMLButtonElement;
  saveButton: HTMLButtonElement;
  messageBox: HTMLElement;
};

type SchemaStudioState = {
  selectedEntity: string;
  availableEntities: string[];
  dataTypes: string[];
  referencedTables: string[];
  originalColumns: SchemaStudioColumnRow[];
  originalForeignKeys: SchemaStudioForeignKeyRow[];
  originalIndexes: SchemaStudioIndexRow[];
};

type EntityListMeta = {
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
};

const loadedEntityKeys: EntityKey[] = [];
const entityDomElements = {} as Record<EntityKey, EntityDOM>;
const entityListState = {} as Record<EntityKey, EntityListState>;
const entityListMeta = {} as Record<EntityKey, EntityListMeta>;
const entityLastRecords = {} as Record<EntityKey, EntityRecord[]>;
const LIST_VIEWS_STORAGE_KEY = 'aida26:list-views:v1';
const COLUMN_VISIBILITY_STORAGE_KEY = 'aida26:visible-columns:v1';
const SCHEMA_STUDIO_KEY = '__schemaStudio';

let schemaStudioDom: SchemaStudioDOM | null = null;
const schemaStudioState: SchemaStudioState = {
  selectedEntity: '',
  availableEntities: [],
  dataTypes: [],
  referencedTables: [],
  originalColumns: [],
  originalForeignKeys: [],
  originalIndexes: [],
};

function formatLocaleText(label: LocaleText): string {
  return `${label.es} / ${label.en}`;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeAttribute(value: string): string {
  return escapeHtml(value);
}

function actionLabel(action: string): string {
  const label = UI_ACTIONS.actionLabels[action];
  return label ? formatLocaleText(label) : action;
}

function formatMessage(message: MessageKey, params?: { value?: number }): string {
  const base = I18N.messages[message];
  if (!base) {
    throw new Error(`Missing i18n message key: ${message}`);
  }

  if (params?.value === undefined) {
    return formatLocaleText(base);
  }
  return `${base.es} ${params.value} / ${base.en} ${params.value}`;
}

function normalizeField(raw: RawFieldSpec): RawFieldObject {
  return raw === true ? {} : raw;
}

function resolveLabel(fieldId: string, raw: RawFieldObject): string {
  const labelKey = raw.labelKey || fieldId;
  const label = UI_METADATA.fieldLabels[labelKey];
  return label ? formatLocaleText(label) : fieldId;
}

function resolveControl(raw: RawFieldObject): FieldControl {
  if (raw.control) {
    return raw.control;
  }
  return raw.optionsKey ? 'select' : 'input';
}

function resolveParser(raw: RawFieldObject): FieldParser {
  if (raw.parser) {
    return raw.parser;
  }

  if (raw.control === 'checkbox') {
    return 'boolean';
  }

  return raw.inputType === 'number' ? 'floatOrNull' : 'string';
}

function resolveOptions(raw: RawFieldObject): ResolvedOption[] {
  if (!raw.optionsKey) {
    return [];
  }
  const options = UI_METADATA.optionSets[raw.optionsKey] || [];
  return options.map(option => ({
    value: option.value,
    label: formatLocaleText(option.label),
  }));
}

function compileField(fieldId: string, rawSpec: RawFieldSpec): CompiledField {
  const raw = normalizeField(rawSpec);
  return {
    id: fieldId,
    label: resolveLabel(fieldId, raw),
    control: resolveControl(raw),
    inputType: raw.inputType || 'text',
    required: !!raw.required,
    readOnlyOnEdit: !!raw.readOnlyOnEdit,
    step: raw.step,
    options: resolveOptions(raw),
    parser: resolveParser(raw),
    min: raw.min,
    max: raw.max,
    pattern: raw.pattern,
  };
}

function buildFieldMarkup(field: CompiledField, value: string, required: string, readOnly: string): string {
  const escapedFieldId = escapeAttribute(field.id);
  const escapedLabel = escapeHtml(field.label);
  const escapedValue = escapeAttribute(value);

  if (field.control === 'select') {
    const options = field.options.map(option => {
      const selected = option.value === value ? 'selected' : '';
      return `<option value="${escapeAttribute(option.value)}" ${selected}>${escapeHtml(option.label)}</option>`;
    }).join('');

    return `
      <div class="form-group">
        <label for="${escapedFieldId}">${escapedLabel}:</label>
        <select id="${escapedFieldId}" ${required}>${options}</select>
      </div>
    `;
  }

  if (field.control === 'textarea') {
    return `
      <div class="form-group">
        <label for="${escapedFieldId}">${escapedLabel}:</label>
        <textarea id="${escapedFieldId}" ${required}>${escapeHtml(value)}</textarea>
      </div>
    `;
  }

  if (field.control === 'checkbox') {
    const checked = value === 'true' ? 'checked' : '';
    return `
      <div class="form-group checkbox-group">
        <label for="${escapedFieldId}">
          <input type="checkbox" id="${escapedFieldId}" ${checked} ${readOnly}>
          ${escapedLabel}
        </label>
      </div>
    `;
  }

  const step = field.step ? `step="${escapeAttribute(field.step)}"` : '';
  const min = field.min !== undefined ? `min="${field.min}"` : '';
  const max = field.max !== undefined ? `max="${field.max}"` : '';

  return `
    <div class="form-group">
      <label for="${escapedFieldId}">${escapedLabel}:</label>
      <input type="${escapeAttribute(field.inputType)}" id="${escapedFieldId}" value="${escapedValue}" ${step} ${min} ${max} ${required} ${readOnly}>
    </div>
  `;
}

function compileEntity(entity: EntityKey): CompiledEntity {
  const raw: RawEntity = ENTITY_SCHEMA.entities[entity];
  const primaryKeyFields = Array.isArray(raw.primaryKeyFields) ? raw.primaryKeyFields : [];

  const ordered = raw.fieldOrder || Object.keys(raw.fields);
  const orderedForm = raw.formOrder || ordered;

  const tableIds = ordered.filter((fieldId: string) => normalizeField(raw.fields[fieldId]).showInTable !== false);
  const formIds = orderedForm.filter((fieldId: string) => normalizeField(raw.fields[fieldId]).showInForm !== false);

  const fieldsById = Object.keys(raw.fields).reduce((acc, fieldId) => {
    acc[fieldId] = compileField(fieldId, raw.fields[fieldId]);
    return acc;
  }, {} as Record<string, CompiledField>);

  const singular = formatLocaleText(raw.names.singular);
  const plural = formatLocaleText(raw.names.plural);

  return {
    key: entity,
    primaryKeyFields,
    foreignKeys: raw.foreignKeys || [],
    foreignKeyDependencies: raw.foreignKeyDependencies || [],
    rowActions: raw.rowActions || [],
    ui: {
      singular,
      plural,
      add: `${actionLabel('add')} ${singular}`,
      edit: `${actionLabel('edit')} ${singular}`,
      update: actionLabel('update'),
      cancel: actionLabel('cancel'),
      actions: actionLabel('actions'),
    },
    tableFields: tableIds.map((fieldId: string) => fieldsById[fieldId]),
    formFields: formIds.map((fieldId: string) => fieldsById[fieldId]),
  };
}

const COMPILED_ENTITIES = {} as Record<EntityKey, CompiledEntity>;

async function loadSchemaFromBackend() {
  const response = await fetch(`${API_BASE}/meta`);
  if (!response.ok) {
    throw new Error(`Unable to load schema metadata (HTTP ${response.status})`);
  }

  const payload = await response.json();
  if (!payload || typeof payload !== 'object' || !payload.entities || !payload.i18n) {
    throw new Error('Invalid metadata payload');
  }

  UI_METADATA.fieldLabels = payload.i18n.fieldLabels || {};
  UI_METADATA.optionSets = payload.i18n.optionSets || {};
  UI_METADATA.foreignKeyOptionRowsByField = payload.i18n.foreignKeyOptionRowsByField || {};
  const payloadMessages = payload.i18n.messages || {};
  I18N.messages = Object.fromEntries(
    Object.entries(payloadMessages)
      .filter(([, message]: [string, any]) => message && typeof message === 'object')
      .map(([messageKey, message]: [string, any]) => [
        messageKey,
        {
          es: String(message.es || ''),
          en: String(message.en || ''),
        },
      ])
  );

  for (const requiredMessageKey of REQUIRED_MESSAGE_KEYS) {
    const requiredMessage = I18N.messages[requiredMessageKey];
    if (!requiredMessage || !requiredMessage.es || !requiredMessage.en) {
      throw new Error(`Missing required i18n message in /api/meta: ${requiredMessageKey}`);
    }
  }

  UI_NAVIGATION.groups = (payload.navigation?.groups || [])
    .filter((group: any) => group && typeof group.key === 'string' && group.label && Array.isArray(group.entities))
    .map((group: any) => ({
      key: String(group.key),
      label: {
        es: String(group.label.es || group.key),
        en: String(group.label.en || group.key),
      },
      entities: group.entities.map((entity: any) => String(entity)),
    }));

  const uiActionLabelsPayload = payload.i18n.uiActionLabels || {};
  UI_ACTIONS.actionLabels = Object.fromEntries(
    Object.entries(uiActionLabelsPayload)
      .filter(([, label]: [string, any]) => label && typeof label === 'object')
      .map(([actionKey, label]: [string, any]) => [
        actionKey,
        {
          es: String(label.es || actionKey),
          en: String(label.en || actionKey),
        },
      ])
  );

  ENTITY_SCHEMA.entities = payload.entities;
}

function initializeCompiledSchema() {
  const allEntityKeys = Object.keys(ENTITY_SCHEMA.entities);
  const orderedFromGroups = UI_NAVIGATION.groups.flatMap(group => group.entities).filter((entity, index, arr) => arr.indexOf(entity) === index);
  const finalOrder = orderedFromGroups.concat(allEntityKeys.filter(entity => !orderedFromGroups.includes(entity)));
  loadedEntityKeys.splice(0, loadedEntityKeys.length, ...finalOrder);

  Object.keys(COMPILED_ENTITIES).forEach(key => {
    delete COMPILED_ENTITIES[key];
  });

  loadedEntityKeys.forEach(entity => {
    COMPILED_ENTITIES[entity] = compileEntity(entity);
  });
}

function getRecordValue(record: EntityRecord | undefined, fieldId: string): string {
  if (!record || record[fieldId] === null || record[fieldId] === undefined) {
    return '';
  }
  return String(record[fieldId]);
}

function getTodayDateInputValue(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function normalizeDateInputValue(value: string): string {
  if (!value) {
    return '';
  }

  const trimmed = value.trim();
  const yyyyMmDdMatch = trimmed.match(/^\d{4}-\d{2}-\d{2}$/);
  if (yyyyMmDdMatch) {
    return trimmed;
  }

  const isoPrefixMatch = trimmed.match(/^(\d{4}-\d{2}-\d{2})/);
  if (isoPrefixMatch) {
    return isoPrefixMatch[1];
  }

  // Keep non-empty unknown formats untouched so validator can reject them explicitly.
  return trimmed;
}

function isValidDateInputValue(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }

  const [year, month, day] = value.split('-').map(part => parseInt(part, 10));
  const candidate = new Date(Date.UTC(year, month - 1, day));
  return candidate.getUTCFullYear() === year
    && candidate.getUTCMonth() === month - 1
    && candidate.getUTCDate() === day;
}

function buildEntityUrl(entity: EntityKey, primaryKeyValues?: string[], listState?: EntityListState): string {
  const base = `${API_BASE}/${entity}`;
  if (!primaryKeyValues || primaryKeyValues.length === 0) {
    if (!listState) {
      return base;
    }

    const params = new URLSearchParams();
    const validFilters = listState.filters
      .map(filter => ({
        field: filter.field.trim(),
        operator: filter.operator.trim(),
        value: filter.value.trim(),
        group: Number.isInteger(filter.group) && filter.group > 0 ? filter.group : 1,
      }))
      .filter(filter => filter.field && filter.operator && filter.value.length > 0);
    const validSorts = listState.sorts
      .map(sort => ({
        field: sort.field.trim(),
        direction: sort.direction === 'DESC' ? 'DESC' : 'ASC',
      }))
      .filter(sort => sort.field);

    if (validFilters.length > 0) {
      params.set('filters', JSON.stringify(validFilters));
      params.set('filterLogic', listState.filterLogic === 'OR' ? 'OR' : 'AND');
      params.set('groupLogic', listState.groupLogic === 'OR' ? 'OR' : 'AND');
    }
    if (validSorts.length > 0) {
      params.set('sorts', JSON.stringify(validSorts));
    }
    params.set('page', String(Math.max(1, listState.page || 1)));
    params.set('pageSize', String(Math.max(1, listState.pageSize || 25)));
    params.set('includeMeta', '1');

    const query = params.toString();
    return query ? `${base}?${query}` : base;
  }

  const token = encodeURIComponent(JSON.stringify(primaryKeyValues.map(value => String(value))));
  return `${base}?pk=${token}`;
}

function getFilterOperatorsForField(field: CompiledField): Array<{ value: string; label: string }> {
  if (field.inputType === 'date') {
    return [
      { value: 'eq', label: 'Es igual / Equals' },
      { value: 'before', label: 'Antes de / Before' },
      { value: 'after', label: 'Despues de / After' },
      { value: 'onOrBefore', label: 'En o antes / On or before' },
      { value: 'onOrAfter', label: 'En o despues / On or after' },
    ];
  }

  if (field.parser === 'boolean') {
    return [{ value: 'eq', label: 'Es igual / Equals' }];
  }

  if (field.parser === 'int' || field.parser === 'intOrNull' || field.parser === 'float' || field.parser === 'floatOrNull') {
    return [
      { value: 'eq', label: 'Es igual / Equals' },
      { value: 'gt', label: 'Mayor que / Greater than' },
      { value: 'gte', label: 'Mayor o igual / Greater or equal' },
      { value: 'lt', label: 'Menor que / Less than' },
      { value: 'lte', label: 'Menor o igual / Less or equal' },
    ];
  }

  return [
    { value: 'contains', label: 'Contiene / Contains' },
    { value: 'eq', label: 'Es igual / Equals' },
    { value: 'startsWith', label: 'Empieza con / Starts with' },
    { value: 'endsWith', label: 'Termina con / Ends with' },
  ];
}

function createDefaultListState(entity: EntityKey): EntityListState {
  const fields = COMPILED_ENTITIES[entity].tableFields.filter(field => !field.id.includes('__'));
  const defaultVisibleColumns = fields.map(field => field.id);
  const defaultFilterField = fields[0]?.id || '';
  const defaultFilterOperators = defaultFilterField
    ? getFilterOperatorsForField(fields[0]).map(operator => operator.value)
    : [];
  const defaultFilterOperator = defaultFilterOperators[0] || 'contains';
  return {
    filters: defaultFilterField ? [{ field: defaultFilterField, operator: defaultFilterOperator, value: '', group: 1 }] : [],
    filterLogic: 'AND',
    groupLogic: 'AND',
    sorts: defaultFilterField ? [{ field: defaultFilterField, direction: 'ASC' }] : [],
    page: 1,
    pageSize: 25,
    visibleColumns: getVisibleColumnsForEntity(entity, defaultVisibleColumns),
  };
}

function cloneListState(entity: EntityKey, state: Partial<EntityListState>): EntityListState {
  const defaults = createDefaultListState(entity);
  const legacyFilter = (state as any).filterField && (state as any).filterOperator
    ? [{
      field: String((state as any).filterField),
      operator: String((state as any).filterOperator),
      value: String((state as any).filterValue || ''),
      group: 1,
    }]
    : defaults.filters;
  const legacySort = (state as any).sortField
    ? [{
      field: String((state as any).sortField),
      direction: String((state as any).sortDirection || 'ASC') === 'DESC' ? 'DESC' as const : 'ASC' as const,
    }]
    : defaults.sorts;
  const parsedFilterLogic: 'AND' | 'OR' = String((state as any).filterLogic || 'AND').toUpperCase() === 'OR' ? 'OR' : 'AND';
  const parsedGroupLogic: 'AND' | 'OR' = String((state as any).groupLogic || 'AND').toUpperCase() === 'OR' ? 'OR' : 'AND';

  return {
    filters: Array.isArray(state.filters)
      ? state.filters.map(filter => ({
        field: String((filter as any).field || ''),
        operator: String((filter as any).operator || ''),
        value: String((filter as any).value ?? ''),
        group: Number.isInteger((filter as any).group) && Number((filter as any).group) > 0 ? Number((filter as any).group) : 1,
      })).filter(filter => filter.field && filter.operator)
      : legacyFilter,
    filterLogic: parsedFilterLogic,
    groupLogic: parsedGroupLogic,
    sorts: Array.isArray(state.sorts)
      ? state.sorts.map(sort => ({
        field: String((sort as any).field || ''),
        direction: (String((sort as any).direction || 'ASC') === 'DESC' ? 'DESC' : 'ASC') as 'ASC' | 'DESC',
      })).filter(sort => sort.field)
      : legacySort,
    page: Number.isInteger(state.page) && Number(state.page) > 0 ? Number(state.page) : defaults.page,
    pageSize: Number.isInteger(state.pageSize) && Number(state.pageSize) > 0 ? Number(state.pageSize) : defaults.pageSize,
    visibleColumns: Array.isArray(state.visibleColumns) && state.visibleColumns.length > 0
      ? state.visibleColumns.filter(columnId => defaults.visibleColumns.includes(columnId))
      : defaults.visibleColumns,
  };
}

function getFieldLabelById(entity: EntityKey, fieldId: string): string {
  const field = COMPILED_ENTITIES[entity].tableFields.find(entry => entry.id === fieldId);
  return field?.label || fieldId;
}

function renderListStateChips(entity: EntityKey) {
  const dom = entityDomElements[entity];
  const state = entityListState[entity];
  const chips: string[] = [];

  state.filters
    .filter(filter => filter.field && filter.operator && filter.value.trim().length > 0)
    .forEach((filter, index) => {
      chips.push(`<span class="state-chip">F${index + 1} [G${filter.group}]: ${escapeHtml(getFieldLabelById(entity, filter.field))} (${escapeHtml(filter.operator)}) = ${escapeHtml(filter.value)}</span>`);
    });
  if (state.filters.length > 1) {
    chips.push(`<span class="state-chip">Dentro de grupo: ${escapeHtml(state.filterLogic)}</span>`);
    chips.push(`<span class="state-chip">Entre grupos: ${escapeHtml(state.groupLogic)}</span>`);
  }

  state.sorts
    .filter(sort => sort.field)
    .forEach((sort, index) => {
      chips.push(`<span class="state-chip">S${index + 1}: ${escapeHtml(getFieldLabelById(entity, sort.field))} ${escapeHtml(sort.direction)}</span>`);
    });

  chips.push(`<span class="state-chip">Pagina: ${state.page}</span>`);
  chips.push(`<span class="state-chip">Tamano: ${state.pageSize}</span>`);

  dom.listStateChips.innerHTML = chips.length > 0
    ? chips.join('')
    : '<span class="state-chip is-muted">Sin filtros activos / No active filters</span>';
}

function renderFilterRows(entity: EntityKey) {
  const dom = entityDomElements[entity];
  const state = entityListState[entity];
  const fields = COMPILED_ENTITIES[entity].tableFields.filter(field => !field.id.includes('__'));

  dom.filtersHost.innerHTML = state.filters.map((filter, index) => {
    const selectedField = fields.find(field => field.id === filter.field) || fields[0];
    const operators = selectedField ? getFilterOperatorsForField(selectedField) : [];
    const fieldOptions = fields
      .map(field => `<option value="${escapeAttribute(field.id)}" ${field.id === filter.field ? 'selected' : ''}>${escapeHtml(field.label)}</option>`)
      .join('');
    const operatorOptions = operators
      .map(operator => `<option value="${escapeAttribute(operator.value)}" ${operator.value === filter.operator ? 'selected' : ''}>${escapeHtml(operator.label)}</option>`)
      .join('');

    return `
      <div class="query-row" data-filter-index="${index}">
        <select data-role="filter-field">${fieldOptions}</select>
        <select data-role="filter-operator">${operatorOptions}</select>
        <input type="text" data-role="filter-value" value="${escapeAttribute(filter.value)}" placeholder="Valor" />
        <input type="number" min="1" step="1" data-role="filter-group" value="${filter.group}">
        <button type="button" data-role="remove-filter">Quitar</button>
      </div>
    `;
  }).join('');

  dom.filtersHost.querySelectorAll<HTMLElement>('.query-row').forEach(row => {
    const index = Number(row.dataset.filterIndex || -1);
    if (index < 0 || !state.filters[index]) {
      return;
    }

    const fieldSelect = row.querySelector<HTMLSelectElement>('[data-role="filter-field"]');
    const operatorSelect = row.querySelector<HTMLSelectElement>('[data-role="filter-operator"]');
    const valueInput = row.querySelector<HTMLInputElement>('[data-role="filter-value"]');
    const groupInput = row.querySelector<HTMLInputElement>('[data-role="filter-group"]');
    const removeButton = row.querySelector<HTMLButtonElement>('[data-role="remove-filter"]');

    fieldSelect?.addEventListener('change', () => {
      const selectedField = fields.find(field => field.id === fieldSelect.value) || fields[0];
      const operators = selectedField ? getFilterOperatorsForField(selectedField) : [];
      state.filters[index].field = selectedField?.id || '';
      state.filters[index].operator = operators[0]?.value || '';
      state.page = 1;
      renderFilterRows(entity);
      renderListStateChips(entity);
    });

    operatorSelect?.addEventListener('change', () => {
      state.filters[index].operator = operatorSelect.value;
      state.page = 1;
      renderListStateChips(entity);
    });

    valueInput?.addEventListener('input', () => {
      state.filters[index].value = valueInput.value;
      state.page = 1;
      renderListStateChips(entity);
    });

    groupInput?.addEventListener('input', () => {
      const parsed = Number(groupInput.value);
      state.filters[index].group = Number.isInteger(parsed) && parsed > 0 ? parsed : 1;
      state.page = 1;
      renderListStateChips(entity);
    });

    removeButton?.addEventListener('click', () => {
      state.filters.splice(index, 1);
      state.page = 1;
      renderFilterRows(entity);
      renderListStateChips(entity);
    });
  });
}

function renderSortRows(entity: EntityKey) {
  const dom = entityDomElements[entity];
  const state = entityListState[entity];
  const fields = COMPILED_ENTITIES[entity].tableFields.filter(field => !field.id.includes('__'));

  dom.sortsHost.innerHTML = state.sorts.map((sort, index) => {
    const fieldOptions = fields
      .map(field => `<option value="${escapeAttribute(field.id)}" ${field.id === sort.field ? 'selected' : ''}>${escapeHtml(field.label)}</option>`)
      .join('');

    return `
      <div class="query-row" data-sort-index="${index}">
        <select data-role="sort-field">${fieldOptions}</select>
        <select data-role="sort-direction">
          <option value="ASC" ${sort.direction === 'ASC' ? 'selected' : ''}>ASC</option>
          <option value="DESC" ${sort.direction === 'DESC' ? 'selected' : ''}>DESC</option>
        </select>
        <button type="button" data-role="remove-sort">Quitar</button>
      </div>
    `;
  }).join('');

  dom.sortsHost.querySelectorAll<HTMLElement>('.query-row').forEach(row => {
    const index = Number(row.dataset.sortIndex || -1);
    if (index < 0 || !state.sorts[index]) {
      return;
    }

    const fieldSelect = row.querySelector<HTMLSelectElement>('[data-role="sort-field"]');
    const directionSelect = row.querySelector<HTMLSelectElement>('[data-role="sort-direction"]');
    const removeButton = row.querySelector<HTMLButtonElement>('[data-role="remove-sort"]');

    fieldSelect?.addEventListener('change', () => {
      state.sorts[index].field = fieldSelect.value;
      state.page = 1;
      renderListStateChips(entity);
    });

    directionSelect?.addEventListener('change', () => {
      state.sorts[index].direction = directionSelect.value === 'DESC' ? 'DESC' : 'ASC';
      state.page = 1;
      renderListStateChips(entity);
    });

    removeButton?.addEventListener('click', () => {
      state.sorts.splice(index, 1);
      state.page = 1;
      renderSortRows(entity);
      renderListStateChips(entity);
    });
  });
}

function renderPaginationStatus(entity: EntityKey) {
  const dom = entityDomElements[entity];
  const meta = entityListMeta[entity];
  const state = entityListState[entity];

  const totalPages = meta?.totalPages || 1;
  const total = meta?.total || 0;
  const currentPage = Math.min(state.page, totalPages);
  dom.pageInfo.textContent = `Pagina ${currentPage}/${totalPages} - ${total} registros`;
  dom.prevPageButton.disabled = currentPage <= 1;
  dom.nextPageButton.disabled = currentPage >= totalPages;
}

function renderColumnPicker(entity: EntityKey) {
  const dom = entityDomElements[entity];
  const state = entityListState[entity];
  const allFields = COMPILED_ENTITIES[entity].tableFields.filter(field => !field.id.includes('__'));

  dom.columnPickerPanel.innerHTML = allFields
    .map(field => {
      const checked = state.visibleColumns.includes(field.id) ? 'checked' : '';
      return `<label><input type="checkbox" value="${escapeAttribute(field.id)}" ${checked}> ${escapeHtml(field.label)}</label>`;
    })
    .join('');

  dom.columnPickerPanel.querySelectorAll<HTMLInputElement>('input[type="checkbox"]').forEach(input => {
    input.addEventListener('change', () => {
      const selected = Array.from(dom.columnPickerPanel.querySelectorAll<HTMLInputElement>('input[type="checkbox"]:checked'))
        .map(checkbox => checkbox.value);

      if (selected.length === 0) {
        input.checked = true;
        return;
      }

      state.visibleColumns = selected;
      setVisibleColumnsForEntity(entity, selected);
      renderEntityTable(entity, entityLastRecords[entity] || []);
      renderListStateChips(entity);
    });
  });
}

function readSavedViewsMap(): Record<string, SavedListView[]> {
  try {
    const raw = localStorage.getItem(LIST_VIEWS_STORAGE_KEY);
    if (!raw) {
      return {};
    }

    const parsed = JSON.parse(raw) as Record<string, SavedListView[]>;
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function writeSavedViewsMap(map: Record<string, SavedListView[]>) {
  localStorage.setItem(LIST_VIEWS_STORAGE_KEY, JSON.stringify(map));
}

function readColumnVisibilityMap(): Record<string, string[]> {
  try {
    const raw = localStorage.getItem(COLUMN_VISIBILITY_STORAGE_KEY);
    if (!raw) {
      return {};
    }

    const parsed = JSON.parse(raw) as Record<string, string[]>;
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function writeColumnVisibilityMap(map: Record<string, string[]>) {
  localStorage.setItem(COLUMN_VISIBILITY_STORAGE_KEY, JSON.stringify(map));
}

function getVisibleColumnsForEntity(entity: EntityKey, allowedColumns: string[]): string[] {
  const map = readColumnVisibilityMap();
  const stored = map[entity];
  if (!Array.isArray(stored) || stored.length === 0) {
    return allowedColumns;
  }

  const normalized = stored.filter(columnName => allowedColumns.includes(columnName));
  return normalized.length > 0 ? normalized : allowedColumns;
}

function setVisibleColumnsForEntity(entity: EntityKey, visibleColumns: string[]) {
  const map = readColumnVisibilityMap();
  map[entity] = visibleColumns;
  writeColumnVisibilityMap(map);
}

function getSavedViewsForEntity(entity: EntityKey): SavedListView[] {
  return readSavedViewsMap()[entity] || [];
}

function setSavedViewsForEntity(entity: EntityKey, views: SavedListView[]) {
  const map = readSavedViewsMap();
  map[entity] = views;
  writeSavedViewsMap(map);
}

function renderSavedViewsSelect(entity: EntityKey) {
  const dom = entityDomElements[entity];
  const views = getSavedViewsForEntity(entity);

  dom.viewSelect.innerHTML = '<option value="">Vista guardada / Saved view</option>'
    + views.map(view => `<option value="${escapeAttribute(view.name)}">${escapeHtml(view.name)}</option>`).join('');
}

function applyListStateToControls(entity: EntityKey) {
  const dom = entityDomElements[entity];
  const state = entityListState[entity];

  dom.pageSizeSelect.value = String(state.pageSize);
  dom.filterLogicSelect.value = state.filterLogic;
  dom.groupLogicSelect.value = state.groupLogic;
  renderFilterRows(entity);
  renderSortRows(entity);
  renderListStateChips(entity);
  renderPaginationStatus(entity);
  renderColumnPicker(entity);
}

function setListError(entity: EntityKey, message: string) {
  const dom = entityDomElements[entity];
  dom.listError.textContent = message;
  dom.listError.style.display = message ? 'block' : 'none';
}

function initializeListState(entity: EntityKey) {
  entityListState[entity] = createDefaultListState(entity);
  entityListMeta[entity] = {
    total: 0,
    page: 1,
    pageSize: entityListState[entity].pageSize,
    totalPages: 1,
  };
}

function resetListState(entity: EntityKey) {
  entityListState[entity] = createDefaultListState(entity);
  applyListStateToControls(entity);
}

function bindListControls(entity: EntityKey) {
  const dom = entityDomElements[entity];
  const getState = () => entityListState[entity];

  dom.addFilterButton.addEventListener('click', () => {
    const state = getState();
    const fields = COMPILED_ENTITIES[entity].tableFields.filter(field => !field.id.includes('__'));
    const firstField = fields[0];
    const firstOperator = firstField ? getFilterOperatorsForField(firstField)[0]?.value || 'contains' : 'contains';
    state.filters.push({ field: firstField?.id || '', operator: firstOperator, value: '', group: 1 });
    state.page = 1;
    renderFilterRows(entity);
    renderListStateChips(entity);
  });

  dom.filterLogicSelect.addEventListener('change', () => {
    const state = getState();
    state.filterLogic = dom.filterLogicSelect.value === 'OR' ? 'OR' : 'AND';
    state.page = 1;
    renderListStateChips(entity);
  });

  dom.groupLogicSelect.addEventListener('change', () => {
    const state = getState();
    state.groupLogic = dom.groupLogicSelect.value === 'OR' ? 'OR' : 'AND';
    state.page = 1;
    renderListStateChips(entity);
  });

  dom.addSortButton.addEventListener('click', () => {
    const state = getState();
    const fields = COMPILED_ENTITIES[entity].tableFields.filter(field => !field.id.includes('__'));
    state.sorts.push({ field: fields[0]?.id || '', direction: 'ASC' });
    state.page = 1;
    renderSortRows(entity);
    renderListStateChips(entity);
  });

  dom.pageSizeSelect.addEventListener('change', () => {
    const state = getState();
    const parsed = Number(dom.pageSizeSelect.value);
    state.pageSize = Number.isInteger(parsed) && parsed > 0 ? parsed : 25;
    state.page = 1;
    loadEntity(entity);
  });

  dom.prevPageButton.addEventListener('click', () => {
    const state = getState();
    if (state.page <= 1) {
      return;
    }
    state.page -= 1;
    loadEntity(entity);
  });

  dom.nextPageButton.addEventListener('click', () => {
    const state = getState();
    const totalPages = entityListMeta[entity]?.totalPages || 1;
    if (state.page >= totalPages) {
      return;
    }
    state.page += 1;
    loadEntity(entity);
  });

  dom.columnPickerToggle.addEventListener('click', () => {
    const isVisible = dom.columnPickerPanel.style.display !== 'none';
    dom.columnPickerPanel.style.display = isVisible ? 'none' : 'grid';
  });

  dom.applyFiltersButton.addEventListener('click', () => {
    const state = getState();
    state.page = 1;
    loadEntity(entity);
  });

  dom.clearFiltersButton.addEventListener('click', () => {
    resetListState(entity);
    setListError(entity, '');
    loadEntity(entity);
  });

  dom.saveViewButton.addEventListener('click', () => {
    const state = getState();
    const viewName = dom.viewNameInput.value.trim();
    if (!viewName) {
      setListError(entity, 'Ingrese un nombre de vista / Enter a view name');
      return;
    }

    const views = getSavedViewsForEntity(entity);
    const stateSnapshot = cloneListState(entity, state);
    const existingIndex = views.findIndex(view => view.name === viewName);
    if (existingIndex >= 0) {
      views[existingIndex] = { name: viewName, state: stateSnapshot };
    } else {
      views.push({ name: viewName, state: stateSnapshot });
    }

    setSavedViewsForEntity(entity, views.sort((left, right) => left.name.localeCompare(right.name)));
    renderSavedViewsSelect(entity);
    dom.viewSelect.value = viewName;
    dom.viewNameInput.value = '';
    setListError(entity, '');
  });

  dom.deleteViewButton.addEventListener('click', () => {
    const selectedName = dom.viewSelect.value;
    if (!selectedName) {
      return;
    }

    const views = getSavedViewsForEntity(entity).filter(view => view.name !== selectedName);
    setSavedViewsForEntity(entity, views);
    renderSavedViewsSelect(entity);
    setListError(entity, '');
  });

  dom.viewSelect.addEventListener('change', () => {
    const selectedName = dom.viewSelect.value;
    if (!selectedName) {
      return;
    }

    const selectedView = getSavedViewsForEntity(entity).find(view => view.name === selectedName);
    if (!selectedView) {
      return;
    }

    entityListState[entity] = cloneListState(entity, selectedView.state);
    applyListStateToControls(entity);
    setListError(entity, '');
    loadEntity(entity);
  });

  renderFilterRows(entity);
  renderSortRows(entity);
  renderListStateChips(entity);
  renderSavedViewsSelect(entity);
}

function getPrimaryKeyValues(record: EntityRecord, entity: EntityKey): string[] {
  const primaryKeyFields = COMPILED_ENTITIES[entity]?.primaryKeyFields || [];
  return primaryKeyFields.map(primaryKeyField => String(record[primaryKeyField] ?? ''));
}

function buildPrimaryKeyToken(record: EntityRecord, entity: EntityKey): string {
  return encodeURIComponent(JSON.stringify(getPrimaryKeyValues(record, entity)));
}

function parseFieldValue(field: CompiledField, rawValue: string): any {
  if (field.inputType === 'date') {
    const normalized = normalizeDateInputValue(rawValue);
    return normalized === '' ? null : normalized;
  }

  switch (field.parser) {
    case 'int':
      return parseInt(rawValue, 10) || 0;
    case 'intOrNull': {
      const parsed = parseInt(rawValue, 10);
      return Number.isNaN(parsed) ? null : parsed;
    }
    case 'float':
      return parseFloat(rawValue) || 0;
    case 'floatOrNull': {
      const parsed = parseFloat(rawValue);
      return Number.isNaN(parsed) ? null : parsed;
    }
    case 'boolean':
      return rawValue === 'true';
    default:
      return rawValue;
  }
}

function buildPayloadFromForm(entity: EntityKey, container: HTMLElement): EntityRecord {
  const payload: EntityRecord = {};
  COMPILED_ENTITIES[entity].formFields.forEach(field => {
    const element = container.querySelector(`#${CSS.escape(field.id)}`) as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement | null;
    if (!element) {
      throw new Error(`Missing form control for field: ${field.id}`);
    }

    const rawValue = field.control === 'checkbox'
      ? String((element as HTMLInputElement).checked)
      : field.inputType === 'date'
        ? normalizeDateInputValue(element.value)
        : element.value;
    payload[field.id] = parseFieldValue(field, rawValue);
  });
  return payload;
}

function validatePayload(entity: EntityKey, payload: EntityRecord): string[] {
  const errors: string[] = [];

  COMPILED_ENTITIES[entity].formFields.forEach(field => {
    const value = payload[field.id];
    const isEmpty = value === '' || value === null || value === undefined;

    if (field.required && isEmpty) {
      errors.push(`${field.label}: ${formatMessage('required')}`);
      return;
    }

    if (isEmpty) {
      return;
    }

    if (typeof value === 'number') {
      if (field.min !== undefined && value < field.min) {
        errors.push(`${field.label}: ${formatMessage('mustBeAtLeast', { value: field.min })}`);
      }
      if (field.max !== undefined && value > field.max) {
        errors.push(`${field.label}: ${formatMessage('mustBeAtMost', { value: field.max })}`);
      }
    }

    if (field.pattern) {
      const regex = new RegExp(field.pattern);
      if (!regex.test(String(value))) {
        errors.push(`${field.label}: ${formatMessage('invalidFormat')}`);
      }
    }

    if (field.inputType === 'date' && !isValidDateInputValue(String(value))) {
      errors.push(`${field.label}: ${formatMessage('invalidFormat')}`);
    }
  });

  return errors;
}

async function fetchJson(url: string, init?: RequestInit): Promise<any> {
  const response = await fetch(url, init);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  if (response.status === 204) {
    return null;
  }

  const contentType = response.headers.get('content-type') || '';
  if (!contentType.includes('application/json')) {
    return null;
  }

  return response.json();
}

async function fetchSchemaStudioEntities(): Promise<Array<{ entityKey: string; tableName: string; labelEs: string; labelEn: string }>> {
  const result = await fetchJson(`${API_BASE}/schema-studio/entities`);
  if (!Array.isArray(result)) {
    return [];
  }

  return result.map((row: any) => ({
    entityKey: String(row.entityKey || ''),
    tableName: String(row.tableName || ''),
    labelEs: String(row.labelEs || row.entityKey || ''),
    labelEn: String(row.labelEn || row.entityKey || ''),
  }));
}

async function fetchSchemaStudioEntityModel(entityKey: string): Promise<any> {
  return fetchJson(`${API_BASE}/schema-studio/${encodeURIComponent(entityKey)}`);
}

async function saveSchemaStudioEntityModel(entityKey: string, payload: any): Promise<any> {
  return fetchJson(`${API_BASE}/schema-studio/${encodeURIComponent(entityKey)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
}

function setSchemaStudioMessage(message: string, isError = false) {
  if (!schemaStudioDom) return;
  schemaStudioDom.messageBox.textContent = message;
  schemaStudioDom.messageBox.className = `studio-message${isError ? ' error' : ''}`;
  schemaStudioDom.messageBox.style.display = message ? 'block' : 'none';
}

function getSchemaStudioDataTypeOptions(selectedType: string): string {
  return schemaStudioState.dataTypes
    .map(dataType => {
      const selected = dataType === selectedType ? 'selected' : '';
      return `<option value="${escapeAttribute(dataType)}" ${selected}>${escapeHtml(dataType)}</option>`;
    })
    .join('');
}

function getSchemaStudioReferencedTableOptions(selectedTable: string): string {
  return schemaStudioState.referencedTables
    .map(tableName => {
      const selected = tableName === selectedTable ? 'selected' : '';
      return `<option value="${escapeAttribute(tableName)}" ${selected}>${escapeHtml(tableName)}</option>`;
    })
    .join('');
}

function getSchemaStudioReferentialActions(): string[] {
  const optionRows = UI_METADATA.optionSets.referentialActions || [];
  const values = optionRows
    .map(row => String(row?.value || '').trim())
    .filter(value => value.length > 0);

  if (values.length === 0) {
    return FALLBACK_REFERENTIAL_ACTIONS;
  }

  return Array.from(new Set(values));
}

function renderSchemaStudioRows(rows: SchemaStudioColumnRow[]) {
  if (!schemaStudioDom) return;

  schemaStudioDom.rowsHost.innerHTML = rows
    .map((row, index) => `
      <div class="studio-row" data-row-index="${index}" data-original-column="${escapeAttribute(row.originalColumnName)}">
        <input class="studio-col-name" placeholder="column_name" value="${escapeAttribute(row.columnName)}">
        <select class="studio-data-type">${getSchemaStudioDataTypeOptions(row.dataType)}</select>
        <input class="studio-label-es" placeholder="label_es" value="${escapeAttribute(row.labelEs)}">
        <input class="studio-label-en" placeholder="label_en" value="${escapeAttribute(row.labelEn)}">
        <label class="studio-flag"><input type="checkbox" class="studio-nullable" ${row.nullable ? 'checked' : ''}>NULL</label>
        <label class="studio-flag"><input type="checkbox" class="studio-pk" ${row.primaryKey ? 'checked' : ''}>PK</label>
        <input class="studio-pk-pos" type="number" min="1" value="${row.primaryKeyPosition || ''}" ${row.primaryKey ? '' : 'disabled'}>
        <button type="button" class="studio-remove-row">Quitar</button>
      </div>
    `)
    .join('');

  schemaStudioDom.rowsHost.querySelectorAll<HTMLButtonElement>('.studio-remove-row').forEach(button => {
    button.addEventListener('click', () => {
      button.closest('.studio-row')?.remove();
    });
  });

  schemaStudioDom.rowsHost.querySelectorAll<HTMLInputElement>('.studio-pk').forEach(checkbox => {
    checkbox.addEventListener('change', () => {
      const row = checkbox.closest('.studio-row');
      const pkPositionInput = row?.querySelector<HTMLInputElement>('.studio-pk-pos');
      if (!pkPositionInput) return;
      pkPositionInput.disabled = !checkbox.checked;
      if (!checkbox.checked) {
        pkPositionInput.value = '';
      } else if (!pkPositionInput.value) {
        pkPositionInput.value = '1';
      }
    });
  });
}

function renderSchemaStudioForeignKeys(rows: SchemaStudioForeignKeyRow[]) {
  if (!schemaStudioDom) return;

  const referentialActions = getSchemaStudioReferentialActions();

  schemaStudioDom.foreignKeysHost.innerHTML = rows
    .map((row, index) => `
      <div class="studio-row" data-fk-index="${index}">
        <input class="studio-fk-name" placeholder="constraint_name" value="${escapeAttribute(row.constraintName)}">
        <input class="studio-fk-columns" placeholder="local cols (csv)" value="${escapeAttribute(row.columnsCsv)}">
        <select class="studio-fk-ref-table">${getSchemaStudioReferencedTableOptions(row.referencedTable)}</select>
        <input class="studio-fk-ref-columns" placeholder="ref cols (csv)" value="${escapeAttribute(row.referencedColumnsCsv)}">
        <select class="studio-fk-on-update">
          ${referentialActions.map(action => `<option value="${action}" ${row.onUpdateAction === action ? 'selected' : ''}>ON UPDATE ${action}</option>`).join('')}
        </select>
        <select class="studio-fk-on-delete">
          ${referentialActions.map(action => `<option value="${action}" ${row.onDeleteAction === action ? 'selected' : ''}>ON DELETE ${action}</option>`).join('')}
        </select>
        <button type="button" class="studio-remove-row">Quitar</button>
      </div>
    `)
    .join('');

  schemaStudioDom.foreignKeysHost.querySelectorAll<HTMLButtonElement>('.studio-remove-row').forEach(button => {
    button.addEventListener('click', () => {
      button.closest('.studio-row')?.remove();
    });
  });
}

function renderSchemaStudioIndexes(rows: SchemaStudioIndexRow[]) {
  if (!schemaStudioDom) return;

  schemaStudioDom.indexesHost.innerHTML = rows
    .map((row, index) => `
      <div class="studio-row" data-index-index="${index}">
        <input class="studio-index-name" placeholder="index_name" value="${escapeAttribute(row.indexName)}">
        <input class="studio-index-columns" placeholder="columns (csv)" value="${escapeAttribute(row.columnsCsv)}">
        <label class="studio-flag"><input type="checkbox" class="studio-index-unique" ${row.isUnique ? 'checked' : ''}>UNIQUE</label>
        <button type="button" class="studio-remove-row">Quitar</button>
      </div>
    `)
    .join('');

  schemaStudioDom.indexesHost.querySelectorAll<HTMLButtonElement>('.studio-remove-row').forEach(button => {
    button.addEventListener('click', () => {
      button.closest('.studio-row')?.remove();
    });
  });
}

function collectSchemaStudioRowsFromDom(): SchemaStudioColumnRow[] {
  if (!schemaStudioDom) return [];

  const rows = Array.from(schemaStudioDom.rowsHost.querySelectorAll<HTMLElement>('.studio-row'));
  return rows.map(row => {
    const columnNameInput = row.querySelector<HTMLInputElement>('.studio-col-name');
    const dataTypeSelect = row.querySelector<HTMLSelectElement>('.studio-data-type');
    const labelEsInput = row.querySelector<HTMLInputElement>('.studio-label-es');
    const labelEnInput = row.querySelector<HTMLInputElement>('.studio-label-en');
    const nullableInput = row.querySelector<HTMLInputElement>('.studio-nullable');
    const pkInput = row.querySelector<HTMLInputElement>('.studio-pk');
    const pkPositionInput = row.querySelector<HTMLInputElement>('.studio-pk-pos');

    return {
      originalColumnName: row.dataset.originalColumn || '',
      columnName: (columnNameInput?.value || '').trim(),
      dataType: dataTypeSelect?.value || '',
      labelEs: (labelEsInput?.value || '').trim(),
      labelEn: (labelEnInput?.value || '').trim(),
      nullable: !!nullableInput?.checked,
      primaryKey: !!pkInput?.checked,
      primaryKeyPosition: pkInput?.checked ? Math.max(1, parseInt(pkPositionInput?.value || '1', 10) || 1) : 0,
    };
  });
}

function collectSchemaStudioForeignKeysFromDom(): SchemaStudioForeignKeyRow[] {
  if (!schemaStudioDom) return [];

  return Array.from(schemaStudioDom.foreignKeysHost.querySelectorAll<HTMLElement>('.studio-row')).map(row => {
    const constraintName = (row.querySelector<HTMLInputElement>('.studio-fk-name')?.value || '').trim();
    const columnsCsv = (row.querySelector<HTMLInputElement>('.studio-fk-columns')?.value || '').trim();
    const referencedTable = (row.querySelector<HTMLSelectElement>('.studio-fk-ref-table')?.value || '').trim();
    const referencedColumnsCsv = (row.querySelector<HTMLInputElement>('.studio-fk-ref-columns')?.value || '').trim();
    const onUpdateAction = (row.querySelector<HTMLSelectElement>('.studio-fk-on-update')?.value || DEFAULT_REFERENTIAL_ACTION).trim();
    const onDeleteAction = (row.querySelector<HTMLSelectElement>('.studio-fk-on-delete')?.value || DEFAULT_REFERENTIAL_ACTION).trim();

    return {
      constraintName,
      columnsCsv,
      referencedTable,
      referencedColumnsCsv,
      onUpdateAction,
      onDeleteAction,
    };
  });
}

function collectSchemaStudioIndexesFromDom(): SchemaStudioIndexRow[] {
  if (!schemaStudioDom) return [];

  return Array.from(schemaStudioDom.indexesHost.querySelectorAll<HTMLElement>('.studio-row')).map(row => {
    const indexName = (row.querySelector<HTMLInputElement>('.studio-index-name')?.value || '').trim();
    const columnsCsv = (row.querySelector<HTMLInputElement>('.studio-index-columns')?.value || '').trim();
    const isUnique = Boolean(row.querySelector<HTMLInputElement>('.studio-index-unique')?.checked);
    return { indexName, columnsCsv, isUnique };
  });
}

async function loadSchemaStudioEntity(entityKey: string) {
  if (!schemaStudioDom || !entityKey) {
    return;
  }

  schemaStudioState.selectedEntity = entityKey;
  setSchemaStudioMessage('Cargando metadata de entidad...');

  const model = await fetchSchemaStudioEntityModel(entityKey);
  schemaStudioState.dataTypes = Array.isArray(model?.dataTypes)
    ? model.dataTypes.map((entry: any) => String(entry))
    : [];
  schemaStudioState.referencedTables = Array.isArray(model?.referencedTables)
    ? model.referencedTables.map((entry: any) => String(entry))
    : [];

  const rows: SchemaStudioColumnRow[] = (Array.isArray(model?.columns) ? model.columns : []).map((row: any) => {
    const columnName = String(row.columnName || row.column_name || '');
    return {
      originalColumnName: String(row.originalColumnName || columnName),
      columnName,
      dataType: String(row.dataType || row.data_type || ''),
      labelEs: String(row.labelEs || row.label_es || columnName),
      labelEn: String(row.labelEn || row.label_en || columnName),
      nullable: Boolean(row.nullable),
      primaryKey: Boolean(row.primaryKey),
      primaryKeyPosition: Number(row.primaryKeyPosition || 0),
    };
  });

  const foreignKeys: SchemaStudioForeignKeyRow[] = (Array.isArray(model?.foreignKeys) ? model.foreignKeys : []).map((row: any) => ({
    constraintName: String(row.constraintName || ''),
    columnsCsv: Array.isArray(row.columns) ? row.columns.map((entry: any) => String(entry)).join(', ') : '',
    referencedTable: String(row.referencedTable || ''),
    referencedColumnsCsv: Array.isArray(row.referencedColumns) ? row.referencedColumns.map((entry: any) => String(entry)).join(', ') : '',
    onUpdateAction: String(row.onUpdateAction || DEFAULT_REFERENTIAL_ACTION),
    onDeleteAction: String(row.onDeleteAction || DEFAULT_REFERENTIAL_ACTION),
  }));

  const indexes: SchemaStudioIndexRow[] = (Array.isArray(model?.indexes) ? model.indexes : []).map((row: any) => ({
    indexName: String(row.indexName || ''),
    columnsCsv: Array.isArray(row.columns) ? row.columns.map((entry: any) => String(entry)).join(', ') : '',
    isUnique: Boolean(row.isUnique),
  }));

  schemaStudioState.originalColumns = rows;
  schemaStudioState.originalForeignKeys = foreignKeys;
  schemaStudioState.originalIndexes = indexes;
  renderSchemaStudioRows(rows);
  renderSchemaStudioForeignKeys(foreignKeys);
  renderSchemaStudioIndexes(indexes);
  setSchemaStudioMessage('');
}

function validateSchemaStudioRows(
  rows: SchemaStudioColumnRow[],
  foreignKeys: SchemaStudioForeignKeyRow[],
  indexes: SchemaStudioIndexRow[]
): string[] {
  const errors: string[] = [];
  if (rows.length === 0) {
    errors.push('Debe existir al menos una columna / At least one column is required');
    return errors;
  }

  const seenColumns = new Set<string>();
  for (const row of rows) {
    if (!row.columnName) {
      errors.push('Hay filas sin nombre de columna / Some rows are missing column_name');
    }
    if (!row.dataType) {
      errors.push(`Tipo de dato faltante para ${row.columnName || '(sin nombre)'}`);
    }
    if (seenColumns.has(row.columnName)) {
      errors.push(`Nombre de columna duplicado: ${row.columnName}`);
    }
    seenColumns.add(row.columnName);
  }

  const pkRows = rows.filter(row => row.primaryKey);
  if (pkRows.length === 0) {
    errors.push('Debe definir al menos una PK / At least one PK column is required');
  }

  const knownColumnNames = new Set(rows.map(row => row.columnName));
  for (const foreignKey of foreignKeys) {
    if (!foreignKey.columnsCsv || !foreignKey.referencedTable || !foreignKey.referencedColumnsCsv) {
      errors.push('FK incompleta: revise columnas locales, tabla y columnas referenciadas');
      continue;
    }

    const localColumns = foreignKey.columnsCsv.split(',').map(entry => entry.trim()).filter(Boolean);
    const referencedColumns = foreignKey.referencedColumnsCsv.split(',').map(entry => entry.trim()).filter(Boolean);
    if (localColumns.length !== referencedColumns.length) {
      errors.push(`FK ${foreignKey.constraintName || '(sin nombre)'} tiene distinta cantidad de columnas locales y referenciadas`);
    }
    for (const localColumn of localColumns) {
      if (!knownColumnNames.has(localColumn)) {
        errors.push(`FK ${foreignKey.constraintName || '(sin nombre)'} usa columna local inexistente: ${localColumn}`);
      }
    }
  }

  for (const indexRow of indexes) {
    if (!indexRow.indexName || !indexRow.columnsCsv) {
      errors.push('Indice incompleto: revise nombre y columnas');
      continue;
    }

    const columns = indexRow.columnsCsv.split(',').map(entry => entry.trim()).filter(Boolean);
    for (const column of columns) {
      if (!knownColumnNames.has(column)) {
        errors.push(`Indice ${indexRow.indexName} usa columna inexistente: ${column}`);
      }
    }
  }

  return errors;
}

async function saveSchemaStudioEntity() {
  if (!schemaStudioDom || !schemaStudioState.selectedEntity) {
    return;
  }

  const entityKey = schemaStudioState.selectedEntity;
  const rows = collectSchemaStudioRowsFromDom();
  const foreignKeys = collectSchemaStudioForeignKeysFromDom();
  const indexes = collectSchemaStudioIndexesFromDom();
  const validationErrors = validateSchemaStudioRows(rows, foreignKeys, indexes);
  if (validationErrors.length > 0) {
    setSchemaStudioMessage(validationErrors.join(' | '), true);
    return;
  }

  setSchemaStudioMessage('Guardando cambios de schema...');

  const oldColumnNames = new Set(schemaStudioState.originalColumns.map(row => row.originalColumnName));
  const newColumnNames = new Set(rows.map(row => row.columnName));
  const droppedColumns = Array.from(oldColumnNames.values()).filter(columnName => !newColumnNames.has(columnName));

  const summaryLines = [
    `Entidad: ${entityKey}`,
    `- Columnas enviadas: ${rows.length}`,
    `- Columnas eliminadas: ${droppedColumns.length}`,
    `- FKs enviadas: ${foreignKeys.length}`,
    `- Indices enviados: ${indexes.length}`,
    '- Se recrean PK/FK/indices de la tabla de forma controlada',
  ];

  if (!confirm(`Resumen de cambios de schema:\n\n${summaryLines.join('\n')}\n\nDesea aplicar estos cambios?`)) {
    setSchemaStudioMessage('Guardado cancelado / Save canceled', true);
    return;
  }

  await saveSchemaStudioEntityModel(entityKey, {
    columns: rows,
    foreignKeys: foreignKeys.map(foreignKey => ({
      constraintName: foreignKey.constraintName,
      columnsCsv: foreignKey.columnsCsv,
      referencedTable: foreignKey.referencedTable,
      referencedColumnsCsv: foreignKey.referencedColumnsCsv,
      onUpdateAction: foreignKey.onUpdateAction,
      onDeleteAction: foreignKey.onDeleteAction,
    })),
    indexes: indexes.map(indexRow => ({
      indexName: indexRow.indexName,
      columnsCsv: indexRow.columnsCsv,
      isUnique: indexRow.isUnique,
    })),
  });

  await loadSchemaStudioEntity(entityKey);
  setSchemaStudioMessage('Schema actualizado correctamente / Schema updated successfully');
}

async function initializeSchemaStudioData() {
  const entityRows = await fetchSchemaStudioEntities();
  schemaStudioState.availableEntities = entityRows.map(row => row.entityKey).filter(Boolean);
}

function resolveFormFieldValue(field: CompiledField, record: EntityRecord | undefined, isEdit: boolean): string {
  if (field.control === 'checkbox') {
    return String(record ? Boolean(record[field.id]) : false);
  }

  const rawValue = getRecordValue(record, field.id);
  const normalizedValue = field.inputType === 'date' ? normalizeDateInputValue(rawValue) : rawValue;

  if (normalizedValue) {
    return normalizedValue;
  }

  if (!isEdit && field.inputType === 'date') {
    return getTodayDateInputValue();
  }

  return '';
}

function buildFormFields(entity: EntityKey, record: EntityRecord | undefined, isEdit: boolean): string {
  return COMPILED_ENTITIES[entity].formFields.map(field => buildFieldMarkup(
    field,
    resolveFormFieldValue(field, record, isEdit),
    field.required ? 'required' : '',
    field.readOnlyOnEdit && isEdit ? 'readonly' : ''
  )).join('');
}

function applyFormFieldValues(entity: EntityKey, container: HTMLElement, record: EntityRecord | undefined, isEdit: boolean) {
  COMPILED_ENTITIES[entity].formFields.forEach(field => {
    const element = Array.from(container.querySelectorAll<HTMLElement>('[id]')).find(candidate => candidate.id === field.id) as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement | undefined;
    if (!element) {
      return;
    }

    if (field.control === 'checkbox') {
      (element as HTMLInputElement).checked = resolveFormFieldValue(field, record, isEdit) === 'true';
    } else {
      element.value = resolveFormFieldValue(field, record, isEdit);
    }
  });
}

function setSelectOptions(selectElement: HTMLSelectElement, options: ResolvedOption[], selectedValue: string) {
  const hasSelectedOption = options.some(option => option.value === selectedValue);
  const initialOption = '<option value=""></option>';
  const renderedOptions = options.map(option => {
    const selected = option.value === selectedValue ? 'selected' : '';
    return `<option value="${escapeAttribute(option.value)}" ${selected}>${escapeHtml(option.label)}</option>`;
  }).join('');

  selectElement.innerHTML = `${initialOption}${renderedOptions}`;
  if (!hasSelectedOption) {
    selectElement.value = '';
  }
}

function deduplicateOptions(options: ResolvedOption[]): ResolvedOption[] {
  const seen = new Set<string>();
  const result: ResolvedOption[] = [];
  for (const option of options) {
    if (seen.has(option.value)) {
      continue;
    }
    seen.add(option.value);
    result.push(option);
  }
  return result;
}

function enableDependentForeignKeyFiltering(entity: EntityKey, container: HTMLElement) {
  const compiled = COMPILED_ENTITIES[entity];
  const foreignKeysByKey = new Map(
    compiled.foreignKeys.map(foreignKey => [foreignKey.foreignKeyKey, foreignKey])
  );

  const bestForeignKeyByField = new Map<string, { foreignKeyKey: string; columnsCount: number }>();
  compiled.foreignKeys.forEach(foreignKey => {
    const columnsCount = foreignKey.columns.length;
    foreignKey.columns.forEach(column => {
      const existing = bestForeignKeyByField.get(column.columnName);
      if (!existing || columnsCount < existing.columnsCount) {
        bestForeignKeyByField.set(column.columnName, {
          foreignKeyKey: foreignKey.foreignKeyKey,
          columnsCount,
        });
      }
    });
  });

  const fieldToForeignKey = new Map<string, { foreignKeyKey: string }>();
  bestForeignKeyByField.forEach((value, fieldId) => {
    fieldToForeignKey.set(fieldId, { foreignKeyKey: value.foreignKeyKey });
  });

  const dependencyByChildForeignKey = new Map(
    compiled.foreignKeyDependencies.map(dependency => [dependency.dependentForeignKeyKey, dependency])
  );

  const resolveFilteredOptions = (fieldId: string): { options: ResolvedOption[]; disabled: boolean } => {
    const fieldKey = `${entity}.${fieldId}`;
    const rawOptions = UI_METADATA.foreignKeyOptionRowsByField[fieldKey];
    const fallbackOptions = COMPILED_ENTITIES[entity].formFields.find(field => field.id === fieldId)?.options || [];
    const fieldForeignKey = fieldToForeignKey.get(fieldId);

    if (!rawOptions || !fieldForeignKey) {
      return { options: deduplicateOptions(fallbackOptions), disabled: false };
    }

    const dependency = dependencyByChildForeignKey.get(fieldForeignKey.foreignKeyKey);
    if (!dependency) {
      return {
        options: deduplicateOptions(rawOptions.map(option => ({ value: option.value, label: formatLocaleText(option.label) }))),
        disabled: false,
      };
    }

    const requiredForeignKey = foreignKeysByKey.get(dependency.requiredForeignKeyKey);
    const dependentForeignKey = foreignKeysByKey.get(dependency.dependentForeignKeyKey);
    if (!requiredForeignKey || !dependentForeignKey) {
      return {
        options: deduplicateOptions(rawOptions.map(option => ({ value: option.value, label: formatLocaleText(option.label) }))),
        disabled: false,
      };
    }

    const requiredSelectionsByLocalColumn = new Map<string, string>();
    for (const requiredColumn of requiredForeignKey.columns) {
      const requiredElement = container.querySelector(`#${CSS.escape(requiredColumn.columnName)}`) as HTMLSelectElement | null;
      requiredSelectionsByLocalColumn.set(requiredColumn.columnName, requiredElement?.value || '');
    }

    if (dependency.mappings.some(mapping => !requiredSelectionsByLocalColumn.get(mapping.sharedLocalColumnName))) {
      return { options: [], disabled: true };
    }

    const dependentReferencedByLocalColumn = new Map(
      dependentForeignKey.columns.map(column => [column.columnName, column.referencedColumnName])
    );

    const filtered = rawOptions.filter(option => dependency.mappings.every(mapping => {
      const dependentReferencedColumn = dependentReferencedByLocalColumn.get(mapping.sharedLocalColumnName);
      if (!dependentReferencedColumn) {
        return false;
      }
      const requiredSelectedValue = requiredSelectionsByLocalColumn.get(mapping.sharedLocalColumnName) || '';
      return option.referencedValues[dependentReferencedColumn] === requiredSelectedValue;
    }));

    return {
      options: deduplicateOptions(filtered.map(option => ({ value: option.value, label: formatLocaleText(option.label) }))),
      disabled: false,
    };
  };

  const refreshForeignKeySelects = () => {
    COMPILED_ENTITIES[entity].formFields
      .filter(field => field.control === 'select')
      .forEach(field => {
        const selectElement = container.querySelector(`#${CSS.escape(field.id)}`) as HTMLSelectElement | null;
        if (!selectElement) {
          return;
        }

        const selectedValue = selectElement.value;
        const { options, disabled } = resolveFilteredOptions(field.id);
        setSelectOptions(selectElement, options, selectedValue);
        selectElement.disabled = disabled;
      });
  };

  COMPILED_ENTITIES[entity].formFields
    .filter(field => field.control === 'select')
    .forEach(field => {
      const selectElement = container.querySelector(`#${CSS.escape(field.id)}`) as HTMLSelectElement | null;
      if (!selectElement) {
        return;
      }

      selectElement.addEventListener('change', refreshForeignKeySelects);
    });

  refreshForeignKeySelects();
}

function formatCellValue(field: CompiledField, value: any): string {
  if (value === null || value === undefined) {
    return '';
  }

  if (field.control === 'checkbox' || typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }

  return String(value);
}

function buildFormTemplate(entity: EntityKey, record: EntityRecord | undefined, isEdit: boolean): string {
  const ui = COMPILED_ENTITIES[entity].ui;
  return `
    <form>
      <h3>${escapeHtml(isEdit ? ui.edit : ui.add)}</h3>
      ${buildFormFields(entity, record, isEdit)}
      <div class="form-actions">
        <button type="submit">${escapeHtml(isEdit ? ui.update : ui.add)}</button>
        <button type="button" class="cancel-btn" data-action="cancel">${escapeHtml(ui.cancel)}</button>
      </div>
    </form>
  `;
}

function renderTableRow(entity: EntityKey, record: EntityRecord): string {
  const visibleColumns = new Set(entityListState[entity].visibleColumns);
  const cells = COMPILED_ENTITIES[entity].tableFields
    .filter(field => visibleColumns.has(field.id))
    .map(field => `<td>${escapeHtml(formatCellValue(field, record[field.id]))}</td>`)
    .join('');
  const primaryKeyToken = buildPrimaryKeyToken(record, entity);
  const rowActions = COMPILED_ENTITIES[entity].rowActions
    .map(action => {
      const targetEntity = String(record[action.targetField] ?? '');
      if (!targetEntity || !COMPILED_ENTITIES[targetEntity]) {
        return '';
      }

      return `<button class="row-action-btn" data-action="${escapeAttribute(action.key)}" data-behavior="${escapeAttribute(action.kind)}" data-target-entity="${escapeAttribute(targetEntity)}">${escapeHtml(actionLabel(action.key))}</button>`;
    })
    .join('');

  return `
    <tr>
      ${cells}
      <td class="actions">
        ${rowActions}
        <button class="edit-btn" data-action="edit" data-pk="${escapeAttribute(primaryKeyToken)}">${escapeHtml(actionLabel('edit'))}</button>
        <button class="delete-btn" data-action="delete" data-pk="${escapeAttribute(primaryKeyToken)}">${escapeHtml(actionLabel('delete'))}</button>
      </td>
    </tr>
  `;
}

function renderEntityTable(entity: EntityKey, records: EntityRecord[]) {
  const dom = entityDomElements[entity];
  const visibleColumns = new Set(entityListState[entity].visibleColumns);

  dom.tableHeadRow.innerHTML = '';
  COMPILED_ENTITIES[entity].tableFields
    .filter(field => visibleColumns.has(field.id))
    .forEach(field => {
      const th = document.createElement('th');
      th.textContent = field.label;
      dom.tableHeadRow.appendChild(th);
    });

  const actionsTh = document.createElement('th');
  actionsTh.textContent = COMPILED_ENTITIES[entity].ui.actions;
  dom.tableHeadRow.appendChild(actionsTh);

  entityDomElements[entity].tableBody.innerHTML = records.map(record => renderTableRow(entity, record)).join('');
}

async function loadEntity(entity: EntityKey) {
  try {
    const response = await fetchJson(buildEntityUrl(entity, undefined, entityListState[entity]));
    const records = Array.isArray(response) ? response : (Array.isArray(response?.rows) ? response.rows : []);
    const page = Number(response?.page || entityListState[entity].page || 1);
    const pageSize = Number(response?.pageSize || entityListState[entity].pageSize || 25);
    const total = Number(response?.total || records.length || 0);
    const totalPages = Math.max(1, Number(response?.totalPages || Math.ceil(total / Math.max(1, pageSize))));

    entityListState[entity].page = Math.min(page, totalPages);
    entityListMeta[entity] = { total, page: entityListState[entity].page, pageSize, totalPages };
    entityLastRecords[entity] = records;

    renderEntityTable(entity, records || []);
    renderPaginationStatus(entity);
    renderListStateChips(entity);
    setListError(entity, '');
  } catch (error) {
    console.error(`Error loading ${entity}:`, error);
    setListError(entity, 'Error al cargar listado / Error loading list');
  }
}

function hideForm(entity: EntityKey) {
  entityDomElements[entity].formContainer.style.display = 'none';
}

function showForm(entity: EntityKey, record?: EntityRecord) {
  const isEdit = !!record;
  const originalPrimaryKeyValues = isEdit && record
    ? COMPILED_ENTITIES[entity].primaryKeyFields.map(primaryKeyField => String(record[primaryKeyField] ?? ''))
    : [];
  const container = entityDomElements[entity].formContainer;
  container.innerHTML = buildFormTemplate(entity, record, isEdit);
  container.style.display = 'block';
  applyFormFieldValues(entity, container, record, isEdit);
  enableDependentForeignKeyFiltering(entity, container);

  const form = container.querySelector('form') as HTMLFormElement;
  const cancelButton = container.querySelector('[data-action="cancel"]') as HTMLButtonElement;

  cancelButton.addEventListener('click', () => hideForm(entity));

  form.addEventListener('submit', async event => {
    event.preventDefault();

    const payload = buildPayloadFromForm(entity, container);
    const validationErrors = validatePayload(entity, payload);
    if (validationErrors.length > 0) {
      alert(`${formatMessage('validationErrors')}\n\n- ${validationErrors.join('\n- ')}`);
      return;
    }

    const url = isEdit ? buildEntityUrl(entity, originalPrimaryKeyValues) : buildEntityUrl(entity);

    try {
      await fetchJson(url, {
        method: isEdit ? 'PUT' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      hideForm(entity);
      await loadEntity(entity);
    } catch (error) {
      console.error(`Error saving ${entity}:`, error);
    }
  });
}

function showSection(entity: EntityKey | typeof SCHEMA_STUDIO_KEY) {
  loadedEntityKeys.forEach(key => {
    entityDomElements[key].section.classList.remove('active');
    entityDomElements[key].navButton.classList.remove('active');
  });

  if (schemaStudioDom) {
    schemaStudioDom.section.classList.remove('active');
    schemaStudioDom.navButton.classList.remove('active');
  }

  if (entity === SCHEMA_STUDIO_KEY) {
    if (schemaStudioDom) {
      schemaStudioDom.section.classList.add('active');
      schemaStudioDom.navButton.classList.add('active');
    }
    return;
  }

  entityDomElements[entity].section.classList.add('active');
  entityDomElements[entity].navButton.classList.add('active');
  loadEntity(entity);
}

function buildSchemaStudioSection(): HTMLElement {
  const section = document.createElement('section');
  section.className = 'section';

  const title = document.createElement('h2');
  title.textContent = 'Schema Studio / Editor Unificado de Esquema';

  const entitySelect = document.createElement('select');
  entitySelect.className = 'studio-entity-select';

  const actionBar = document.createElement('div');
  actionBar.className = 'studio-action-bar';

  const addColumnButton = document.createElement('button');
  addColumnButton.type = 'button';
  addColumnButton.className = 'studio-add-btn';
  addColumnButton.textContent = 'Agregar columna / Add column';

  const addForeignKeyButton = document.createElement('button');
  addForeignKeyButton.type = 'button';
  addForeignKeyButton.className = 'studio-reload-btn';
  addForeignKeyButton.textContent = 'Agregar FK';

  const addIndexButton = document.createElement('button');
  addIndexButton.type = 'button';
  addIndexButton.className = 'studio-reload-btn';
  addIndexButton.textContent = 'Agregar indice';

  const reloadButton = document.createElement('button');
  reloadButton.type = 'button';
  reloadButton.className = 'studio-reload-btn';
  reloadButton.textContent = 'Recargar entidad';

  const saveButton = document.createElement('button');
  saveButton.type = 'button';
  saveButton.className = 'studio-save-btn';
  saveButton.textContent = 'Guardar cambios de schema';

  actionBar.appendChild(addColumnButton);
  actionBar.appendChild(addForeignKeyButton);
  actionBar.appendChild(addIndexButton);
  actionBar.appendChild(reloadButton);
  actionBar.appendChild(saveButton);

  const rowsHost = document.createElement('div');
  rowsHost.className = 'studio-rows-host';

  const foreignKeysHost = document.createElement('div');
  foreignKeysHost.className = 'studio-rows-host';

  const indexesHost = document.createElement('div');
  indexesHost.className = 'studio-rows-host';

  const columnsTitle = document.createElement('h3');
  columnsTitle.textContent = 'Columnas';

  const foreignKeysTitle = document.createElement('h3');
  foreignKeysTitle.textContent = 'Claves foraneas';

  const indexesTitle = document.createElement('h3');
  indexesTitle.textContent = 'Indices';

  const messageBox = document.createElement('div');
  messageBox.className = 'studio-message';
  messageBox.style.display = 'none';

  section.appendChild(title);
  section.appendChild(entitySelect);
  section.appendChild(actionBar);
  section.appendChild(columnsTitle);
  section.appendChild(rowsHost);
  section.appendChild(foreignKeysTitle);
  section.appendChild(foreignKeysHost);
  section.appendChild(indexesTitle);
  section.appendChild(indexesHost);
  section.appendChild(messageBox);

  const navButton = document.createElement('button');
  navButton.textContent = 'Schema Studio / Editor de Esquema';

  schemaStudioDom = {
    navButton,
    section,
    entitySelect,
    rowsHost,
    addColumnButton,
    foreignKeysHost,
    addForeignKeyButton,
    indexesHost,
    addIndexButton,
    reloadButton,
    saveButton,
    messageBox,
  };

  entitySelect.addEventListener('change', () => {
    const selectedEntity = entitySelect.value;
    if (!selectedEntity) {
      renderSchemaStudioRows([]);
      renderSchemaStudioForeignKeys([]);
      renderSchemaStudioIndexes([]);
      return;
    }

    loadSchemaStudioEntity(selectedEntity).catch(error => {
      console.error('Error loading schema studio entity:', error);
      setSchemaStudioMessage('Error al cargar entidad en Schema Studio', true);
    });
  });

  addColumnButton.addEventListener('click', () => {
    const currentRows = collectSchemaStudioRowsFromDom();
    currentRows.push({
      originalColumnName: '',
      columnName: '',
      dataType: schemaStudioState.dataTypes[0] || 'text',
      labelEs: '',
      labelEn: '',
      nullable: false,
      primaryKey: false,
      primaryKeyPosition: 0,
    });
    renderSchemaStudioRows(currentRows);
  });

  addForeignKeyButton.addEventListener('click', () => {
    const currentRows = collectSchemaStudioForeignKeysFromDom();
    currentRows.push({
      constraintName: '',
      columnsCsv: '',
      referencedTable: schemaStudioState.referencedTables[0] || '',
      referencedColumnsCsv: '',
      onUpdateAction: DEFAULT_REFERENTIAL_ACTION,
      onDeleteAction: DEFAULT_REFERENTIAL_ACTION,
    });
    renderSchemaStudioForeignKeys(currentRows);
  });

  addIndexButton.addEventListener('click', () => {
    const currentRows = collectSchemaStudioIndexesFromDom();
    currentRows.push({
      indexName: '',
      columnsCsv: '',
      isUnique: false,
    });
    renderSchemaStudioIndexes(currentRows);
  });

  reloadButton.addEventListener('click', () => {
    if (!schemaStudioState.selectedEntity) {
      return;
    }
    loadSchemaStudioEntity(schemaStudioState.selectedEntity).catch(error => {
      console.error('Error reloading schema studio entity:', error);
      setSchemaStudioMessage('Error al recargar entidad', true);
    });
  });

  saveButton.addEventListener('click', () => {
    saveSchemaStudioEntity().catch(error => {
      console.error('Error saving schema studio entity:', error);
      setSchemaStudioMessage('Error al guardar schema', true);
    });
  });

  return section;
}

async function editEntity(entity: EntityKey, primaryKeyToken: string) {
  try {
    const record = await fetchJson(`${API_BASE}/${entity}?pk=${primaryKeyToken}`);

    if (!record || typeof record !== 'object' || Array.isArray(record)) {
      throw new Error('Invalid record payload');
    }

    showForm(entity, record);
  } catch (error) {
    console.error(`Error loading ${entity} for edit:`, error);
  }
}

async function deleteEntity(entity: EntityKey, primaryKeyToken: string) {
  if (!confirm(formatMessage('deleteConfirm'))) {
    return;
  }

  try {
    await fetchJson(`${API_BASE}/${entity}?pk=${primaryKeyToken}`, { method: 'DELETE' });
    await loadEntity(entity);
  } catch (error) {
    console.error(`Error deleting ${entity}:`, error);
  }
}

function handleTableAction(entity: EntityKey, action: string, primaryKeyToken: string, targetEntity?: string, behavior?: string) {
  if (behavior === 'openEntityFromField' && targetEntity) {
    if (targetEntity && COMPILED_ENTITIES[targetEntity]) {
      showSection(targetEntity);
    }
    return;
  }

  if (action === 'edit') {
    editEntity(entity, primaryKeyToken);
    return;
  }

  if (action === 'delete') {
    deleteEntity(entity, primaryKeyToken);
  }
}

function buildEntitySection(entity: EntityKey): HTMLElement {
  const ui = COMPILED_ENTITIES[entity].ui;

  const section = document.createElement('section');
  section.className = 'section';

  const title = document.createElement('h2');
  title.textContent = ui.plural;

  const addButton = document.createElement('button');
  addButton.className = 'add-btn';
  addButton.textContent = ui.add;

  const listControls = document.createElement('div');
  listControls.className = 'list-controls';

  const baseTableFields = COMPILED_ENTITIES[entity].tableFields.filter(field => !field.id.includes('__'));

  const queryPanel = document.createElement('details');
  queryPanel.className = 'query-panel';
  queryPanel.open = false;

  const querySummary = document.createElement('summary');
  querySummary.textContent = 'Filtros / Orden / Vistas';

  const filtersBlock = document.createElement('div');
  filtersBlock.className = 'query-block';
  const filtersTitle = document.createElement('div');
  filtersTitle.className = 'query-block-title';
  filtersTitle.textContent = 'Filtros';
  const addFilterButton = document.createElement('button');
  addFilterButton.type = 'button';
  addFilterButton.textContent = '+ Filtro';
  const filterLogicSelect = document.createElement('select');
  filterLogicSelect.className = 'filter-logic-select';
  filterLogicSelect.innerHTML = `
    <option value="AND">AND</option>
    <option value="OR">OR</option>
  `;
  const groupLogicSelect = document.createElement('select');
  groupLogicSelect.className = 'filter-logic-select';
  groupLogicSelect.innerHTML = `
    <option value="AND">Grupos: AND</option>
    <option value="OR">Grupos: OR</option>
  `;
  const filtersHost = document.createElement('div');
  filtersHost.className = 'query-rows-host';
  filtersBlock.appendChild(filtersTitle);
  filtersBlock.appendChild(addFilterButton);
  filtersBlock.appendChild(filterLogicSelect);
  filtersBlock.appendChild(groupLogicSelect);
  filtersBlock.appendChild(filtersHost);

  const sortsBlock = document.createElement('div');
  sortsBlock.className = 'query-block';
  const sortsTitle = document.createElement('div');
  sortsTitle.className = 'query-block-title';
  sortsTitle.textContent = 'Orden';
  const addSortButton = document.createElement('button');
  addSortButton.type = 'button';
  addSortButton.textContent = '+ Orden';
  const sortsHost = document.createElement('div');
  sortsHost.className = 'query-rows-host';
  sortsBlock.appendChild(sortsTitle);
  sortsBlock.appendChild(addSortButton);
  sortsBlock.appendChild(sortsHost);

  const applyFiltersButton = document.createElement('button');
  applyFiltersButton.type = 'button';
  applyFiltersButton.className = 'apply-btn';
  applyFiltersButton.textContent = 'Aplicar / Apply';

  const clearFiltersButton = document.createElement('button');
  clearFiltersButton.type = 'button';
  clearFiltersButton.className = 'clear-btn';
  clearFiltersButton.textContent = 'Limpiar / Clear';

  const queryActions = document.createElement('div');
  queryActions.className = 'query-actions';
  queryActions.appendChild(applyFiltersButton);
  queryActions.appendChild(clearFiltersButton);

  const listStateBar = document.createElement('div');
  listStateBar.className = 'list-state-bar';

  const listStateChips = document.createElement('div');
  listStateChips.className = 'state-chips';

  const viewSelect = document.createElement('select');
  viewSelect.className = 'view-select';

  const viewNameInput = document.createElement('input');
  viewNameInput.type = 'text';
  viewNameInput.placeholder = 'Nombre de vista';
  viewNameInput.className = 'view-name-input';

  const saveViewButton = document.createElement('button');
  saveViewButton.type = 'button';
  saveViewButton.className = 'save-view-btn';
  saveViewButton.textContent = 'Guardar vista';

  const deleteViewButton = document.createElement('button');
  deleteViewButton.type = 'button';
  deleteViewButton.className = 'delete-view-btn';
  deleteViewButton.textContent = 'Eliminar vista';

  const pageSizeSelect = document.createElement('select');
  pageSizeSelect.className = 'page-size-select';
  [10, 25, 50, 100].forEach(size => {
    const option = document.createElement('option');
    option.value = String(size);
    option.textContent = `${size} / pagina`;
    pageSizeSelect.appendChild(option);
  });

  const prevPageButton = document.createElement('button');
  prevPageButton.type = 'button';
  prevPageButton.className = 'page-btn';
  prevPageButton.textContent = '<';

  const nextPageButton = document.createElement('button');
  nextPageButton.type = 'button';
  nextPageButton.className = 'page-btn';
  nextPageButton.textContent = '>';

  const pageInfo = document.createElement('div');
  pageInfo.className = 'page-info';

  const columnPickerToggle = document.createElement('button');
  columnPickerToggle.type = 'button';
  columnPickerToggle.className = 'column-picker-toggle';
  columnPickerToggle.textContent = 'Columnas visibles';

  const columnPickerPanel = document.createElement('div');
  columnPickerPanel.className = 'column-picker-panel';
  columnPickerPanel.style.display = 'none';

  const listError = document.createElement('div');
  listError.className = 'list-error';
  listError.style.display = 'none';

  queryPanel.appendChild(querySummary);
  queryPanel.appendChild(filtersBlock);
  queryPanel.appendChild(sortsBlock);
  queryPanel.appendChild(queryActions);
  listControls.appendChild(queryPanel);

  listStateBar.appendChild(listStateChips);
  listStateBar.appendChild(viewSelect);
  listStateBar.appendChild(viewNameInput);
  listStateBar.appendChild(saveViewButton);
  listStateBar.appendChild(deleteViewButton);
  listStateBar.appendChild(pageSizeSelect);
  listStateBar.appendChild(prevPageButton);
  listStateBar.appendChild(nextPageButton);
  listStateBar.appendChild(pageInfo);
  listStateBar.appendChild(columnPickerToggle);
  listStateBar.appendChild(listError);
  listStateBar.appendChild(columnPickerPanel);

  const formContainer = document.createElement('div');
  formContainer.style.display = 'none';

  const tableWrap = document.createElement('div');
  tableWrap.className = 'table-wrap';

  const table = document.createElement('table');
  const thead = document.createElement('thead');
  const headerRow = document.createElement('tr');

  COMPILED_ENTITIES[entity].tableFields.forEach(field => {
    const th = document.createElement('th');
    th.textContent = field.label;
    headerRow.appendChild(th);
  });

  const actionsTh = document.createElement('th');
  actionsTh.textContent = ui.actions;
  headerRow.appendChild(actionsTh);

  thead.appendChild(headerRow);

  const tbody = document.createElement('tbody');
  table.appendChild(thead);
  table.appendChild(tbody);

  section.appendChild(title);
  section.appendChild(addButton);
  section.appendChild(listControls);
  section.appendChild(listStateBar);
  section.appendChild(formContainer);
  tableWrap.appendChild(table);
  section.appendChild(tableWrap);

  entityDomElements[entity] = {
    navButton: document.createElement('button'),
    section,
    addButton,
    listControls,
    queryPanel,
    listStateBar,
    listStateChips,
    listError,
    viewSelect,
    viewNameInput,
    saveViewButton,
    deleteViewButton,
    filtersHost,
    addFilterButton,
    filterLogicSelect,
    groupLogicSelect,
    sortsHost,
    addSortButton,
    applyFiltersButton,
    clearFiltersButton,
    pageInfo,
    prevPageButton,
    nextPageButton,
    pageSizeSelect,
    columnPickerToggle,
    columnPickerPanel,
    tableHeadRow: headerRow,
    formContainer,
    tableWrap,
    tableBody: tbody,
  };

  initializeListState(entity);
  resetListState(entity);
  bindListControls(entity);

  return section;
}

function bootstrapUI() {
  const root = document.getElementById('app-root') as HTMLElement;
  root.innerHTML = '';

  const workspace = document.createElement('div');
  workspace.className = 'workspace-layout';
  root.appendChild(workspace);

  const sidebar = document.createElement('aside');
  sidebar.className = 'sidebar';
  workspace.appendChild(sidebar);

  const content = document.createElement('main');
  content.className = 'content';
  workspace.appendChild(content);

  const nav = document.createElement('nav');
  nav.className = 'nav';
  sidebar.appendChild(nav);

  const sectionsHost = document.createElement('div');
  sectionsHost.className = 'sections-host';
  content.appendChild(sectionsHost);

  const schemaStudioSection = buildSchemaStudioSection();
  sectionsHost.appendChild(schemaStudioSection);
  if (schemaStudioDom) {
    schemaStudioDom.navButton.addEventListener('click', () => showSection(SCHEMA_STUDIO_KEY));
    nav.appendChild(schemaStudioDom.navButton);
  }

  const groups = UI_NAVIGATION.groups;

  loadedEntityKeys.forEach(entity => {
    const section = buildEntitySection(entity);
    sectionsHost.appendChild(section);

    entityDomElements[entity].addButton.addEventListener('click', () => showForm(entity));

    entityDomElements[entity].tableBody.addEventListener('click', event => {
      const target = event.target as HTMLElement;
      if (!(target instanceof HTMLButtonElement)) {
        return;
      }

      const action = target.dataset.action || '';
      const primaryKeyToken = target.dataset.pk || '';
      const targetEntity = target.dataset.targetEntity || '';
      const behavior = target.dataset.behavior || '';
      handleTableAction(entity, action, primaryKeyToken, targetEntity, behavior);
    });
  });

  groups.forEach(group => {
    const groupElement = document.createElement('details');
    groupElement.className = 'nav-group';
    groupElement.open = true;

    const groupSummary = document.createElement('summary');
    groupSummary.className = 'nav-group-title';
    groupSummary.textContent = formatLocaleText(group.label);
    groupElement.appendChild(groupSummary);

    const groupItems = document.createElement('div');
    groupItems.className = 'nav-group-items';

    group.entities
      .filter(entity => !!COMPILED_ENTITIES[entity])
      .forEach(entity => {
        const navButton = document.createElement('button');
        navButton.textContent = COMPILED_ENTITIES[entity].ui.plural;
        navButton.addEventListener('click', () => showSection(entity));
        groupItems.appendChild(navButton);
        entityDomElements[entity].navButton = navButton;
      });

    groupElement.appendChild(groupItems);
    nav.appendChild(groupElement);
  });
}

async function initializeApp() {
  try {
    await loadSchemaFromBackend();
    initializeCompiledSchema();
    await initializeSchemaStudioData();
    bootstrapUI();

    if (schemaStudioDom) {
      schemaStudioDom.entitySelect.innerHTML = schemaStudioState.availableEntities
        .map(entityKey => `<option value="${escapeAttribute(entityKey)}">${escapeHtml(entityKey)}</option>`)
        .join('');

      const firstEntity = schemaStudioState.availableEntities[0] || '';
      schemaStudioDom.entitySelect.value = firstEntity;
      if (firstEntity) {
        await loadSchemaStudioEntity(firstEntity);
      }
    }

    const landingEntity = loadedEntityKeys[0];
    if (landingEntity) {
      showSection(landingEntity);
    }
  } catch (error) {
    console.error('Failed to initialize app metadata:', error);
  }
}

// Initialize
initializeApp();
