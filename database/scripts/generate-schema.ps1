param(
  [string]$OutputPath = "database/schema.generated.sql",
  [string]$ContainerName = "aida26b-db",
  [string]$DatabaseName = "faculty_management"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $projectRoot

try {
  $rawSchema = & docker exec -i $ContainerName pg_dump `
    --schema-only `
    --no-owner `
    --no-privileges `
    --no-comments `
    --no-security-labels `
    --no-tablespaces `
    --quote-all-identifiers `
    -U postgres `
    -d $DatabaseName

  if (-not $rawSchema) {
    throw "No se pudo generar schema con pg_dump"
  }

  $normalized = $rawSchema `
    | Where-Object { $_ -notmatch '^\\restrict\s' } `
    | Where-Object { $_ -notmatch '^\\unrestrict\s' } `
    | Where-Object { $_ -notmatch '^--\s*PostgreSQL database dump' } `
    | Where-Object { $_ -notmatch '^--\s*Dumped from database version' } `
    | Where-Object { $_ -notmatch '^--\s*Dumped by pg_dump version' }

  $header = @(
    "-- Generated file. Do not edit manually.",
    "-- Source of truth: database/migrations/*.sql",
    "-- Regenerate with: ./database/scripts/generate-schema.ps1",
    ""
  )

  $finalContent = @($header + $normalized)
  Set-Content -Path $OutputPath -Value $finalContent -Encoding UTF8

  Write-Host "Schema generado en $OutputPath"
}
finally {
  Pop-Location
}
