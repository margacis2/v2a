param(
    [string]$SourceDir = "build\windows\x64\runner\Release",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $SourceDir)) {
    Write-Error "Source directory '$SourceDir' not found."
    exit 1
}

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$possibleWix = @(
    "C:\Program Files (x86)\WiX Toolset v3.11\bin",
    "C:\Program Files (x86)\WiX Toolset v3.14\bin",
    "C:\Program Files\WiX Toolset v3.11\bin",
    "C:\Program Files\WiX Toolset v3.14\bin"
)
foreach ($p in $possibleWix) {
    if (Test-Path $p) {
        $env:Path = "$p;$env:Path"
        break
    }
}

Write-Host "Harvesting release directory using heat.exe..."
& heat.exe dir $SourceDir -cg ProductComponents -dr INSTALLFOLDER -scom -sreg -srd -var var.SourceDir -gg -out build\ProductComponents.wxs

Write-Host "Compiling WiX sources using candle.exe..."
& candle.exe -arch x64 -dSourceDir=$SourceDir packaging\windows\v2a_installer.wxs build\ProductComponents.wxs -out build\

Write-Host "Linking MSI installer using light.exe..."
& light.exe -ext WixUIExtension -sval -b $SourceDir build\v2a_installer.wixobj build\ProductComponents.wixobj -out "$OutputDir\V2A-1.2.1-x64.msi"

Write-Host "Successfully built MSI: $OutputDir\V2A-1.2.1-x64.msi"
