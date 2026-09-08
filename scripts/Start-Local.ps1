[CmdletBinding()]
param([switch]$SkipBuild, [string]$PublicHost)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ($PublicHost) {
    & (Join-Path $PSScriptRoot 'Initialize-Local.ps1') -PublicHost $PublicHost
} else {
    & (Join-Path $PSScriptRoot 'Initialize-Local.ps1')
}

$arguments = @('compose', '--env-file', (Join-Path $repositoryRoot '.env'), '-f', (Join-Path $repositoryRoot 'infra\docker-compose.yml'), 'up', '-d')
if (-not $SkipBuild) { $arguments += '--build' }
& docker @arguments
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose failed to start.' }

$deadline = [DateTime]::UtcNow.AddMinutes(5)
do {
    try {
        $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/ready' -TimeoutSec 3
        if ($health.status -eq 'ready') {
            Write-Host 'Veil is ready: API http://127.0.0.1:8080, Synapse http://127.0.0.1:8008'
            exit 0
        }
    } catch { Start-Sleep -Seconds 3 }
} while ([DateTime]::UtcNow -lt $deadline)

& docker compose --env-file (Join-Path $repositoryRoot '.env') -f (Join-Path $repositoryRoot 'infra\docker-compose.yml') ps
throw 'The local stack did not become ready within five minutes.'
