/* eslint-disable no-console */
const { Client } = require('pg');

const API_BASE = process.env.API_BASE || 'http://localhost:3000/api';
const ENTITY = process.env.SMOKE_ENTITY || 'students';

function encodePk(values) {
  return encodeURIComponent(JSON.stringify(values));
}

async function requestJson(path, init) {
  const response = await fetch(`${API_BASE}${path}`, init);
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`${init?.method || 'GET'} ${path} failed with ${response.status}: ${body}`);
  }

  const text = await response.text();
  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function getDbConfig() {
  return {
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME || 'faculty_management',
    user: process.env.SCHEMA_STUDIO_DB_USER || process.env.DB_USER || 'postgres',
    password: process.env.SCHEMA_STUDIO_DB_PASSWORD || process.env.DB_PASSWORD || 'postgres',
  };
}

async function verifyCount(client, sql, expected, label) {
  const result = await client.query(sql);
  const value = Number(result.rows[0]?.count || 0);
  if (value !== expected) {
    throw new Error(`${label}: expected ${expected}, got ${value}`);
  }
  console.log(`${label}: ${value}`);
}

async function runSchemaMutationCheck(client) {
  const model = await requestJson(`/schema-studio/${encodeURIComponent(ENTITY)}`, { method: 'GET' });
  if (!model || !Array.isArray(model.columns)) {
    throw new Error('Schema Studio model is missing or invalid');
  }

  const timestamp = Date.now();
  const tempColumn = `tmp_smoke_col_${timestamp}`;
  const tempIndex = `idx_smoke_${ENTITY}_${timestamp}`;

  const indexBaseColumn = model.columns.find(column => !column.primaryKey)?.columnName || model.columns[0]?.columnName;
  if (!indexBaseColumn) {
    throw new Error('No available column to build temporary index');
  }

  const patchPayload = {
    columns: [
      ...model.columns,
      {
        originalColumnName: '',
        columnName: tempColumn,
        dataType: 'text',
        labelEs: 'Tmp Smoke',
        labelEn: 'Tmp Smoke',
        nullable: true,
        primaryKey: false,
        primaryKeyPosition: 0,
      },
    ],
    foreignKeys: model.foreignKeys || [],
    indexes: [
      ...(model.indexes || []),
      {
        indexName: tempIndex,
        columns: [indexBaseColumn],
        isUnique: false,
      },
    ],
  };

  console.log('Applying temporary schema mutation...');
  await requestJson(`/schema-studio/${encodeURIComponent(ENTITY)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(patchPayload),
  });

  await verifyCount(
    client,
    `SELECT COUNT(*)::int AS count FROM information_schema.columns WHERE table_schema='public' AND table_name='${ENTITY}' AND column_name='${tempColumn}'`,
    1,
    'temporary column created'
  );
  await verifyCount(
    client,
    `SELECT COUNT(*)::int AS count FROM pg_indexes WHERE schemaname='public' AND tablename='${ENTITY}' AND indexname='${tempIndex}'`,
    1,
    'temporary index created'
  );

  console.log('Restoring original schema model...');
  await requestJson(`/schema-studio/${encodeURIComponent(ENTITY)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      columns: model.columns,
      foreignKeys: model.foreignKeys || [],
      indexes: model.indexes || [],
    }),
  });

  await verifyCount(
    client,
    `SELECT COUNT(*)::int AS count FROM information_schema.columns WHERE table_schema='public' AND table_name='${ENTITY}' AND column_name='${tempColumn}'`,
    0,
    'temporary column restored'
  );
  await verifyCount(
    client,
    `SELECT COUNT(*)::int AS count FROM pg_indexes WHERE schemaname='public' AND tablename='${ENTITY}' AND indexname='${tempIndex}'`,
    0,
    'temporary index restored'
  );
}

async function runCrudCheck(client) {
  const timestamp = Date.now();
  const studentId = `SMK${timestamp}`;
  const pk = encodePk([studentId]);

  console.log('Running CRUD smoke flow...');
  await requestJson('/students', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      numero_libreta: studentId,
      dni: String(7000000 + (timestamp % 1000000)),
      first_name: 'Smoke',
      last_name: 'Test',
      email: `smoke.${timestamp}@example.com`,
      enrollment_date: '2026-04-13',
      status: 'active',
    }),
  });

  await requestJson(`/students?pk=${pk}`, { method: 'GET' });
  await requestJson(`/students?pk=${pk}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ first_name: 'SmokeUpdated' }),
  });
  await requestJson(`/students?pk=${pk}`, { method: 'DELETE' });

  await verifyCount(
    client,
    `SELECT COUNT(*)::int AS count FROM students WHERE numero_libreta='${studentId}'`,
    0,
    'crud row cleaned'
  );
}

async function main() {
  const client = new Client(getDbConfig());
  await client.connect();

  try {
    await runSchemaMutationCheck(client);
    await runCrudCheck(client);
    console.log('Schema Studio smoke test: OK');
  } finally {
    await client.end();
  }
}

main().catch(error => {
  console.error('Schema Studio smoke test failed:', error.message);
  process.exit(1);
});
