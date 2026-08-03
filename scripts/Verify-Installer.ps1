[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Installer
)

$ErrorActionPreference = 'Stop'
$expectedSha256 = 'FD93BED91FC30086158ECB6CB8EC66B6CFEB9BAEFB0CF516B35B26FB9CA655E5'

$resolvedInstaller = (Resolve-Path -LiteralPath $Installer).Path
$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedInstaller).Hash

Write-Host "File:   $resolvedInstaller"
Write-Host "SHA256: $actualSha256"

if ($actualSha256 -ne $expectedSha256) {
    throw "Checksum mismatch. Expected: $expectedSha256"
}

Write-Host 'Checksum verified.'
