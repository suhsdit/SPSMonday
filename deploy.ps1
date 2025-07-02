# Deployment script for SPSMonday module
# This script publishes the module to PowerShell Gallery

param(
    [Parameter(Mandatory=$true)]
    [string]$NuGetApiKey,
    
    [Parameter(Mandatory=$false)]
    [string]$BuildVersion,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$VersionBump = 'Patch',
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [string]$Repository = "PSGallery"
)

Write-Host "Deploying SPSMonday module to PowerShell Gallery" -ForegroundColor Green
if ($BuildVersion) {
    Write-Host "Using specified version: $BuildVersion" -ForegroundColor Cyan
} else {
    Write-Host "Auto-incrementing version ($VersionBump bump)" -ForegroundColor Cyan
}
Write-Host "Repository: $Repository" -ForegroundColor Cyan
Write-Host "WhatIf Mode: $WhatIf" -ForegroundColor Cyan

# Set paths
$moduleName = 'SPSMonday'
$modulePath = Join-Path -Path $PWD -ChildPath $moduleName
$manifestPath = Join-Path -Path $modulePath -ChildPath "$moduleName.psd1"

# Function to increment version
function Get-NextVersion {
    param(
        [version]$CurrentVersion,
        [string]$BumpType
    )
    
    switch ($BumpType) {
        'Major' { 
            return [version]::new($CurrentVersion.Major + 1, 0, 0)
        }
        'Minor' { 
            return [version]::new($CurrentVersion.Major, $CurrentVersion.Minor + 1, 0)
        }
        'Patch' { 
            return [version]::new($CurrentVersion.Major, $CurrentVersion.Minor, $CurrentVersion.Build + 1)
        }
    }
}

# Determine the version to use
if (-not $BuildVersion) {
    Write-Host "Determining next version..." -ForegroundColor Yellow
    
    # Get current version from manifest
    $currentManifest = Test-ModuleManifest -Path $manifestPath
    $currentVersion = $currentManifest.Version
    
    # Check what's the latest version on PowerShell Gallery
    try {
        $galleryModule = Find-Module -Name $moduleName -Repository $Repository -ErrorAction Stop
        $galleryVersion = $galleryModule.Version
        Write-Host "Latest version on PowerShell Gallery: $galleryVersion" -ForegroundColor Gray
        
        # Use the higher version as base
        $baseVersion = if ($galleryVersion -gt $currentVersion) { $galleryVersion } else { $currentVersion }
    }
    catch {
        # Module doesn't exist on gallery yet, use current manifest version
        Write-Host "Module not found on PowerShell Gallery, using manifest version" -ForegroundColor Gray
        $baseVersion = $currentVersion
    }
    
    $newVersion = Get-NextVersion -CurrentVersion $baseVersion -BumpType $VersionBump
    $BuildVersion = $newVersion.ToString()
    
    Write-Host "Calculated new version: $BuildVersion" -ForegroundColor Green
    
    # Update the manifest with new version
    Write-Host "Updating module manifest..." -ForegroundColor Yellow
    $manifestContent = Get-Content -Path $manifestPath -Raw
    $manifestContent = $manifestContent -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '$BuildVersion'"
    $manifestContent | Set-Content -Path $manifestPath -Encoding UTF8
}

# Verify module exists
if (!(Test-Path -Path $modulePath)) {
    Write-Error "Module not found at: $modulePath"
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
    # Test module manifest
    $module = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    
    Write-Host "✓ Module validation successful" -ForegroundColor Green
    Write-Host "  Name: $($module.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($module.Version)" -ForegroundColor Gray
    Write-Host "  Author: $($module.Author)" -ForegroundColor Gray
    Write-Host "  Description: $($module.Description)" -ForegroundColor Gray
    
    # Verify we're using the correct version
    if ($module.Version.ToString() -ne $BuildVersion) {
        Write-Error "Version mismatch! Manifest shows $($module.Version) but expected $BuildVersion"
        exit 1
    }
    
    # Check if this version already exists
    Write-Host "Checking if version exists on PowerShell Gallery..." -ForegroundColor Yellow
    try {
        $existingModule = Find-Module -Name $moduleName -RequiredVersion $module.Version -Repository $Repository -ErrorAction Stop
        if ($existingModule) {
            Write-Error "Version $($module.Version) already exists on PowerShell Gallery"
            Write-Host "Try using a different -VersionBump parameter or specify -BuildVersion manually" -ForegroundColor Yellow
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
        Path = $modulePath
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

<#
.SYNOPSIS
    Deploys the SPSMonday module to PowerShell Gallery with automatic version management.

.DESCRIPTION
    This script provides several ways to manage versioning:
    
    1. Auto-increment (default): Automatically bumps the version based on what's currently published
       ./deploy.ps1 -NuGetApiKey $apiKey
       ./deploy.ps1 -NuGetApiKey $apiKey -VersionBump Major
    
    2. Specific version: Manually specify the exact version to publish
       ./deploy.ps1 -NuGetApiKey $apiKey -BuildVersion "2.1.0"
    
    3. What-if mode: Test the deployment without actually publishing
       ./deploy.ps1 -NuGetApiKey $apiKey -WhatIf

.PARAMETER NuGetApiKey
    Your PowerShell Gallery API key (required)

.PARAMETER BuildVersion
    Specific version to publish (optional, overrides auto-increment)

.PARAMETER VersionBump
    Type of version increment: Major, Minor, or Patch (default: Patch)

.PARAMETER WhatIf
    Test mode - shows what would be published without actually doing it

.PARAMETER Repository
    Target repository (default: PSGallery)

.EXAMPLES
    # Auto-increment patch version (1.0.0 -> 1.0.1)
    ./deploy.ps1 -NuGetApiKey $apiKey
    
    # Auto-increment minor version (1.0.0 -> 1.1.0)
    ./deploy.ps1 -NuGetApiKey $apiKey -VersionBump Minor
    
    # Use specific version
    ./deploy.ps1 -NuGetApiKey $apiKey -BuildVersion "2.0.0"
    
    # Test deployment
    ./deploy.ps1 -NuGetApiKey $apiKey -WhatIf
#>
