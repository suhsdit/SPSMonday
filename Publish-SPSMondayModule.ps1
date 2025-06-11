# Quick deploy script for SPSMonday module
# This script handles the complete build and deploy process

param(
    [Parameter(Mandatory=$false)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$NuGetApiKey,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

Write-Host "SPSMonday Module Deployment Tool" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Get current version from manifest if not specified
if (!$Version) {
    $manifestPath = ".\SPSMonday\SPSMonday.psd1"
    if (Test-Path $manifestPath) {
        $manifest = Import-PowerShellDataFile -Path $manifestPath
        $currentVersion = $manifest.ModuleVersion
        
        # Suggest next version
        $versionParts = $currentVersion.Split('.')
        $versionParts[2] = [int]$versionParts[2] + 1
        $suggestedVersion = $versionParts -join '.'
        
        Write-Host "Current version: $currentVersion" -ForegroundColor Yellow
        $Version = Read-Host "Enter new version (suggested: $suggestedVersion)"
        
        if ([string]::IsNullOrWhiteSpace($Version)) {
            $Version = $suggestedVersion
        }
    } else {
        Write-Error "Module manifest not found at: $manifestPath"
        exit 1
    }
}

Write-Host "Target version: $Version" -ForegroundColor Cyan

# Get API key if not provided
if (!$NuGetApiKey -and !$WhatIf) {
    Write-Host "`nPowerShell Gallery API Key required for deployment." -ForegroundColor Yellow
    Write-Host "Get your key from: https://www.powershellgallery.com/account/apikeys" -ForegroundColor Gray
    $NuGetApiKey = Read-Host "Enter your NuGet API Key (or press Enter for WhatIf mode)"
    
    if ([string]::IsNullOrWhiteSpace($NuGetApiKey)) {
        $WhatIf = $true
        Write-Host "Running in WhatIf mode..." -ForegroundColor Yellow
    }
}

# Pre-deployment checks
Write-Host "`nPerforming pre-deployment checks..." -ForegroundColor Yellow

# Check if git repo is clean (if git is available)
try {
    $gitStatus = git status --porcelain 2>$null
    if ($LASTEXITCODE -eq 0) {
        if ($gitStatus) {
            Write-Warning "Git repository has uncommitted changes:"
            git status --short
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                Write-Host "Deployment cancelled" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "✓ Git repository is clean" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "Git not available or not a git repository" -ForegroundColor Gray
}

# Check PowerShell Gallery connectivity
Write-Host "Testing PowerShell Gallery connectivity..." -ForegroundColor Gray
try {
    $testModule = Find-Module -Name "PowerShellGet" -Repository PSGallery -ErrorAction Stop | Select-Object -First 1
    Write-Host "✓ PowerShell Gallery is accessible" -ForegroundColor Green
} catch {
    Write-Error "Cannot connect to PowerShell Gallery: $_"
    exit 1
}

# Build module
if (!$SkipBuild) {
    Write-Host "`nBuilding module..." -ForegroundColor Yellow
    try {
        & .\build.ps1 -BuildVersion $Version
        Write-Host "✓ Build completed successfully" -ForegroundColor Green
    } catch {
        Write-Error "Build failed: $_"
        exit 1
    }
} else {
    Write-Host "Skipping build (SkipBuild specified)" -ForegroundColor Gray
}

# Deploy module
Write-Host "`nDeploying module..." -ForegroundColor Yellow
try {
    $deployParams = @{
        BuildVersion = $Version
    }
    
    if ($NuGetApiKey) {
        $deployParams.NuGetApiKey = $NuGetApiKey
    }
    
    if ($WhatIf) {
        $deployParams.WhatIf = $true
    }
    
    & .\deploy.ps1 @deployParams
    
    if (!$WhatIf) {
        Write-Host "✓ Deployment completed successfully" -ForegroundColor Green
    } else {
        Write-Host "✓ WhatIf deployment check completed" -ForegroundColor Green
    }
} catch {
    Write-Error "Deployment failed: $_"
    exit 1
}

# Post-deployment tasks
if (!$WhatIf) {
    Write-Host "`nPost-deployment tasks..." -ForegroundColor Yellow
    
    # Suggest git tagging
    try {
        git --version >$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Consider tagging this release:" -ForegroundColor Cyan
            Write-Host "  git tag v$Version" -ForegroundColor White
            Write-Host "  git push origin v$Version" -ForegroundColor White
        }
    } catch {
        # Git not available
    }
    
    # Installation instructions
    Write-Host "`nYour module has been published!" -ForegroundColor Green
    Write-Host "Users can install it with:" -ForegroundColor Cyan
    Write-Host "  Install-Module -Name SPSMonday" -ForegroundColor White
    Write-Host "  Import-Module SPSMonday" -ForegroundColor White
    Write-Host "`nModule page: https://www.powershellgallery.com/packages/SPSMonday/$Version" -ForegroundColor Cyan
}

Write-Host "`n✓ Deployment process completed!" -ForegroundColor Green
