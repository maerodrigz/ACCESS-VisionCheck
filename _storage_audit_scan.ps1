# Read-only storage audit. Does NOT delete/move/modify anything.
$ErrorActionPreference = 'Continue'
$outDir = 'C:\Users\Dell\Desktop\access_mobile'
$report = Join-Path $outDir '_storage_audit_raw.json'
$roots = @(
  'C:\Users\Dell\Desktop\access_mobile',
  'C:\Users\Dell\Desktop\fresh_validation',
  'C:\Users\Dell\Desktop\video_metadata_test'
)

function Get-DirSizeMB([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum).Sum
  if ($null -eq $sum) { return 0 }
  return [math]::Round($sum / 1MB, 2)
}

Write-Host '=== ROOT TOTALS ==='
$rootRows = @()
foreach ($r in $roots) {
  $mb = Get-DirSizeMB $r
  Write-Host ("ROOT {0} = {1} MB" -f $r, $mb)
  $rootRows += [pscustomobject]@{ path = $r; size_mb = $mb }
}

Write-Host '=== TOP-LEVEL CHILDREN (access_mobile) ==='
$children = @()
Get-ChildItem -LiteralPath 'C:\Users\Dell\Desktop\access_mobile' -Force -ErrorAction SilentlyContinue | ForEach-Object {
  $mb = if ($_.PSIsContainer) { Get-DirSizeMB $_.FullName } else { [math]::Round($_.Length / 1MB, 2) }
  $children += [pscustomobject]@{ path = $_.FullName; is_dir = [bool]$_.PSIsContainer; size_mb = $mb }
  Write-Host ("{0}`t{1}`t{2}" -f $mb, $(if ($_.PSIsContainer) { 'DIR' } else { 'FILE' }), $_.FullName)
}
$children = $children | Sort-Object size_mb -Descending

Write-Host '=== NOTABLE SUBFOLDERS ==='
$notable = @(
  'C:\Users\Dell\Desktop\access_mobile\access_backend\uploads',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\ml',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\experiments',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\research_logs',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\phase7d_performance_benchmark',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\phase7e_opencv_profiling',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\phase7f_opencv_blocking_optimization',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\phase7g_musiq_cutover_verification',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\phase7h_video_authenticity_verification',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\phase7i_local_cutover',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\__pycache__',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\.pytest_cache',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\.mypy_cache',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\.ruff_cache',
  'C:\Users\Dell\Desktop\access_mobile\musiq_worker',
  'C:\Users\Dell\Desktop\access_mobile\tools',
  'C:\Users\Dell\Desktop\access_mobile\build',
  'C:\Users\Dell\Desktop\access_mobile\.dart_tool',
  'C:\Users\Dell\Desktop\access_mobile\android\.gradle',
  'C:\Users\Dell\Desktop\access_mobile\android\app\build',
  'C:\Users\Dell\Desktop\access_mobile\admin-web\node_modules',
  'C:\Users\Dell\Desktop\access_mobile\admin-web\dist',
  'C:\Users\Dell\Desktop\fresh_validation',
  'C:\Users\Dell\Desktop\video_metadata_test'
)
$notableRows = @()
foreach ($p in $notable) {
  if (Test-Path -LiteralPath $p) {
    $mb = Get-DirSizeMB $p
    $notableRows += [pscustomobject]@{ path = $p; size_mb = $mb }
    Write-Host ("{0}`t{1}" -f $mb, $p)
  }
}

Write-Host '=== LARGEST FILES under roots (top 40) ==='
$bigFiles = @()
foreach ($r in $roots) {
  if (-not (Test-Path -LiteralPath $r)) { continue }
  Get-ChildItem -LiteralPath $r -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -ge 5MB } |
    ForEach-Object {
      $bigFiles += [pscustomobject]@{
        path = $_.FullName
        size_mb = [math]::Round($_.Length / 1MB, 2)
        ext = $_.Extension.ToLowerInvariant()
      }
    }
}
$bigFiles = $bigFiles | Sort-Object size_mb -Descending | Select-Object -First 40
$bigFiles | ForEach-Object { Write-Host ("{0}`t{1}" -f $_.size_mb, $_.path) }

Write-Host '=== MODEL WEIGHT CANDIDATES ==='
$modelFiles = @()
foreach ($r in $roots) {
  if (-not (Test-Path -LiteralPath $r)) { continue }
  Get-ChildItem -LiteralPath $r -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '\.(pth|pt|ckpt|h5|onnx|pb|safetensors)$' -or $_.Name -match 'weights|checkpoint|efficientnet|dinov2|waverep|univfd|musiq' } |
    ForEach-Object {
      if ($_.Length -ge 1MB) {
        $modelFiles += [pscustomobject]@{
          path = $_.FullName
          size_mb = [math]::Round($_.Length / 1MB, 2)
        }
      }
    }
}
$modelFiles = $modelFiles | Sort-Object size_mb -Descending | Select-Object -First 50
$modelFiles | ForEach-Object { Write-Host ("MODEL {0}`t{1}" -f $_.size_mb, $_.path) }

Write-Host '=== MEDIA COUNTS / SAMPLE HASHES (mp4/jpg/png under fresh_validation + video_metadata_test + tools) ==='
$mediaRoots = @(
  'C:\Users\Dell\Desktop\fresh_validation',
  'C:\Users\Dell\Desktop\video_metadata_test',
  'C:\Users\Dell\Desktop\access_mobile\tools',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\uploads'
)
$hashMap = @{}
$dupGroups = @()
$mediaStats = @()
foreach ($mr in $mediaRoots) {
  if (-not (Test-Path -LiteralPath $mr)) { continue }
  $files = Get-ChildItem -LiteralPath $mr -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '\.(jpg|jpeg|png|mp4|mov|webm|webp)$' }
  $count = ($files | Measure-Object).Count
  $bytes = ($files | Measure-Object Length -Sum).Sum
  $mediaStats += [pscustomobject]@{
    path = $mr
    count = $count
    size_mb = if ($bytes) { [math]::Round($bytes / 1MB, 2) } else { 0 }
  }
  Write-Host ("MEDIA {0} count={1} size_mb={2}" -f $mr, $count, $(if ($bytes) { [math]::Round($bytes / 1MB, 2) } else { 0 }))
  # Hash only files >= 100KB and <= 80MB to keep audit practical
  foreach ($f in $files) {
    if ($f.Length -lt 100KB -or $f.Length -gt 80MB) { continue }
    try {
      $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
      if (-not $hashMap.ContainsKey($h)) { $hashMap[$h] = New-Object System.Collections.Generic.List[string] }
      $hashMap[$h].Add($f.FullName)
    } catch {}
  }
}
foreach ($k in $hashMap.Keys) {
  if ($hashMap[$k].Count -gt 1) {
    $dupGroups += [pscustomobject]@{
      sha256 = $k
      count = $hashMap[$k].Count
      paths = @($hashMap[$k])
      size_mb = [math]::Round(((Get-Item -LiteralPath $hashMap[$k][0]).Length) / 1MB, 2)
    }
  }
}
$dupGroups = $dupGroups | Sort-Object { $_.count * $_.size_mb } -Descending | Select-Object -First 30
Write-Host ("DUPLICATE_GROUPS={0}" -f $dupGroups.Count)

Write-Host '=== DOCKER READ-ONLY ==='
$docker = @{}
try {
  $docker.system_df = (docker system df 2>&1 | Out-String)
  $docker.system_df_v = (docker system df -v 2>&1 | Out-String)
  $docker.images = (docker images --format '{{.Repository}}:{{.Tag}} {{.Size}} {{.ID}}' 2>&1 | Out-String)
  $docker.volumes = (docker volume ls 2>&1 | Out-String)
  $docker.ps = (docker ps -a --format '{{.Names}} {{.Status}} {{.Size}}' 2>&1 | Out-String)
} catch {
  $docker.error = $_.Exception.Message
}
Write-Host $docker.system_df

$payload = [pscustomobject]@{
  generated_at = (Get-Date).ToString('o')
  roots = $rootRows
  children = $children
  notable = $notableRows
  largest_files = $bigFiles
  model_files = $modelFiles
  media_stats = $mediaStats
  duplicate_groups = $dupGroups
  docker = $docker
}
$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host "WROTE $report"
