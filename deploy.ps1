# Deployment script for SPSMonday module
# This script publishes the module to PowerShell Gallery

param(
    [Parameter(Mandatory=$true)]
    [string]$NuGetApiKey,
    
    [Parameter(Mandatory=$false)]
    [string]$BuildVersion = "1.0.0",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [string]$Repository = "PSGallery"
)

Write-Host "Deploying SPSMonday module to PowerShell Gallery" -ForegroundColor Green
Write-Host "Version: $BuildVersion" -ForegroundColor Cyan
Write-Host "Repository: $Repository" -ForegroundColor Cyan
Write-Host "WhatIf Mode: $WhatIf" -ForegroundColor Cyan

# Set paths
$moduleName = 'SPSMonday'
$buildOutputPath = Join-Path -Path $PWD -ChildPath "BuildOutput\$moduleName"

# Verify build output exists
if (!(Test-Path -Path $buildOutputPath)) {
    Write-Error "Build output not found at: $buildOutputPath"
    Write-Host "Please run build.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Verify NuGet API key
if ([string]::IsNullOrWhiteSpace($NuGetApiKey)) {
    Write-Error "NuGetApiKey is required"
    Write-Host "Get your API key from: https://www.powershellgallery.com/account/apikeys" -ForegroundColor Yellow
    exit 1
}

# Final validation before publish
Write-Host "Performing final validation..." -ForegroundColor Yellow

try {
    # Test module import one more time
    Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
    $manifestPath = Join-Path -Path $buildOutputPath -ChildPath "$moduleName.psd1"
    $module = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    
    Write-Host "✓ Module validation successful" -ForegroundColor Green
    Write-Host "  Name: $($module.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($module.Version)" -ForegroundColor Gray
    Write-Host "  Author: $($module.Author)" -ForegroundColor Gray
    Write-Host "  Description: $($module.Description)" -ForegroundColor Gray
    Write-Host "  Tags: $($module.Tags -join ', ')" -ForegroundColor Gray
    
    # Check if this version already exists
    Write-Host "Checking if version exists on PowerShell Gallery..." -ForegroundColor Yellow
    try {
        $existingModule = Find-Module -Name $moduleName -RequiredVersion $module.Version -Repository $Repository -ErrorAction Stop
        if ($existingModule) {
            Write-Error "Version $($module.Version) already exists on PowerShell Gallery"
            Write-Host "Please increment the version number and rebuild" -ForegroundColor Yellow
            exit 1
        }
    }
    catch {
        # Version doesn't exist, which is good
        Write-Host "✓ Version $($module.Version) is available" -ForegroundColor Green
    }
}
catch {
    Write-Error "Module validation failed: $_"
    exit 1
}

# Publish to PowerShell Gallery
Write-Host "Publishing module to PowerShell Gallery..." -ForegroundColor Yellow

try {
    $publishParams = @{
        Path = $buildOutputPath
        NuGetApiKey = $NuGetApiKey
        Repository = $Repository
        Force = $true
        Verbose = $true
    }
    
    if ($WhatIf) {
        $publishParams.WhatIf = $true
        Write-Host "WhatIf mode - would publish with these parameters:" -ForegroundColor Cyan
        $publishParams | Format-Table -AutoSize
    }
    
    Publish-Module @publishParams
    
    if (!$WhatIf) {
        Write-Host "✓ Module published successfully!" -ForegroundColor Green
        Write-Host "View your module at: https://www.powershellgallery.com/packages/$moduleName/$($module.Version)" -ForegroundColor Cyan
        
        # Test installation
        Write-Host "`nTesting installation from PowerShell Gallery..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10  # Give the gallery time to index
        
        try {
            $installedModule = Find-Module -Name $moduleName -Repository $Repository
            Write-Host "✓ Module is available for installation" -ForegroundColor Green
            Write-Host "  Version: $($installedModule.Version)" -ForegroundColor Gray
            Write-Host "  Published: $($installedModule.PublishedDate)" -ForegroundColor Gray
        }
        catch {
            Write-Warning "Module may not be immediately available for search. This is normal and can take a few minutes."
        }
        
        Write-Host "`nUsers can now install your module with:" -ForegroundColor Yellow
        Write-Host "Install-Module -Name $moduleName" -ForegroundColor White
    }
}
catch {
    Write-Error "Publishing failed: $_"
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "- Invalid API key" -ForegroundColor White
    Write-Host "- Version already exists" -ForegroundColor White
    Write-Host "- Network connectivity issues" -ForegroundColor White
    Write-Host "- Module validation errors" -ForegroundColor White
    exit 1
}

Write-Host "`n✓ Deployment process completed!" -ForegroundColor Green
