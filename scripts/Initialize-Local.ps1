[CmdletBinding()]
param([string]$PublicHost)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $repositoryRoot '.env'
$localDirectory = Join-Path $repositoryRoot '.local'
$synapseDirectory = Join-Path $localDirectory 'synapse'

function New-RandomBase64([int]$byteCount) {
    $bytes = New-Object byte[] $byteCount
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
    return [Convert]::ToBase64String($bytes)
}

function New-UrlSecret([int]$byteCount) {
    return (New-RandomBase64 $byteCount).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

if (-not (Test-Path -LiteralPath $environmentFile)) {
    $values = [ordered]@{
        POSTGRES_PASSWORD = New-UrlSecret 30
        OWNERSHIP_KEY_BASE64 = New-RandomBase64 32
        MATRIX_REGISTRATION_SECRET = New-UrlSecret 36
        SYNAPSE_MACAROON_SECRET = New-UrlSecret 36
        SYNAPSE_FORM_SECRET = New-UrlSecret 36
        MODERATOR_API_KEY = New-UrlSecret 32
        VEIL_API_PORT = '8080'
        SYNAPSE_PORT = '8008'
        MATRIX_PUBLIC_HOMESERVER_URL = "http://$(if ($PublicHost) { $PublicHost } else { 'localhost' }):8008"
        POSTGRES_PORT = '5432'
    }
    $lines = $values.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    [IO.File]::WriteAllLines($environmentFile, $lines, [Text.UTF8Encoding]::new($false))
}

$environmentValues = @{}
Get-Content -LiteralPath $environmentFile | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') { $environmentValues[$matches[1]] = $matches[2] }
}

$synapsePort = if ($environmentValues.ContainsKey('SYNAPSE_PORT')) { $environmentValues.SYNAPSE_PORT } else { '8008' }
$desiredPublicURL = "http://$(if ($PublicHost) { $PublicHost } else { 'localhost' }):$synapsePort"
if ($PublicHost -or -not $environmentValues.ContainsKey('MATRIX_PUBLIC_HOMESERVER_URL')) {
    $existingLines = Get-Content -LiteralPath $environmentFile
    if ($existingLines -match '^MATRIX_PUBLIC_HOMESERVER_URL=') {
        $existingLines = $existingLines | ForEach-Object {
            if ($_ -match '^MATRIX_PUBLIC_HOMESERVER_URL=') { "MATRIX_PUBLIC_HOMESERVER_URL=$desiredPublicURL" } else { $_ }
        }
    } else {
        $existingLines += "MATRIX_PUBLIC_HOMESERVER_URL=$desiredPublicURL"
    }
    [IO.File]::WriteAllLines($environmentFile, $existingLines, [Text.UTF8Encoding]::new($false))
    $environmentValues.MATRIX_PUBLIC_HOMESERVER_URL = $desiredPublicURL
}

New-Item -ItemType Directory -Path $synapseDirectory -Force | Out-Null
$template = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'infra\synapse\homeserver.yaml.template')
foreach ($name in @('POSTGRES_PASSWORD', 'MATRIX_REGISTRATION_SECRET', 'SYNAPSE_MACAROON_SECRET', 'SYNAPSE_FORM_SECRET', 'SYNAPSE_PORT')) {
    if (-not $environmentValues.ContainsKey($name)) { throw "Missing $name in .env" }
    $template = $template.Replace("{{$name}}", $environmentValues[$name])
}
[IO.File]::WriteAllText((Join-Path $synapseDirectory 'homeserver.yaml'), $template, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'infra\synapse\log.config') -Destination (Join-Path $synapseDirectory 'log.config') -Force

Write-Host 'Prepared local credentials and Synapse configuration.'
