$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path "$root\.venv\Scripts\python.exe")) {
    Write-Host "[Vid enc] Creating .venv ..."
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        py -m venv .venv
    } else {
        python -m venv .venv
    }
}
$py = "$root\.venv\Scripts\python.exe"
$pip = "$root\.venv\Scripts\pip.exe"

Write-Host "[Vid enc] Installing requirements ..."
& $pip install -q -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    Write-Host "[Vid enc] pip install failed." -ForegroundColor Red
    exit 1
}

Write-Host "[Vid enc] Upgrading yt-dlp (catches latest YouTube fixes) ..."
& $pip install -q -U yt-dlp
if ($LASTEXITCODE -ne 0) {
    Write-Host "[Vid enc] yt-dlp upgrade failed (continuing with installed version)." -ForegroundColor Yellow
}

$cfCmd = $null
$onPath = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($onPath) {
    $cfCmd = $onPath.Source
} else {
    $localCf = "$root\.tools\cloudflared.exe"
    if (Test-Path $localCf) {
        $cfCmd = $localCf
    } else {
        Write-Host "[Vid enc] cloudflared not found, downloading to .tools\ ..."
        New-Item -ItemType Directory -Force -Path "$root\.tools" | Out-Null
        $cfUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
        try {
            $ProgressPreference = "SilentlyContinue"
            Invoke-WebRequest -Uri $cfUrl -OutFile $localCf -UseBasicParsing
        } catch {
            Write-Host "[Vid enc] Download failed: $_" -ForegroundColor Red
            exit 1
        }
        if (-not (Test-Path $localCf)) {
            Write-Host "[Vid enc] cloudflared download did not produce a file." -ForegroundColor Red
            exit 1
        }
        Write-Host "[Vid enc] Downloaded cloudflared to $localCf"
        $cfCmd = $localCf
    }
}

$flaskLog = "$root\flask.log"
$flaskErr = "$root\flask.err.log"
Remove-Item -Force $flaskLog, $flaskErr -ErrorAction SilentlyContinue

Write-Host "[Vid enc] Starting Flask on http://127.0.0.1:8765 ..."
$flask = Start-Process -FilePath $py `
    -ArgumentList @("-m", "server.app") `
    -WorkingDirectory $root `
    -RedirectStandardOutput $flaskLog `
    -RedirectStandardError $flaskErr `
    -WindowStyle Hidden `
    -PassThru

Start-Sleep -Seconds 2
if ($flask.HasExited) {
    Write-Host "[Vid enc] Flask exited immediately:" -ForegroundColor Red
    if (Test-Path $flaskErr) { Get-Content $flaskErr | Write-Host }
    exit 1
}

$cfOut = "$root\cloudflared.log"
$cfErr = "$root\cloudflared.err.log"
Remove-Item -Force $cfOut, $cfErr -ErrorAction SilentlyContinue

Write-Host "[Vid enc] Starting cloudflared quick tunnel ..."
$cfProc = Start-Process -FilePath $cfCmd `
    -ArgumentList @("tunnel", "--url", "http://127.0.0.1:8765") `
    -RedirectStandardOutput $cfOut `
    -RedirectStandardError $cfErr `
    -WindowStyle Hidden `
    -PassThru

$tunnel = $null
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline -and -not $tunnel) {
    Start-Sleep -Milliseconds 500
    foreach ($file in @($cfOut, $cfErr)) {
        if (Test-Path $file) {
            $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
            if ($content -and ($content -match "https://[a-z0-9-]+\.trycloudflare\.com")) {
                $tunnel = $matches[0]
                break
            }
        }
    }
}

if (-not $tunnel) {
    Write-Host "[Vid enc] Could not parse tunnel URL after 30s. Check $cfErr" -ForegroundColor Red
    Stop-Process -Id $flask.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $cfProc.Id -Force -ErrorAction SilentlyContinue
    exit 1
}

Set-Content -Path "$root\current_tunnel.txt" -Value $tunnel -Encoding utf8

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host " Public URL:  $tunnel" -ForegroundColor Green
Write-Host " (also written to current_tunnel.txt)" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Paste into your executor:"
Write-Host ""
Write-Host "  local TUNNEL = `"$tunnel`""
Write-Host "  local VIDEO  = `"<your video URL>`""
Write-Host "  local HS = game:GetService(`"HttpService`")"
Write-Host "  local res = HS:JSONDecode(game:HttpGet(TUNNEL..`"/encode?url=`"..HS:UrlEncode(VIDEO)))"
Write-Host "  if res.error then error(res.error) end"
Write-Host "  loadstring(game:HttpGet(res.playback_url))()"
Write-Host ""
Write-Host "Press Ctrl+C to stop both processes."
Write-Host ""

try {
    while (-not $flask.HasExited -and -not $cfProc.HasExited) {
        Start-Sleep -Seconds 1
    }
} finally {
    Write-Host "[Vid enc] Stopping ..."
    Stop-Process -Id $flask.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $cfProc.Id -Force -ErrorAction SilentlyContinue
}
