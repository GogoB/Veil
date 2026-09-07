[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$projectFile = Join-Path $repositoryRoot 'ios\Veil.xcodeproj\project.pbxproj'
$sourceRoot = Join-Path $repositoryRoot 'ios\Veil'
$infoPlist = Join-Path $sourceRoot 'Resources\Info.plist'
$schemeFile = Join-Path $repositoryRoot 'ios\Veil.xcodeproj\xcshareddata\xcschemes\Veil.xcscheme'

if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    throw "Missing Xcode project: $projectFile"
}

$projectText = Get-Content -Raw -LiteralPath $projectFile -Encoding UTF8
$swiftFiles = Get-ChildItem -LiteralPath $sourceRoot -Filter '*.swift' -File -Recurse
$problems = [System.Collections.Generic.List[string]]::new()

$sourceBuildEntries = @(
    [regex]::Matches($projectText, '/\* ([^*]+\.swift) in Sources \*/') |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
)

foreach ($file in $swiftFiles) {
    if (-not ($sourceBuildEntries -contains $file.Name)) {
        $problems.Add("Swift source is not in the Sources phase: $($file.FullName)")
    }
}

foreach ($name in $sourceBuildEntries) {
    if (-not ($swiftFiles.Name -contains $name)) {
        $problems.Add("Xcode project references a missing Swift source: $name")
    }
}

if ($sourceBuildEntries.Count -ne $swiftFiles.Count) {
    $problems.Add("Sources phase has $($sourceBuildEntries.Count) unique Swift files; disk has $($swiftFiles.Count).")
}

[xml](Get-Content -Raw -LiteralPath $infoPlist -Encoding UTF8) | Out-Null
[xml]$scheme = Get-Content -Raw -LiteralPath $schemeFile -Encoding UTF8
if ($scheme.Scheme.BuildAction.BuildActionEntries.BuildActionEntry.BuildableReference.BlueprintIdentifier -ne 'A00000000000000000000200') {
    $problems.Add('The shared Veil scheme does not reference the application target.')
}

$publicModels = Get-Content -Raw -LiteralPath (Join-Path $sourceRoot 'Models\Models.swift') -Encoding UTF8
if ($publicModels -match '(?im)^\s*(let|var)\s+(age|ageBand|birthdate|adultConfirmation)\b') {
    $problems.Add('An age-related property exists in the shared-facing app models.')
}

if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'design\preview')) {
    $problems.Add('The superseded browser prototype still exists.')
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Verified $($swiftFiles.Count) Swift files, Xcode source references, shared scheme, Info.plist XML, and privacy model guard."
if (-not (Get-Command xcodebuild -ErrorAction SilentlyContinue)) {
    Write-Host 'SwiftUI compilation is Mac-only. Run xcodebuild or Xcode on the Mac next.'
}
