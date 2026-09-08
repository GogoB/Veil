[CmdletBinding()]
param([switch]$RemoveData)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$arguments = @('compose', '--env-file', (Join-Path $repositoryRoot '.env'), '-f', (Join-Path $repositoryRoot 'infra\docker-compose.yml'), 'down')
if ($RemoveData) { $arguments += '--volumes' }
& docker @arguments
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose failed to stop cleanly.' }
