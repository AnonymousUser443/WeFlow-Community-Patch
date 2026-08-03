[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WeFlowRoot
)

$ErrorActionPreference = 'Stop'

$resolvedRoot = (Resolve-Path -LiteralPath $WeFlowRoot).Path
$packagePath = Join-Path $resolvedRoot 'package.json'
if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
    throw "package.json not found under: $resolvedRoot"
}

$package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
if ($package.name -ne 'weflow' -or $package.version -ne '5.0.0') {
    throw "Expected WeFlow 5.0.0, found name='$($package.name)' version='$($package.version)'."
}

$patchPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\patches\weflow-community-hotfix.patch')).Path

& git -C $resolvedRoot apply --check $patchPath
if ($LASTEXITCODE -ne 0) {
    throw 'Patch preflight failed. Ensure the target is a compatible, clean WeFlow 5.0.0 checkout.'
}

& git -C $resolvedRoot apply $patchPath
if ($LASTEXITCODE -ne 0) {
    throw 'Patch application failed.'
}

Write-Host "Patch applied successfully to: $resolvedRoot"
Write-Host 'Next: npm ci; npm run typecheck; npm run build'
