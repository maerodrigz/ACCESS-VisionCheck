# Copy local static UI into Cloudflare Pages folder and inject API base placeholder.
$ErrorActionPreference = "Stop"
$Portal = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Src = Join-Path $Portal "static"
$Dst = Join-Path $Portal "cloud\pages"
New-Item -ItemType Directory -Force -Path $Dst | Out-Null
Copy-Item (Join-Path $Src "styles.css") (Join-Path $Dst "styles.css") -Force
Copy-Item (Join-Path $Src "app.js") (Join-Path $Dst "app.js") -Force

$ApiBase = if ($env:PHASE6B_API_BASE) { $env:PHASE6B_API_BASE.TrimEnd("/") } else { "https://YOUR-WORKER.workers.dev" }
$Index = Get-Content (Join-Path $Src "index.html") -Raw -Encoding UTF8
$Inject = @"
  <meta name="api-base" content="$ApiBase" />
  <script>window.PHASE6B_API_BASE = "$ApiBase";</script>
"@
if ($Index -notmatch 'name="api-base"') {
  $Index = $Index -replace "</head>", "$Inject`n</head>"
}
$Index = $Index -replace 'href="/static/styles.css"', 'href="./styles.css"'
$Index = $Index -replace 'src="/static/app.js"', 'src="./app.js"'
Set-Content -Path (Join-Path $Dst "index.html") -Value $Index -Encoding UTF8
Write-Output "Synced Pages assets to $Dst"
Write-Output "API base: $ApiBase"
