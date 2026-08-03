[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Installer
)

$ErrorActionPreference = 'Stop'
$expectedSha256 = 'CD334F4DF75B8EB2D8473B77198E1992A90D5D01508327EC7B8B38A5B629A7C6'

$resolvedInstaller = (Resolve-Path -LiteralPath $Installer).Path
$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedInstaller).Hash

Write-Host "File:   $resolvedInstaller"
Write-Host "SHA256: $actualSha256"

if ($actualSha256 -ne $expectedSha256) {
    throw "Checksum mismatch. Expected: $expectedSha256"
}

Write-Host 'Checksum verified.'
