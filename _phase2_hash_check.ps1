# READ-ONLY Phase 2 helper: sizes + SHA-256 for candidate duplicates. No deletes.
$ErrorActionPreference = 'Continue'
$paths = @(
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\.venv_musiq_phase4b',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\.venv_waverep_benchmark',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\venv312',
  'C:\Users\Dell\Desktop\access_mobile\.venv',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\.venv_musiq_research',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\.venv_musiq_official',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\.venv_musiq_official_phase1',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\images',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq\extracted',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\official_musiq_engine_verification\cache\tfhub',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\musiq_paq2piq_benchmark\cache',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\musiq_paq2piq_benchmark\_smoke\cache',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\livec\output\run_livec_001\cache',
  'C:\Users\Dell\Desktop\access_mobile\access_backend\ml\univfd',
  'C:\Users\Dell\Desktop\access_mobile\build',
  'C:\Users\Dell\Desktop\access_mobile\.dart_tool'
)
function DirMB($p) {
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  $s = (Get-ChildItem -LiteralPath $p -Recurse -Force -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum
  if ($null -eq $s) { return 0 }
  return [math]::Round($s/1MB, 2)
}
Write-Host '=== DIR SIZES ==='
foreach ($p in $paths) {
  $mb = DirMB $p
  Write-Host ("{0}`t{1}" -f $(if ($null -eq $mb) { 'MISSING' } else { $mb }), $p)
}
$ckpts = @(
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\musiq_paq2piq_benchmark\cache\torch\hub\pyiqa\musiq_paq2piq_ckpt-364c0c84.pth',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\koniq10k\musiq_paq2piq_benchmark\_smoke\cache\torch\hub\pyiqa\musiq_paq2piq_ckpt-364c0c84.pth',
  'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\livec\output\run_livec_001\cache\torch\hub\pyiqa\musiq_paq2piq_ckpt-364c0c84.pth'
)
Write-Host '=== MUSIQ CKPT SHA-256 ==='
foreach ($c in $ckpts) {
  if (Test-Path -LiteralPath $c) {
    $h = Get-FileHash -LiteralPath $c -Algorithm SHA256
    Write-Host ("{0}`t{1}`t{2}" -f $h.Hash, [math]::Round((Get-Item -LiteralPath $c).Length/1MB,2), $c)
  } else {
    Write-Host ("MISSING`t`t{0}" -f $c)
  }
}
Write-Host '=== SPAQ ZIPS ==='
Get-ChildItem -LiteralPath 'C:\Users\Dell\Desktop\access_mobile\tools\quality_validation\workspace\datasets\spaq' -Filter 'SPAQ_Part_*.zip' -EA SilentlyContinue |
  ForEach-Object { Write-Host ("{0}`t{1}" -f ([math]::Round($_.Length/1MB,2)), $_.FullName) }
