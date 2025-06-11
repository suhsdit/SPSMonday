# Build script for SPSMonday module  
# This script updates the module version and prepares it for deployment

param(
    [Parameter(Mandatory=$false)]
    [string]$BuildVersion = "1.0.0"
)

# List all environment variables for debugging
Write-Host "List all environment variables" -ForegroundColor Green
Get-ChildItem Env: | ForEach-Object { "$($_.Name): $($_.Value)" }
Write-Host "End of environment variables" -ForegroundColor Green

Write-Host "env build ver: $($env:buildVer)" -ForegroundColor Yellow

$buildVersion = if ($env:buildVer) { $env:buildVer } else { $BuildVersion }
$moduleName = 'SPSMonday'
$manifestPath = Join-Path -Path $PWD/$moduleName -ChildPath "$moduleName.psd1"

Write-Host "buildVersion: $buildVersion" -ForegroundColor Cyan
Write-Host "manifestPath: $manifestPath" -ForegroundColor Cyan
Write-Host "WorkingDir: $PWD" -ForegroundColor Cyan

# Update build version in manifest
Write-Host "Updating module version..." -ForegroundColor Yellow
$manifestContent = Get-Content -Path $manifestPath -Raw
$manifestContent = $manifestContent -replace '<ModuleVersion>', $buildVersion

$manifestContent | Set-Content -Path $manifestPath

Write-Host "✓ Build completed successfully!" -ForegroundColor Green
