# Stop SearXNG containers
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location "$root\searxng"
docker compose stop
Pop-Location
