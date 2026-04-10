# Sistema de Gestión Académica - Facultad de Ciencias Exactas UBA

Este proyecto implementa un sistema de gestión académica para la Facultad de Ciencias Exactas de la Universidad de Buenos Aires. El sistema permite gestionar alumnos, materias e inscripciones, con el objetivo de automatizar procesos académicos como la identificación de alumnos elegibles para títulos de grado y la generación de certificados.

## Características

- **Gestión de Alumnos**: CRUD completo con número de libreta como identificador único
- **Gestión de Materias**: CRUD con código de materia como identificador
- **Gestión de Inscripciones**: Relación muchos-a-muchos entre alumnos y materias con clave compuesta
- **Interfaz Web**: Grillas interactivas con botones de agregar, editar y eliminar
- **API REST**: Backend en Node.js con TypeScript
- **Base de Datos**: PostgreSQL

## Tecnologías Utilizadas

- **Backend**: Node.js, TypeScript, Express.js
- **Frontend**: Vanilla TypeScript, HTML5, CSS3
- **Base de Datos**: PostgreSQL
- **ORM**: SQL directo con pg library

## Estructura del Proyecto

```
/
├── backend/           # API REST
│   ├── src/
│   │   └── server.ts
│   ├── package.json
│   ├── tsconfig.json
│   └── .env
├── frontend/          # Interfaz web
│   ├── src/
│   │   └── app.ts
│   ├── index.html
│   ├── package.json
│   └── tsconfig.json
├── database/
│   └── schema.sql    # Scripts de base de datos
└── README.md
```

## Instalación y Configuración

### Prerrequisitos

- Node.js (versión 16 o superior)
- PostgreSQL (versión 12 o superior)
- npm o yarn

### Base de Datos

1. Crear una base de datos PostgreSQL llamada `faculty_management`
2. Ejecutar el script `database/schema.sql` para crear las tablas

### Backend

1. Navegar al directorio `backend`
2. Instalar dependencias: `npm install`
3. Configurar variables de entorno en `.env`:
   ```
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=faculty_management
   DB_USER=tu_usuario
   DB_PASSWORD=tu_contraseña
   PORT=3000
   ```
4. Compilar: `npm run build`
4. Ejecutar: `npm start` (servirá en http://localhost:3000)

### Frontend

1. Navegar al directorio `frontend`
2. Instalar dependencias: `npm install`
3. Compilar: `npm run build`
4. Compilar: `npm run build` (compila backend y frontend)
5. Ejecutar: `npm start` (servirá en http://localhost:3000)

### Ejecucion con Docker Compose (recomendado)

1. Copiar variables de entorno base:
   ```bash
   copy .env.example .env
   ```
2. Construir y levantar toda la app (PostgreSQL + backend + frontend servido por backend):
   ```bash
   docker compose up --build
   ```
3. Ejecutar en segundo plano (opcional):
   ```bash
   docker compose up --build -d
   ```
4. Detener servicios:
   ```bash
   docker compose down
   ```
5. Reinicializar base de datos desde cero (reaplica `schema.sql`):
   ```bash
   docker compose down -v
   docker compose up --build
   ```

Si ya tenias un volumen existente y queres habilitar `ON UPDATE CASCADE` sin borrar datos:
```bash
Get-Content .\database\migrations\001_enrollments_on_update_cascade.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
```

Si queres mover metadata de UI al schema de base de datos (labels, option sets y `enrollments_list`):
```bash
Get-Content .\database\migrations\002_db_driven_ui_metadata.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
```

Si queres mover el registro de entidades, claves primarias, claves foraneas y ordenamiento al schema de base de datos:
```bash
Get-Content .\database\migrations\003_db_entity_registry.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
```

Si queres mover las vistas de listado e indices a metadata de base de datos:
```bash
Get-Content .\database\migrations\004_db_list_views_and_indexes.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
```

Si queres poblar dependencias de dropdown entre FKs (tablas `app_entity_foreign_key_dependencies` y `app_entity_foreign_key_dependency_mappings`) desde metadata ya existente:
```bash
Get-Content .\database\migrations\005_fill_foreign_key_dependencies.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
Get-Content .\database\migrations\006_rename_fk_dependency_columns.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
Get-Content .\database\migrations\007_enforce_metadata_labels_not_null.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
Get-Content .\database\migrations\008_limit_structural_sync_triggers.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
Get-Content .\database\migrations\009_metadata_hardening_data_types_and_index_order.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
Get-Content .\database\migrations\010_pk_order_and_data_type_ui_profiles.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
Get-Content .\database\migrations\011_namespaced_physical_indexes.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
Get-Content .\database\migrations\012_ui_messages_and_option_set_definitions.sql | docker compose exec -T db psql -U postgres -d faculty_management -v ON_ERROR_STOP=1
```

### Acceso Manual a la DB como Owner

- El rol owner (`AIDA26_OWNER_USER`) no tiene password ni login.
- Para tareas administrativas manuales, entrar al contenedor como superusuario postgres y cambiar de rol:
  ```bash
  docker compose exec db psql -U postgres -d faculty_management
  SET ROLE aida26_owner;
  ```
- El backend se conecta con el rol de aplicacion (`AIDA26_APP_USER` + `AIDA26_APP_PASSWORD`).

## Uso

1. Ejecutar el backend: `npm start` en el directorio backend (servirá en http://localhost:3000)
2. Abrir el navegador en http://localhost:3000
3. Navegar entre las secciones de Alumnos, Materias e Inscripciones
4. Usar los botones "Agregar" para crear nuevos registros
5. Usar los botones "Editar" y "Eliminar" en cada fila de las grillas

## API Endpoints

### CRUD Generico por Entidad

- `GET /api/meta` - Obtener metadata para frontend (labels, option sets, entidades, campos y configuracion de orden/relaciones)
- `GET /api/:entity` - Listar registros (`students`, `subjects`, `enrollments`)
- `GET /api/:entity/:pk...` - Obtener un registro por clave primaria
- `POST /api/:entity` - Crear registro
- `PUT /api/:entity/:pk...` - Actualizar registro
- `DELETE /api/:entity/:pk...` - Eliminar registro

Notas:

- Para PK compuesta se pasan multiples segmentos de path (ejemplo: `/api/enrollments/1234/MAT101`).
- El `PUT` identifica el registro por la PK original en la URL y permite enviar una PK nueva en el body (correccion de claves).
- En `enrollments`, las FK a `students` y `subjects` usan `ON UPDATE CASCADE`, por lo que cambios de PK en tablas padre se propagan manteniendo consistencia referencial.
- Regla de listado: se muestran todas las columnas de la entidad menos las definidas en `app_entity_hidden_columns`, y luego se agregan solo las columnas referenciadas definidas en `app_shown_referenced_entity_columns`.

### Efecto Operativo de Metadata

Las tablas de metadata no son solo descriptivas: al insertar, actualizar o borrar filas, aplican cambios reales.

- `app_entity_column_nullability`: aplica `SET/DROP NOT NULL` sobre columnas fisicas.
- `app_entity_column_uniqueness`: aplica `ADD/DROP CONSTRAINT UNIQUE` sobre columnas fisicas.
- `app_entity_indexes` y `app_entity_index_columns`: crean, recrean o eliminan indices fisicos.
- `app_entity_foreign_key_groups` y `app_entity_foreign_keys`: crean, recrean o eliminan constraints FK fisicas (incluyendo acciones `ON UPDATE`/`ON DELETE`).

Las tablas de metadata UI (`app_entity_hidden_columns`, `app_shown_referenced_entity_columns`, labels y submenus) impactan en API/frontend de forma dinamica, sin requerir rebuild.

Reglas de seguridad para `app_user`:

- Puede modificar datos de metadata dentro de los limites definidos por triggers de proteccion.
- No puede alterar el schema (se revoca `CREATE` sobre `public`; tampoco es owner de las tablas).
- No puede insertar/actualizar/borrar filas protegidas del catalogo de metadata (por ejemplo entidades `app_*`, acciones y submenus base).

## Desarrollo Futuro

- Implementar autenticación y autorización
- Agregar validaciones más robustas
- Implementar búsqueda y filtros
- Generar reportes y estadísticas
- Automatizar procesos de titulación
- Generar certificados de alumno regular

## Contribución

Este proyecto es parte del sistema académico de la Facultad de Ciencias Exactas. Para contribuciones, por favor contactar al equipo de desarrollo.

## Licencia

Este proyecto es propiedad de la Universidad de Buenos Aires - Facultad de Ciencias Exactas.