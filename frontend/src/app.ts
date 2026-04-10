// Main application file
// Code and comments in English

const API_BASE = '/api';

const DEFAULT_MESSAGES = {
  validationErrors: { es: 'Errores de validacion', en: 'Validation errors' },
  deleteConfirm: { es: 'Esta seguro de que desea eliminar este registro?', en: 'Are you sure you want to delete this record?' },
  required: { es: 'es obligatorio', en: 'is required' },
  invalidFormat: { es: 'formato invalido', en: 'invalid format' },
  mustBeAtLeast: { es: 'debe ser >=', en: 'must be >=' },
  mustBeAtMost: { es: 'debe ser <=', en: 'must be <=' },
} as const;

const I18N: {
  messages: Record<keyof typeof DEFAULT_MESSAGES, LocaleText>;
} = {
  messages: { ...DEFAULT_MESSAGES },
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

type LocaleText = { es: string; en: string };
type FieldControl = 'input' | 'textarea' | 'select' | 'checkbox';
type FieldParser = 'string' | 'int' | 'intOrNull' | 'float' | 'floatOrNull' | 'boolean';
type MessageKey = keyof typeof DEFAULT_MESSAGES;

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
  formContainer: HTMLElement;
  tableWrap: HTMLElement;
  tableBody: HTMLTableSectionElement;
};

const loadedEntityKeys: EntityKey[] = [];
const entityDomElements = {} as Record<EntityKey, EntityDOM>;

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
  (Object.keys(I18N.messages) as MessageKey[]).forEach(messageKey => {
    const message = payloadMessages[messageKey];
    if (!message) {
      return;
    }

    I18N.messages[messageKey] = {
      es: String(message.es || I18N.messages[messageKey].es),
      en: String(message.en || I18N.messages[messageKey].en),
    };
  });

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

  const uiActionsOptions = payload.i18n.optionSets?.uiActions || [];
  UI_ACTIONS.actionLabels = Object.fromEntries(
    uiActionsOptions.map((option: any) => [
      String(option.value),
      {
        es: String(option.label.es || option.value),
        en: String(option.label.en || option.value),
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

function buildEntityUrl(entity: EntityKey, primaryKeyValues?: string[]): string {
  const base = `${API_BASE}/${entity}`;
  if (!primaryKeyValues || primaryKeyValues.length === 0) {
    return base;
  }

  const token = encodeURIComponent(JSON.stringify(primaryKeyValues.map(value => String(value))));
  return `${base}?pk=${token}`;
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
      return;
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
  const cells = COMPILED_ENTITIES[entity].tableFields.map(field => `<td>${escapeHtml(formatCellValue(field, record[field.id]))}</td>`).join('');
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
  entityDomElements[entity].tableBody.innerHTML = records.map(record => renderTableRow(entity, record)).join('');
}

async function loadEntity(entity: EntityKey) {
  try {
    const records = await fetchJson(buildEntityUrl(entity));
    renderEntityTable(entity, records || []);
  } catch (error) {
    console.error(`Error loading ${entity}:`, error);
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

function showSection(entity: EntityKey) {
  loadedEntityKeys.forEach(key => {
    entityDomElements[key].section.classList.remove('active');
    entityDomElements[key].navButton.classList.remove('active');
  });

  entityDomElements[entity].section.classList.add('active');
  entityDomElements[entity].navButton.classList.add('active');
  loadEntity(entity);
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
  section.appendChild(formContainer);
  tableWrap.appendChild(table);
  section.appendChild(tableWrap);

  entityDomElements[entity] = {
    navButton: document.createElement('button'),
    section,
    addButton,
    formContainer,
    tableWrap,
    tableBody: tbody,
  };

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
    bootstrapUI();

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
