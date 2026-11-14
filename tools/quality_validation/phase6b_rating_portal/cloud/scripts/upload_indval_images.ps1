# Upload blinded INDVAL JPGs to a PRIVATE Supabase Storage bucket.
# Supports:
#   - New Secret API keys: sb_secret_...  (preferred; apikey header only)
#   - Legacy service_role JWT: eyJ...     (apikey + Authorization Bearer)
#
# Does NOT create the Supabase project. Never prints secret values.
#
# Usage:
#   $env:SUPABASE_URL = "https://YOUR_REF.supabase.co"   # NO /rest/v1/
#   $env:SUPABASE_SECRET_KEY = "<sb_secret_...>"         # preferred
#   # OR: $env:SUPABASE_SERVICE_ROLE_KEY = "<legacy JWT>"
#   $env:SUPABASE_STORAGE_BUCKET = "phase6b-indval"
#   .\upload_indval_images.ps1              # real upload
#   .\upload_indval_images.ps1 -DryRun      # validate only, no network upload

[CmdletBinding()]
param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Get-SupabaseSecret {
  $secret = $env:SUPABASE_SECRET_KEY
  if (-not $secret) { $secret = $env:SUPABASE_SERVICE_ROLE_KEY }
  if (-not $secret) {
    throw "Set SUPABASE_SECRET_KEY (sb_secret_...) or legacy SUPABASE_SERVICE_ROLE_KEY first."
  }
  return $secret.Trim()
}

function Normalize-SupabaseBaseUrl([string]$raw) {
  if (-not $raw) {
    throw "Set SUPABASE_URL to the project base URL, e.g. https://YOUR_REF.supabase.co (no /rest/v1/)."
  }
  $u = $raw.Trim().TrimEnd("/")
  # Common mistakes: paste REST or storage path into SUPABASE_URL
  foreach ($suffix in @("/rest/v1", "/storage/v1", "/auth/v1", "/functions/v1")) {
    if ($u.ToLowerInvariant().EndsWith($suffix)) {
      $u = $u.Substring(0, $u.Length - $suffix.Length).TrimEnd("/")
    }
  }
  if ($u -notmatch '^https://[a-z0-9-]+\.supabase\.co$') {
    Write-Warning "SUPABASE_URL looks unusual after normalize: (host redacted). Expected https://<project-ref>.supabase.co"
  }
  return $u
}

function Get-AuthHeaders([string]$secret) {
  # New secret keys are NOT JWTs. Putting them on Authorization: Bearer often yields
  # "Invalid Compact JWS" / Invalid JWT from Storage. Use apikey only for sb_secret_.
  if ($secret.StartsWith("sb_secret_")) {
    return @{
      apikey = $secret
    }
  }
  if ($secret.StartsWith("sb_publishable_")) {
    throw "SUPABASE_SECRET_KEY must be a secret key (sb_secret_...), not a publishable key."
  }
  # Legacy anon/service_role JWTs
  if ($secret.StartsWith("eyJ")) {
    return @{
      apikey = $secret
      Authorization = "Bearer $secret"
    }
  }
  throw "Unrecognized key format. Use sb_secret_... or a legacy service_role JWT (eyJ...)."
}

function Get-KeyKind([string]$secret) {
  if ($secret.StartsWith("sb_secret_")) { return "sb_secret" }
  if ($secret.StartsWith("eyJ")) { return "legacy_jwt" }
  return "unknown"
}

# --- resolve config (never write secrets to output) ---
$secret = Get-SupabaseSecret
$keyKind = Get-KeyKind $secret
$base = Normalize-SupabaseBaseUrl $env:SUPABASE_URL
$Bucket = if ($env:SUPABASE_STORAGE_BUCKET) { $env:SUPABASE_STORAGE_BUCKET.Trim() } else { "phase6b-indval" }
if ($Bucket -ne "phase6b-indval") {
  Write-Warning "Bucket is '$Bucket' (Worker default is phase6b-indval). Continue only if intentional."
}

$Portal = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ImgDir = (Resolve-Path (Join-Path $Portal "..\workspace\phase6a_human_validation\rater_pack\images")).Path
$files = @(Get-ChildItem (Join-Path $ImgDir "INDVAL-*.jpg") | Sort-Object Name)
if ($files.Count -ne 100) {
  throw "Expected 100 INDVAL images, found $($files.Count) in $ImgDir"
}

# Validate exact object key pattern Worker expects: INDVAL-001.jpg … INDVAL-100.jpg
$expected = 1..100 | ForEach-Object { "INDVAL-{0:D3}.jpg" -f $_ }
$names = $files | ForEach-Object { $_.Name }
$missing = @($expected | Where-Object { $_ -notin $names })
$extra = @($names | Where-Object { $_ -notin $expected })
if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
  throw "INDVAL filename set mismatch. missing=$($missing.Count) extra=$($extra.Count)"
}

Write-Output "DryRun=$DryRun"
Write-Output "SUPABASE_URL host OK (path suffixes stripped if present)"
Write-Output "Key kind: $keyKind (value not printed)"
Write-Output "Bucket: $Bucket"
Write-Output "Local images: $($files.Count) at $ImgDir"
Write-Output "Object keys: INDVAL-001.jpg … INDVAL-100.jpg (bucket root)"

if ($DryRun) {
  # Build one sample URI shape without calling the network with the secret.
  $sampleUri = "$base/storage/v1/object/$Bucket/INDVAL-001.jpg"
  Write-Output "Sample upload URI shape: $sampleUri"
  Write-Output "Auth mode: $(if ($keyKind -eq 'sb_secret') { 'apikey header only' } else { 'apikey + Authorization Bearer' })"
  Write-Output "DRY RUN OK — no uploads performed."
  exit 0
}

$headers = Get-AuthHeaders $secret

# Ensure bucket exists (private). Ignore "already exists".
try {
  $bucketBody = (@{ id = $Bucket; name = $Bucket; public = $false } | ConvertTo-Json)
  Invoke-RestMethod -Method POST -Uri "$base/storage/v1/bucket" `
    -Headers ($headers + @{ "Content-Type" = "application/json" }) `
    -Body $bucketBody | Out-Null
  Write-Output "Created bucket $Bucket"
} catch {
  Write-Output "Bucket create skipped/exists (non-fatal)."
}

$n = 0
foreach ($f in $files) {
  if ($f.Name -notmatch '^INDVAL-\d{3}\.jpg$') {
    throw "Unexpected filename: $($f.Name)"
  }
  $uri = "$base/storage/v1/object/$Bucket/$($f.Name)"
  $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
  try {
    Invoke-RestMethod -Method POST -Uri $uri -Headers ($headers + @{
      "Content-Type" = "image/jpeg"
      "x-upsert" = "true"
    }) -Body $bytes | Out-Null
  } catch {
    # Do not echo response bodies that might reflect auth material.
    throw "Upload failed for $($f.Name). Check key kind ($keyKind), bucket privacy, and SUPABASE_URL base (no /rest/v1/)."
  }
  $n++
  if ($n % 10 -eq 0) { Write-Output "Uploaded $n / 100" }
}
Write-Output "Done. Uploaded $n objects to $Bucket (private)."
