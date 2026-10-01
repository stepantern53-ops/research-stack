# Start Docker Desktop, wait for daemon, start SearXNG, verify JSON API
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$dockerDesktop = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (-not (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue)) {
    Start-Process $dockerDesktop
}
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    docker ps 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 10
}
if (-not $ready) { Write-Error "Docker daemon not ready after 5 min"; exit 1 }

Push-Location "$root\searxng"
docker compose up -d
Pop-Location
Start-Sleep -Seconds 15
$resp = curl.exe -s "http://localhost:8080/search?q=test&format=json"
if ($resp -match '"results"') { Write-Host "SearXNG OK" } else { Write-Host "SearXNG check failed: $($resp.Substring(0, [Math]::Min(300, $resp.Length)))" }
