[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')][switch]$Install,
    [Parameter(ParameterSetName = 'Uninstall')][switch]$Uninstall,
    [Parameter(ParameterSetName = 'Find')][switch]$Find,
    [switch]$Verify,
    [switch]$Configure,
    [ValidateSet('Mod', 'Script')][string]$Mode = 'Mod',
    [string]$Root,
    [string]$LogRoot,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$download = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'tools\build.py')) {
    $download = Join-Path $PSScriptRoot 'dist\t6\src'
}
$source = Join-Path $download 'Plutonium\storage\t6\mods\zm_zstats'
$imageSource = Join-Path $download 'Plutonium\storage\t6\images\menu_zm_cac_backing.iwi'
$scriptSource = Join-Path $download 'Plutonium\storage\t6\scripts\zm\zstats.gsc'

if (-not $Root) {
    if (-not $env:LOCALAPPDATA) {
        throw 'LOCALAPPDATA is unavailable. Pass -Root with the Plutonium folder.'
    }
    $Root = Join-Path $env:LOCALAPPDATA 'Plutonium'
}

$plutonium = [IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath $plutonium -PathType Container)) {
    throw "Plutonium folder does not exist: $plutonium"
}
$storage = Join-Path $plutonium 'storage\t6'
$destination = Join-Path $storage 'mods\zm_zstats'
$imageDirectory = Join-Path $storage 'images'
$imageDestination = Join-Path $imageDirectory 'menu_zm_cac_backing.iwi'
$imageBackup = Join-Path $imageDirectory 'menu_zm_cac_backing.zstats-backup.iwi'
$imageMarker = Join-Path $imageDirectory 'menu_zm_cac_backing.zstats.sha256'
$scriptDestination = Join-Path $storage 'scripts\zm\zstats.gsc'
$scriptMarker = "$scriptDestination.zstats.sha256"
$scriptBackup = "$scriptDestination.zstats-backup"
$modFiles = @('zstats.iwd', 'scripts\zm\zstats.gsc')

function Get-ZStatsSHA256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally {
        $stream.Dispose()
    }
}

function Test-ZStatsOwned([string]$Path, [string]$Marker) {
    return (Test-Path -LiteralPath $Path -PathType Leaf) -and
           (Test-Path -LiteralPath $Marker -PathType Leaf) -and
           ((Get-ZStatsSHA256 $Path) -eq (Get-Content -LiteralPath $Marker -Raw).Trim())
}

function Test-ZStatsLegacy([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $ownPath = if ($Path.EndsWith('.zstats-backup')) { $Path.Substring(0, $Path.Length - '.zstats-backup'.Length) } else { $Path }
    if ($ownPath -eq $scriptDestination -or $ownPath -eq (Join-Path $destination 'scripts\zm\zstats.gsc')) {
        return [IO.File]::ReadAllText($Path).StartsWith('// ZSTATS T6')
    }
    if ($ownPath -eq (Join-Path $destination 'zstats.iwd')) {
        try {
            $archive = [IO.Compression.ZipFile]::OpenRead($Path)
            try { return [bool]($archive.Entries | Where-Object FullName -eq 'ui/t6/menus/zstatssettings.lua' | Select-Object -First 1) }
            finally { $archive.Dispose() }
        } catch { return $false }
    }
    return $false
}

function Test-ZStatsManaged([string]$Path, [string]$Marker) {
    if (Test-ZStatsOwned $Path $Marker) { return $true }
    return -not (Test-Path -LiteralPath $Marker -PathType Leaf) -and (Test-ZStatsLegacy $Path)
}

function Start-ZStatsLog([string]$Action) {
    $state = if ($LogRoot) { [IO.Path]::GetFullPath($LogRoot) }
             elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'ZStatsInstaller' }
             else { Join-Path $plutonium '.zstats-installer' }
    New-Item -ItemType Directory -Path $state -Force | Out-Null
    $script:LogPath = Join-Path $state 'install.log'
    Add-Content -LiteralPath $script:LogPath -Value "$(Get-Date -Format o) plan $Action $Mode $plutonium"
}

function Write-ZStatsLog([string]$Action, [string]$Path) {
    Add-Content -LiteralPath $script:LogPath -Value "$(Get-Date -Format o) $Action $Path"
}

function Install-ZStatsFile([string]$From, [string]$To) {
    $marker = "$To.zstats.sha256"
    $backup = "$To.zstats-backup"
    if ((Test-Path -LiteralPath $To -PathType Leaf) -and
        -not (Test-ZStatsManaged $To $marker) -and
        (Test-Path -LiteralPath $backup -PathType Leaf)) {
        throw "Cannot replace changed file while its backup already exists: $To"
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $To) -Force | Out-Null
    if ((Test-Path -LiteralPath $To -PathType Leaf) -and -not (Test-ZStatsManaged $To $marker)) {
        Copy-Item -LiteralPath $To -Destination $backup
        Write-ZStatsLog 'backed-up' $To
    }
    Copy-Item -LiteralPath $From -Destination $To -Force
    (Get-ZStatsSHA256 $To) | Set-Content -LiteralPath $marker -NoNewline
    Write-ZStatsLog 'installed' $To
}

function Remove-ZStatsFile([string]$To) {
    $marker = "$To.zstats.sha256"
    $backup = "$To.zstats-backup"
    if (-not (Test-ZStatsManaged $To $marker)) {
        Write-Warning "Modified or unowned file left alone: $To"
        Write-ZStatsLog 'left-unowned' $To
        return
    }
    Remove-Item -LiteralPath $To -Force
    if (Test-Path -LiteralPath $backup -PathType Leaf) {
        if (Test-ZStatsLegacy $backup) {
            Write-ZStatsLog 'left-legacy-backup' $backup
        } else {
            Move-Item -LiteralPath $backup -Destination $To
            Write-ZStatsLog 'restored' $To
        }
    } else {
        Write-ZStatsLog 'removed' $To
    }
    if (Test-Path -LiteralPath $marker -PathType Leaf) { Remove-Item -LiteralPath $marker -Force }
}

if ($Configure) {
    Write-Host 'Set zs_* options in the Plutonium console before starting a match.'
    Write-Host 'For example: seta zs_hud_preset detailed'
    Write-Host 'The loose T6 script has no lobby or pause-menu Lua. Career PB storage needs the mod menu.'
    exit 0
}

if ($Mode -eq 'Script') {
    if ($Find) {
        Write-Host "T6 loose script: $scriptDestination"
        Write-Host "Installed: $([bool](Test-Path -LiteralPath $scriptDestination -PathType Leaf))"
        exit 0
    }
    if ($Verify) {
        if (-not (Test-Path -LiteralPath $scriptSource -PathType Leaf) -or
            -not (Test-Path -LiteralPath $scriptDestination -PathType Leaf) -or
            (Get-ZStatsSHA256 $scriptSource) -ne (Get-ZStatsSHA256 $scriptDestination)) {
            throw 'The T6 loose script is absent or differs from this download.'
        }
        Write-Host 'Verified the T6 loose script.'
        exit 0
    }
    if ($Uninstall) {
        if (-not (Test-ZStatsManaged $scriptDestination $scriptMarker)) {
            Write-Warning 'The T6 loose script is absent, modified, or not owned by this installer; it was left alone.'
            exit 0
        }
        if (-not $Yes) {
            $answer = Read-Host "Remove $scriptDestination ? [y/N]"
            if ($answer -notmatch '^(?i)y(?:es)?$') { exit 0 }
        }
        Start-ZStatsLog 'uninstall'
        Remove-ZStatsFile $scriptDestination
        Write-Host 'Removed the T6 loose script.'
        exit 0
    }
    if (-not (Test-Path -LiteralPath $scriptSource -PathType Leaf)) {
        throw 'The T6 script payload is missing. Extract the complete release ZIP.'
    }
    if (-not $Yes) {
        $answer = Read-Host "Install T6 loose script to $scriptDestination ? [Y/n]"
        if ($answer -match '^(?i)n(?:o)?$') { exit 0 }
    }
    Start-ZStatsLog 'install'
    Install-ZStatsFile $scriptSource $scriptDestination
    Write-Host "Installed T6 loose script to $scriptDestination"
    exit 0
}

if ($Verify) {
    foreach ($relative in $modFiles) {
        $from = Join-Path $source $relative
        $to = Join-Path $destination $relative
        if (-not (Test-Path -LiteralPath $from -PathType Leaf) -or
            -not (Test-Path -LiteralPath $to -PathType Leaf) -or
            (Get-ZStatsSHA256 $from) -ne (Get-ZStatsSHA256 $to)) {
            throw "The T6 mod file is absent or differs: $relative"
        }
    }
    Write-Host 'Verified the T6 mod files.'
    exit 0
}

if ($Find) {
    Write-Host "Plutonium: $plutonium"
    Write-Host "Black Ops II storage: $storage"
    Write-Host "ZStats installed: $([bool](Test-Path -LiteralPath $destination))"
    Write-Host "ZStats background installed: $([bool](Test-Path -LiteralPath $imageDestination))"
    exit 0
}

if ($Uninstall) {
    if (-not (Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath $imageMarker -PathType Leaf)) {
        Write-Host 'ZStats is not installed at the selected location.'
        exit 0
    }
    if (-not $Yes) {
        $answer = Read-Host "Remove $destination ? [y/N]"
        if ($answer -notmatch '^(?i)y(?:es)?$') { exit 0 }
    }
    Start-ZStatsLog 'uninstall'
    foreach ($relative in $modFiles) { Remove-ZStatsFile (Join-Path $destination $relative) }
    $imageOwned = $false
    if ((Test-Path -LiteralPath $imageDestination -PathType Leaf) -and (Test-Path -LiteralPath $imageMarker -PathType Leaf)) {
        $imageOwned = (Get-ZStatsSHA256 $imageDestination) -eq (Get-Content -LiteralPath $imageMarker -Raw).Trim()
    }
    if ($imageOwned) {
        if (Test-Path -LiteralPath $imageBackup -PathType Leaf) {
            Move-Item -LiteralPath $imageBackup -Destination $imageDestination -Force
            Write-ZStatsLog 'restored' $imageDestination
            Write-Host 'Restored the previous menu_zm_cac_backing texture.'
        } else {
            Remove-Item -LiteralPath $imageDestination -Force
            Write-ZStatsLog 'removed' $imageDestination
            Write-Host 'Removed the ZStats menu background texture.'
        }
    } elseif (Test-Path -LiteralPath $imageMarker -PathType Leaf) {
        Write-Warning 'The menu_zm_cac_backing texture changed after installation; leaving it and any backup untouched.'
    }
    if ($imageOwned -and (Test-Path -LiteralPath $imageMarker -PathType Leaf)) { Remove-Item -LiteralPath $imageMarker -Force }
    Write-Host "Removed ZStats from $destination"
    exit 0
}

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw 'The T6 payload is missing. Extract the complete release zip before installing.'
}
if (-not (Test-Path -LiteralPath $imageSource -PathType Leaf)) {
    throw 'The T6 menu background payload is missing. Extract the complete release zip before installing.'
}
foreach ($relative in $modFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $relative) -PathType Leaf)) {
        throw "The T6 mod payload is missing: $relative"
    }
}

if (-not $Yes) {
    $answer = Read-Host "Install ZStats to $destination ? [Y/n]"
    if ($answer -match '^(?i)n(?:o)?$') { exit 0 }
}

foreach ($relative in $modFiles) {
    $to = Join-Path $destination $relative
    if ((Test-Path -LiteralPath $to -PathType Leaf) -and
        -not (Test-ZStatsManaged $to "$to.zstats.sha256") -and
        (Test-Path -LiteralPath "$to.zstats-backup" -PathType Leaf)) {
        throw "Cannot replace changed file while its backup already exists: $to"
    }
}
if ((Test-Path -LiteralPath $imageDestination -PathType Leaf) -and
    -not (Test-ZStatsOwned $imageDestination $imageMarker) -and
    (Test-Path -LiteralPath $imageBackup -PathType Leaf)) {
    throw "Cannot replace changed image while its backup already exists: $imageDestination"
}
Start-ZStatsLog 'install'
foreach ($relative in $modFiles) {
    Install-ZStatsFile (Join-Path $source $relative) (Join-Path $destination $relative)
}
New-Item -ItemType Directory -Force -Path $imageDirectory | Out-Null
$imageOwned = $false
if ((Test-Path -LiteralPath $imageDestination -PathType Leaf) -and (Test-Path -LiteralPath $imageMarker -PathType Leaf)) {
    $imageOwned = (Get-ZStatsSHA256 $imageDestination) -eq (Get-Content -LiteralPath $imageMarker -Raw).Trim()
}
if ((Test-Path -LiteralPath $imageDestination -PathType Leaf) -and -not $imageOwned -and -not (Test-Path -LiteralPath $imageBackup -PathType Leaf)) {
    Copy-Item -LiteralPath $imageDestination -Destination $imageBackup -Force
}
Copy-Item -LiteralPath $imageSource -Destination $imageDestination -Force
(Get-ZStatsSHA256 $imageSource) | Set-Content -LiteralPath $imageMarker -NoNewline
Write-ZStatsLog 'installed' $imageDestination
Write-Host "Installed ZStats to $destination"
Write-Host "Installed ZStats menu background to $imageDestination"
