[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Installer,

    # Known good installer checksums:
    #   Hotfix 3 (current): `FBE8D7A2367299145C838215C4733CBCC8D7E4DA8F403D731A9AB5B917520625`
    #   Hotfix 2:           `CD334F4DF75B8EB2D8473B77198E1992A90D5D01508327EC7B8B38A5B629A7C6`
    [string]$ExpectedSha256 = 'FBE8D7A2367299145C838215C4733CBCC8D7E4DA8F403D731A9AB5B917520625'
)

$ErrorActionPreference = 'Stop'

$resolvedInstaller = (Resolve-Path -LiteralPath $Installer).Path
$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedInstaller).Hash

Write-Host "File:   $resolvedInstaller"
Write-Host "SHA256: $actualSha256"

if ($actualSha256 -ne $ExpectedSha256) {
    throw "Checksum mismatch. Expected: $ExpectedSha256"
}

Write-Host 'Checksum verified.'
