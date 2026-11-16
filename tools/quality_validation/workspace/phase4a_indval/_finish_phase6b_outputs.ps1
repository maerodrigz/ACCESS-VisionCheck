# Finish Phase 6B artifacts that require local Python/file concat.
# Safe: does not modify original locked rating or machine-output CSVs.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

# 1) Combined locked ratings (expanded columns via stdlib analyzer)
$py = Join-Path (Split-Path -Parent (Split-Path -Parent $Root)) 'analyze_phase6b_indval_locked_ratings_stdlib.py'
if (-not (Test-Path $py)) {
  $py = Join-Path (Split-Path -Parent $Root) 'analyze_phase6b_indval_locked_ratings_stdlib.py'
}
Write-Host "Running $py"
python $py
if ($LASTEXITCODE -ne 0) { throw "analyzer exit $LASTEXITCODE" }
Write-Host "Done. See phase6b_locked_ratings.csv and phase6b_statistical_analysis/"
