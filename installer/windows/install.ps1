[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')][switch]$Install,
    [Parameter(ParameterSetName = 'Uninstall')][switch]$Uninstall,
    [Parameter(ParameterSetName = 'Find')][switch]$Find,
    [string]$Root,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$download = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'tools\build.py')) {
    $download = Join-Path $PSScriptRoot 'dist\t6\src'
}
$source = Join-Path $download 'Plutonium\storage\t6\mods\zm_zstats'
$imageSource = Join-Path $download 'Plutonium\storage\t6\images\menu_zm_cac_backing.iwi'

if (-not $Root) {
    if (-not $env:LOCALAPPDATA) {
        throw 'LOCALAPPDATA is unavailable. Pass -Root with the Plutonium folder.'
    }
    $Root = Join-Path $env:LOCALAPPDATA 'Plutonium'
}

$plutonium = [IO.Path]::GetFullPath($Root)
$storage = Join-Path $plutonium 'storage\t6'
$destination = Join-Path $storage 'mods\zm_zstats'
$imageDirectory = Join-Path $storage 'images'
$imageDestination = Join-Path $imageDirectory 'menu_zm_cac_backing.iwi'
$imageBackup = Join-Path $imageDirectory 'menu_zm_cac_backing.zstats-backup.iwi'
$imageMarker = Join-Path $imageDirectory 'menu_zm_cac_backing.zstats.sha256'

function Get-ZStatsSHA256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    } finally {
        $stream.Dispose()
    }
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
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
    $imageOwned = $false
    if ((Test-Path -LiteralPath $imageDestination -PathType Leaf) -and (Test-Path -LiteralPath $imageMarker -PathType Leaf)) {
        $imageOwned = (Get-ZStatsSHA256 $imageDestination) -eq (Get-Content -LiteralPath $imageMarker -Raw).Trim()
    }
    if ($imageOwned) {
        if (Test-Path -LiteralPath $imageBackup -PathType Leaf) {
            Move-Item -LiteralPath $imageBackup -Destination $imageDestination -Force
            Write-Host 'Restored the previous menu_zm_cac_backing texture.'
        } else {
            Remove-Item -LiteralPath $imageDestination -Force
            Write-Host 'Removed the ZStats menu background texture.'
        }
    } elseif (Test-Path -LiteralPath $imageMarker -PathType Leaf) {
        Write-Warning 'The menu_zm_cac_backing texture changed after installation; leaving it and any backup untouched.'
    }
    if (Test-Path -LiteralPath $imageMarker -PathType Leaf) { Remove-Item -LiteralPath $imageMarker -Force }
    Write-Host "Removed ZStats from $destination"
    exit 0
}

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw 'The T6 payload is missing. Extract the complete release zip before installing.'
}
if (-not (Test-Path -LiteralPath $imageSource -PathType Leaf)) {
    throw 'The T6 menu background payload is missing. Extract the complete release zip before installing.'
}

if (-not $Yes) {
    $answer = Read-Host "Install ZStats to $destination ? [Y/n]"
    if ($answer -match '^(?i)n(?:o)?$') { exit 0 }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
if (Test-Path -LiteralPath $destination) {
    Remove-Item -LiteralPath $destination -Recurse -Force
}
Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
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
Write-Host "Installed ZStats to $destination"
Write-Host "Installed ZStats menu background to $imageDestination"
