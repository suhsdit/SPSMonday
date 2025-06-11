# Build script for SPSMonday module
# This script prepares the module for deployment to PowerShell Gallery

param(
    [Parameter(Mandatory=$false)]
    [string]$BuildVersion = "1.0.0"
)

Write-Host "Building SPSMonday module version: $BuildVersion" -ForegroundColor Green

# Set module information
$moduleName = 'SPSMonday'
$manifestPath = Join-Path -Path $PWD -ChildPath "$moduleName\$moduleName.psd1"

Write-Host "Module: $moduleName" -ForegroundColor Cyan
Write-Host "Manifest Path: $manifestPath" -ForegroundColor Cyan
Write-Host "Working Directory: $PWD" -ForegroundColor Cyan

# Verify manifest exists
if (!(Test-Path -Path $manifestPath)) {
    throw "Module manifest not found at: $manifestPath"
}

# Update build version in manifest
Write-Host "Updating module version to: $BuildVersion" -ForegroundColor Yellow
$manifestContent = Get-Content -Path $manifestPath -Raw
$manifestContent = $manifestContent -replace '1\.0\.0', $BuildVersion
$manifestContent | Set-Content -Path $manifestPath

# Validate the manifest
Write-Host "Validating module manifest..." -ForegroundColor Yellow
try {
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    Write-Host "✓ Manifest validation successful" -ForegroundColor Green
    Write-Host "  Module Name: $($manifest.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($manifest.Version)" -ForegroundColor Gray
    Write-Host "  Author: $($manifest.Author)" -ForegroundColor Gray
    Write-Host "  Functions: $($manifest.ExportedFunctions.Keys -join ', ')" -ForegroundColor Gray
}
catch {
    Write-Error "Manifest validation failed: $_"
    throw $_
}

# Verify all function files exist
Write-Host "Verifying function files..." -ForegroundColor Yellow
$publicFuncPath = Join-Path -Path $PWD -ChildPath "$moduleName\Public"
$functionFiles = Get-ChildItem -Path $publicFuncPath -Filter "*.ps1" -ErrorAction SilentlyContinue

if ($functionFiles) {
    Write-Host "✓ Found $($functionFiles.Count) function files:" -ForegroundColor Green
    foreach ($file in $functionFiles) {
        Write-Host "  - $($file.Name)" -ForegroundColor Gray
    }
} else {
    Write-Warning "No function files found in Public folder"
}

# Test module import
Write-Host "Testing module import..." -ForegroundColor Yellow
try {
    # Remove existing module if loaded
    Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
    
    # Import module
    Import-Module $manifestPath -Force -ErrorAction Stop
    
    # Verify functions are available
    $exportedFunctions = Get-Command -Module $moduleName -CommandType Function
    Write-Host "✓ Module imported successfully" -ForegroundColor Green
    Write-Host "  Exported functions: $($exportedFunctions.Count)" -ForegroundColor Gray
    
    # Clean up
    Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Error "Module import test failed: $_"
    throw $_
}

# Create build output directory
$buildOutputPath = Join-Path -Path $PWD -ChildPath "BuildOutput"
if (Test-Path $buildOutputPath) {
    Remove-Item $buildOutputPath -Recurse -Force
}
New-Item -Path $buildOutputPath -ItemType Directory -Force | Out-Null

# Copy module to build output
Write-Host "Copying module to build output..." -ForegroundColor Yellow
$destinationPath = Join-Path -Path $buildOutputPath -ChildPath $moduleName
Copy-Item -Path $moduleName -Destination $buildOutputPath -Recurse -Force
Write-Host "✓ Module copied to: $destinationPath" -ForegroundColor Green

Write-Host "`n✓ Build completed successfully!" -ForegroundColor Green
Write-Host "Build output location: $buildOutputPath" -ForegroundColor Cyan

# Display next steps
Write-Host "`nNext steps for PowerShell Gallery deployment:" -ForegroundColor Yellow
Write-Host "1. Test the module: Import-Module '$destinationPath\$moduleName.psd1'" -ForegroundColor White
Write-Host "2. Get API key: https://www.powershellgallery.com/account/apikeys" -ForegroundColor White
Write-Host "3. Publish: Publish-Module -Path '$destinationPath' -NuGetApiKey 'your-api-key'" -ForegroundColor White
