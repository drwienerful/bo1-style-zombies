<#
.SYNOPSIS
  Installs OUR script files into the player's Plutonium T5 storage folder.

.DESCRIPTION
  Copies only files from this repo's src/ folder. It never reads, copies or
  modifies game files, and it only deletes files whose names start with bo1sz_.

  Phase 0 modes:
    -Batch A   One beacon per candidate load folder (A1..A5) to find which load.
    -Batch B   The probe script in the -Target folder (run Batch B tests).
    -Batch C   Same file as B (choose tests with the probe_batch dvar in game).
    -Batch Sweep  Compile-only files, one per uncertain builtin (see sweep_candidates.txt).
    -Uninstall Remove every bo1sz_* file this installer could have placed.

  Canonical path (Batch A, 2026-10-05): A2 = scripts\sp\zom\ (loads in zombies only).
  A1/A4 also load in the main menu and campaign; A3 loads on one map only.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Batch A -Map zombie_theater
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Batch B
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Uninstall
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('A', 'B', 'C', 'Sweep')]
    [string]$Batch,
    [ValidateSet('A1', 'A2', 'A3', 'A4', 'A5')]
    [string]$Target = 'A2',
    [string]$Map = 'zombie_theater',
    [string]$StorageRoot = (Join-Path $env:LOCALAPPDATA 'Plutonium\storage\t5'),
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$Prefix = 'bo1sz_'
$ModName = 'bo1sz_probe'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ProbeSrc = Join-Path $RepoRoot 'src\scripts\probe\probe.gsc'
$BeaconSrc = Join-Path $RepoRoot 'src\scripts\probe\beacon_template.gsc'
$SweepSrc = Join-Path $RepoRoot 'src\scripts\probe\sweep_template.gsc'
$SweepList = Join-Path $RepoRoot 'src\scripts\probe\sweep_candidates.txt'

if (-not (Test-Path $StorageRoot)) {
    throw "Plutonium T5 storage folder not found: $StorageRoot (run Plutonium T5 once, or pass -StorageRoot)."
}

function Get-Candidates {
    # Order matters: Batch A picks the first that loads as canonical.
    [ordered]@{
        A1 = 'scripts\sp'
        A2 = 'scripts\sp\zom'
        A3 = "scripts\sp\$Map"
        A4 = 'raw\scripts\sp'
        A5 = "mods\$ModName\scripts\sp"
    }
}

function Remove-OurFiles {
    $dirs = @((Get-Candidates).Values) + @("mods\$ModName")
    foreach ($rel in $dirs) {
        $dir = Join-Path $StorageRoot $rel
        if (-not (Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -File -Filter "$Prefix*" | ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.FullName, 'Remove')) {
                Remove-Item -LiteralPath $_.FullName
                Write-Host "removed  $($_.FullName)"
            }
        }
    }
    # Our mod folder is ours entirely; remove it only if nothing else is left in it.
    $modDir = Join-Path $StorageRoot "mods\$ModName"
    if ((Test-Path $modDir) -and -not (Get-ChildItem -Path $modDir -Recurse -File)) {
        if ($PSCmdlet.ShouldProcess($modDir, 'Remove empty folder')) {
            Remove-Item -LiteralPath $modDir -Recurse
        }
    }
}

function Write-OurFile([string]$relDir, [string]$name, [string]$content) {
    $dir = Join-Path $StorageRoot $relDir
    $dest = Join-Path $dir $name
    if ($PSCmdlet.ShouldProcess($dest, 'Write')) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        # ASCII, no BOM: the GSC compiler should never see a BOM.
        [System.IO.File]::WriteAllText($dest, $content, [System.Text.Encoding]::ASCII)
        Write-Host "installed $dest"
    }
}

function Show-ForeignScripts {
    # Lists names only (never reads or touches them): other scripts that could
    # change the results of the probe.
    $dirs = @((Get-Candidates).Values) + @('maps')
    $found = @()
    foreach ($rel in $dirs) {
        $dir = Join-Path $StorageRoot $rel
        if (-not (Test-Path $dir)) { continue }
        $found += Get-ChildItem -Path $dir -File -Filter '*.gsc' |
            Where-Object { -not $_.Name.StartsWith($Prefix) -and $_.Name -ne 'zm_spawn_fix.gsc' } |
            ForEach-Object { Join-Path $rel $_.Name }
    }
    if ($found.Count -gt 0) {
        Write-Warning 'Other scripts are installed that may affect probe results:'
        $found | ForEach-Object { Write-Warning "  $_" }
    }
}

if ($Uninstall) {
    Remove-OurFiles
    return
}
if (-not $Batch) {
    throw 'Choose -Batch A, B or C, or -Uninstall.'
}

# Always start clean so beacons and probe never load together.
Remove-OurFiles

if ($Batch -eq 'A') {
    $template = [System.IO.File]::ReadAllText($BeaconSrc)
    foreach ($entry in (Get-Candidates).GetEnumerator()) {
        $label = ($entry.Value -replace '\\', '/') + '/'
        $body = $template.Replace('__ID__', $entry.Key).Replace('__WHERE__', $label)
        Write-OurFile $entry.Value "${Prefix}beacon_$($entry.Key.ToLower()).gsc" $body
    }
    Write-OurFile "mods\$ModName" 'mod.json' '{ "desc": "bo1sz Phase 0 load probe (scripts only)", "vers": "0.0.1" }'
    Write-Host ''
    Write-Host "Batch A installed. Start a SOLO custom game on $Map from the main game (not the Mods menu)."
    Write-Host 'Optional second launch: load mods > bo1sz_probe, then the same map, to test A5.'
}
elseif ($Batch -eq 'Sweep') {
    # One compile-only file per candidate builtin, numbered so load order = list order.
    $rel = (Get-Candidates)[$Target]
    $template = [System.IO.File]::ReadAllText($SweepSrc)
    $n = 0
    foreach ($line in [System.IO.File]::ReadAllLines($SweepList)) {
        if ($line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { continue }
        $parts = $line.Split('|', 2)
        $name = $parts[0].Trim()
        $n++
        $body = $template.Replace('__NAME__', $name).Replace('__CALL__', $parts[1].Trim())
        Write-OurFile $rel ('{0}sweep_{1:D2}_{2}.gsc' -f $Prefix, $n, $name) $body
    }
    Write-Host ''
    Write-Host "Sweep installed ($n files). Load any zombies map once; it may fail to load. Then tell Claude."
}
else {
    $rel = (Get-Candidates)[$Target]
    Write-OurFile $rel "${Prefix}probe.gsc" ([System.IO.File]::ReadAllText($ProbeSrc))
    Write-Host ''
    Write-Host "Probe installed at $rel. In the console BEFORE loading the map:  set probe_batch $($Batch.ToLower())"
}
Show-ForeignScripts
