#!/bin/sh
set -e

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v owner_user="$AIDA26_OWNER_USER" \
  -v app_user="$AIDA26_APP_USER" \
  -v app_password="$AIDA26_APP_PASSWORD" \
  -f /docker-entrypoint-initdb.d/_schema/schema.sql
