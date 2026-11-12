# PowerShell Script to Package V2A Portable Desktop Edition
param (
    [string]$Mode = "lite" # "lite" or "complete"
)

$ErrorActionPreference = "Stop"

$version = "1.2.0"
$sourceDir = "build\windows\x64\runner\Release"
$distDir = "dist"

if (-not (Test-Path $sourceDir)) {
    Write-Host "Release build not found. Running: flutter build windows --release" -ForegroundColor Yellow
    flutter build windows --release
}

if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

$zipName = if ($Mode -eq "complete") {
    "V2A-$version-Windows-x64-Complete.zip"
} else {
    "V2A-$version-Windows-x64-Portable.zip"
}

$targetZip = Join-Path $distDir $zipName
if (Test-Path $targetZip) {
    Remove-Item -Path $targetZip -Force
}

$tempStaging = Join-Path $distDir "V2A"
if (Test-Path $tempStaging) {
    Remove-Item -Path $tempStaging -Recurse -Force
}

Copy-Item -Path $sourceDir -Destination $tempStaging -Recurse

# If Complete mode, copy bundled FFmpeg if available
if ($Mode -eq "complete") {
    $binDir = Join-Path $tempStaging "bin"
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    
    $hostFfmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
    $hostFfprobe = (Get-Command ffprobe -ErrorAction SilentlyContinue).Source
    
    if ($hostFfmpeg) {
        Copy-Item -Path $hostFfmpeg -Destination (Join-Path $binDir "ffmpeg.exe")
    }
    if ($hostFfprobe) {
        Copy-Item -Path $hostFfprobe -Destination (Join-Path $binDir "ffprobe.exe")
    }
}

Compress-Archive -Path "$tempStaging\*" -DestinationPath $targetZip -CompressionLevel Optimal
Remove-Item -Path $tempStaging -Recurse -Force

Write-Host "Portable package created: $targetZip" -ForegroundColor Green
$fileItem = Get-Item $targetZip
Write-Host "Package size: $([math]::Round($fileItem.Length / 1MB, 2)) MB" -ForegroundColor Cyan
