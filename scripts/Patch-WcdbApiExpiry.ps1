[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DllPath,

    [string]$OutputPath,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# =====================================================================================
#  WeFlow wcdb_api.dll  --  build-expiry gate patcher
#
#  The shipped prebuilt wrapper DLL contains TWO hard-coded expiry gates, both keyed to
#  2026-09-30 23:59:59 (UTC for gate 1, local time for gate 2).  Once passed, the DLL
#  refuses to work and the app shows "WeFlow 启动失败 / 错误码: -101".
#
#  Gate 1: InitProtection()   (RVA 0x81970)
#      cmp rax, 0x6ABDA27F   ; 2026-09-30 23:59:59 UTC
#      jle  ok
#      mov  eax, -101
#      ...
#    patch: 0x7E (jle rel8) -> 0xEB (jmp rel8)   => always takes the ok path
#
#  Gate 2: wcdb_init()       (RVA 0xE8E70, gate at RVA 0xE91D7)
#      tm = { sec=59, min=59, hour=23, mday=30, mon=8, year=126 }   ; 2026-09-30 23:59:59 local
#      rbx = _mktime64(&tm)
#      cmp rax, rbx
#      jle  ok
#      ... builds a message ...
#      mov  eax, -1000
#    patch: 0F 8E <rel32> (jle near) -> E9 <rel32> 90 (jmp near + nop) => ok path
#
#  Both patches replace a conditional branch with the same unconditional branch to the
#  identical target, so the resulting behaviour is byte-for-byte the pre-expiry behaviour.
# =====================================================================================

function Find-Pattern {
    param([byte[]]$Haystack, [byte[]]$Needle)
    $hits = New-Object System.Collections.Generic.List[int]
    $limit = $Haystack.Length - $Needle.Length
    for ($i = 0; $i -le $limit; $i++) {
        if ($Haystack[$i] -ne $Needle[0]) { continue }
        $ok = $true
        for ($j = 1; $j -lt $Needle.Length; $j++) {
            if ($Haystack[$i + $j] -ne $Needle[$j]) { $ok = $false; break }
        }
        if ($ok) { $hits.Add($i) }
    }
    return ,$hits
}

# Minimal PE section mapper so file offsets are converted to real RVAs (the .text section
# RVA is not equal to its raw file offset, so the two must not be conflated).
function Get-PeLayout {
    param([byte[]]$Bytes)
    $lfanew = [BitConverter]::ToInt32($Bytes, 0x3C)
    $numSections = [BitConverter]::ToUInt16($Bytes, $lfanew + 6)
    $optSize = [BitConverter]::ToUInt16($Bytes, $lfanew + 20)
    $optOff = $lfanew + 24
    $imageBase = [BitConverter]::ToUInt64($Bytes, $optOff + 24)
    $sections = @()
    $secOff = $optOff + $optSize
    for ($i = 0; $i -lt $numSections; $i++) {
        $o = $secOff + $i * 40
        $sections += [pscustomobject]@{
            Name             = ([System.Text.Encoding]::ASCII.GetString($Bytes, $o, 8)).Trim([char]0)
            VirtualAddress   = [BitConverter]::ToUInt32($Bytes, $o + 12)
            SizeOfRawData    = [BitConverter]::ToUInt32($Bytes, $o + 16)
            PointerToRawData = [BitConverter]::ToUInt32($Bytes, $o + 20)
        }
    }
    return [pscustomobject]@{ ImageBase = $imageBase; Sections = $sections }
}

function Convert-OffsetToRva {
    param([byte[]]$Bytes, [int]$Offset, $Layout)
    foreach ($s in $Layout.Sections) {
        if ($Offset -ge $s.PointerToRawData -and $Offset -lt ($s.PointerToRawData + $s.SizeOfRawData)) {
            return [int]($s.VirtualAddress + ($Offset - $s.PointerToRawData))
        }
    }
    throw ('file offset 0x{0:X} is not inside any section' -f $Offset)
}

function Convert-RvaToOffset {
    param([byte[]]$Bytes, [int]$Rva, $Layout)
    foreach ($s in $Layout.Sections) {
        if ($Rva -ge $s.VirtualAddress -and $Rva -lt ($s.VirtualAddress + $s.SizeOfRawData)) {
            return [int]($s.PointerToRawData + ($Rva - $s.VirtualAddress))
        }
    }
    throw ('rva 0x{0:X} is not inside any section' -f $Rva)
}

$resolved = (Resolve-Path -LiteralPath $DllPath).Path
$bytes = [System.IO.File]::ReadAllBytes($resolved)
Write-Host "Target : $resolved"
Write-Host "Size   : $($bytes.Length) bytes"
Write-Host "SHA256 : $((Get-FileHash -Algorithm SHA256 -LiteralPath $resolved).Hash)"

$out = $bytes.Clone()
$applied = @()
$notes = @()

# ---------------------------------------------------------------- gate 1 -------------
$g1Old = [byte[]](0x48,0x3D,0x7F,0xA2,0xBD,0x6A,0x7E,0x0A,0xB8,0x9B,0xFF,0xFF,0xFF)
$g1New = [byte[]](0x48,0x3D,0x7F,0xA2,0xBD,0x6A,0xEB,0x0A,0xB8,0x9B,0xFF,0xFF,0xFF)
$h1Old = Find-Pattern -Haystack $bytes -Needle $g1Old
$h1New = Find-Pattern -Haystack $bytes -Needle $g1New
if ($h1Old.Count -eq 1 -and $h1New.Count -eq 0) {
    $out[$h1Old[0] + 6] = 0xEB
    $applied += ('gate1 InitProtection(-101) at file 0x{0:X}  : 7E jle -> EB jmp' -f $h1Old[0])
} elseif ($h1New.Count -eq 1 -and $h1Old.Count -eq 0) {
    $notes += ('gate1 InitProtection(-101) at file 0x{0:X}  : already patched' -f $h1New[0])
} else {
    throw ("gate1: unexpected signature counts (original={0}, patched={1}); refusing to patch." -f $h1Old.Count, $h1New.Count)
}

# ---------------------------------------------------------------- gate 2 -------------
# anchor: cmp rax, rbx / jle rel32  (the comparison of _time64() against _mktime64())
$g2Anchor = [byte[]](0x48,0x3B,0xC3,0x0F,0x8E)
$g2Patched = [byte[]](0x48,0x3B,0xC3,0xE9)
$h2 = Find-Pattern -Haystack $bytes -Needle $g2Anchor
$h2p = Find-Pattern -Haystack $bytes -Needle $g2Patched
# sanity: the 2026-09-30 tm initialiser must be present exactly once
$tmAnchor = [byte[]](0xC7,0x44,0x24,0x6C,0x7E,0x00,0x00,0x00,
                     0xC7,0x44,0x24,0x68,0x08,0x00,0x00,0x00,
                     0xC7,0x44,0x24,0x64,0x1E,0x00,0x00,0x00,
                     0xC7,0x44,0x24,0x60,0x17,0x00,0x00,0x00,
                     0xC7,0x44,0x24,0x5C,0x3B,0x00,0x00,0x00,
                     0xC7,0x44,0x24,0x58,0x3B,0x00,0x00,0x00)
$hTm = Find-Pattern -Haystack $bytes -Needle $tmAnchor
if ($hTm.Count -ne 1) { throw ("gate2: expected exactly 1 tm-initialiser anchor, found {0}." -f $hTm.Count) }

if ($h2.Count -eq 1 -and $h2p.Count -eq 0) {
    $layout    = Get-PeLayout -Bytes $bytes
    $branchOff = $h2[0] + 3                    # start of the 0F 8E near branch
    $rel       = [BitConverter]::ToInt32($bytes, $branchOff + 2)
    $branchRva = Convert-OffsetToRva -Bytes $bytes -Offset $branchOff -Layout $layout
    $targetRva = $branchRva + 6 + $rel
    $newRel    = $targetRva - ($branchRva + 5)   # E9 rel32 is 5 bytes, followed by one NOP
    # semantic assertion: the branch target must be the shared "xor eax, eax" success exit
    $targetOff = Convert-RvaToOffset -Bytes $bytes -Rva $targetRva -Layout $layout
    if ($bytes[$targetOff] -ne 0x33 -or $bytes[$targetOff + 1] -ne 0xC0) {
        throw ('gate2: branch target RVA 0x{0:X} is not the expected "xor eax, eax" success exit.' -f $targetRva)
    }
    $out[$branchOff + 0] = 0xE9
    $out[$branchOff + 1] = [byte]($newRel -band 0xFF)
    $out[$branchOff + 2] = [byte](($newRel -shr 8) -band 0xFF)
    $out[$branchOff + 3] = [byte](($newRel -shr 16) -band 0xFF)
    $out[$branchOff + 4] = [byte](($newRel -shr 24) -band 0xFF)
    $out[$branchOff + 5] = 0x90
    $applied += ('gate2 wcdb_init(-1000) at file 0x{0:X} (RVA 0x{1:X})  : 0F 8E jle -> E9 jmp + NOP (-> RVA 0x{2:X})' -f $branchOff, $branchRva, $targetRva)
} elseif ($h2p.Count -eq 1 -and $h2.Count -eq 0) {
    $notes += ('gate2 wcdb_init(-1000) at file 0x{0:X}  : already patched' -f $h2p[0])
} else {
    throw ("gate2: unexpected signature counts (original={0}, patched={1}); refusing to patch." -f $h2.Count, $h2p.Count)
}

# ---------------------------------------------------------------- write --------------
Write-Host ''
foreach ($a in $applied) { Write-Host "Patch  : $a" }
foreach ($n in $notes)   { Write-Host "Note   : $n" }
if ($applied.Count -eq 0) {
    Write-Host 'Result : ALREADY PATCHED (both gates disabled).'
    return
}

if (-not $OutputPath) {
    if (-not $Force) {
        $backup = "$resolved.bak-expiry"
        if (Test-Path -LiteralPath $backup) {
            $backup = "$resolved.bak-expiry-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        }
        Copy-Item -LiteralPath $resolved -Destination $backup
        Write-Host "Backup : $backup"
    }
    $OutputPath = $resolved
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
[System.IO.File]::WriteAllBytes($OutputPath, $out)
Write-Host "Output : $OutputPath"
Write-Host "SHA256 : $((Get-FileHash -Algorithm SHA256 -LiteralPath $OutputPath).Hash)"
Write-Host 'Result : PATCHED (both build-expiry gates disabled).'
