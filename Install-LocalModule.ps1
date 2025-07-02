# Local installation script for SPSMonday module
# This script builds and installs the module locally for testing

param(
    [Parameter(Mandatory=$false)]
    [string]$BuildVersion,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$moduleName = 'SPSMonday'
$ErrorActionPreference = 'Stop'

Write-Host "Local Installation of SPSMonday Module" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

try {
    # Build the module first
    if ($BuildVersion) {
        Write-Host "Building module with version $BuildVersion..." -ForegroundColor Yellow
        .\build.ps1 -BuildVersion $BuildVersion
    } else {
        Write-Host "Building module with current version..." -ForegroundColor Yellow
        .\build.ps1
    }
    
    # Get module info
    $manifestPath = ".\SPSMonday\SPSMonday.psd1"
    $moduleInfo = Test-ModuleManifest -Path $manifestPath
    $version = $moduleInfo.Version
    
    Write-Host "✓ Module built successfully" -ForegroundColor Green
    Write-Host "  Version: $version" -ForegroundColor Gray
    
    # Determine installation path
    $userModulePath = $env:PSModulePath -split ';' | Where-Object { $_ -like "*$env:USERPROFILE*" } | Select-Object -First 1
    $systemModulePath = $env:PSModulePath -split ';' | Where-Object { $_ -like "*Program Files*" } | Select-Object -First 1
    
    $installPath = if ($Scope -eq 'CurrentUser') { 
        Join-Path $userModulePath $moduleName
    } else { 
        Join-Path $systemModulePath $moduleName
    }
    
    Write-Host "Installation scope: $Scope" -ForegroundColor Cyan
    Write-Host "Installation path: $installPath" -ForegroundColor Cyan
    
    # Check if module is already installed
    $existingModule = Get-Module -Name $moduleName -ListAvailable | Where-Object { $_.ModuleBase -eq $installPath }
    if ($existingModule -and !$Force) {
        Write-Warning "Module $moduleName is already installed at $installPath"
        Write-Host "Current installed version: $($existingModule.Version)" -ForegroundColor Yellow
        Write-Host "New version: $version" -ForegroundColor Yellow
        Write-Host "Use -Force to overwrite or uninstall first with: Uninstall-Module $moduleName" -ForegroundColor Yellow
        return
    }
    
    if ($WhatIf) {
        Write-Host "`nWhatIf: Would install module to:" -ForegroundColor Cyan
        Write-Host "  Path: $installPath" -ForegroundColor White
        Write-Host "  Version: $version" -ForegroundColor White
        Write-Host "  Scope: $Scope" -ForegroundColor White
        return
    }
    
    # Remove existing installation if Force is specified
    if ($existingModule -and $Force) {
        Write-Host "Removing existing installation..." -ForegroundColor Yellow
        try {
            Uninstall-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
        } catch {
            # If Uninstall-Module fails, try manual removal
            if (Test-Path $installPath) {
                Remove-Item $installPath -Recurse -Force
            }
        }
    }
    
    # Create installation directory
    if (!(Test-Path $installPath)) {
        New-Item -Path $installPath -ItemType Directory -Force | Out-Null
    }
    
    # Copy module files
    Write-Host "Installing module..." -ForegroundColor Yellow
    Copy-Item -Path ".\SPSMonday\*" -Destination $installPath -Recurse -Force
    
    # Verify installation
    $installedModule = Get-Module -Name $moduleName -ListAvailable | Where-Object { $_.ModuleBase -eq $installPath }
    if ($installedModule) {
        Write-Host "✓ Module installed successfully!" -ForegroundColor Green
        Write-Host "  Name: $($installedModule.Name)" -ForegroundColor Gray
        Write-Host "  Version: $($installedModule.Version)" -ForegroundColor Gray
        Write-Host "  Path: $($installedModule.ModuleBase)" -ForegroundColor Gray
        
        # Test import
        Write-Host "`nTesting module import..." -ForegroundColor Yellow
        try {
            Import-Module $moduleName -Force -ErrorAction Stop
            $importedModule = Get-Module $moduleName
            Write-Host "✓ Module imported successfully!" -ForegroundColor Green
            Write-Host "  Available commands: $($importedModule.ExportedCommands.Keys.Count)" -ForegroundColor Gray
            
            Write-Host "`nAvailable commands:" -ForegroundColor Yellow
            $importedModule.ExportedCommands.Keys | Sort-Object | ForEach-Object {
                Write-Host "  - $_" -ForegroundColor White
            }
        }
        catch {
            Write-Warning "Module installed but failed to import: $_"
        }
        
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "  1. Open a new PowerShell session" -ForegroundColor White
        Write-Host "  2. Import the module: Import-Module $moduleName" -ForegroundColor White
        Write-Host "  3. Use your commands: Get-MondayBoard -BoardId 123456" -ForegroundColor White
        Write-Host "`nTo uninstall: Uninstall-Module $moduleName" -ForegroundColor Gray
    } else {
        Write-Error "Installation verification failed"
    }
}
catch {
    Write-Error "Installation failed: $_"
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "- Try running as Administrator for AllUsers scope" -ForegroundColor White
    Write-Host "- Check that PowerShell execution policy allows module installation" -ForegroundColor White
    Write-Host "- Verify the build completed successfully first" -ForegroundColor White
}

<#
.SYNOPSIS
    Locally builds and installs the SPSMonday module for development and testing.

.DESCRIPTION
    This script builds the module and installs it to your local PowerShell module path,
    making it available for import and testing without publishing to PowerShell Gallery.

.PARAMETER BuildVersion
    Optional version to build the module with. If not specified, uses current manifest version.

.PARAMETER Scope
    Installation scope: CurrentUser (default) or AllUsers (requires admin privileges).

.PARAMETER Force
    Force installation, overwriting existing installation if present.

.PARAMETER WhatIf
    Show what would be installed without actually doing it.

.EXAMPLES
    # Simple local install
    .\Install-LocalModule.ps1
    
    # Install with specific version
    .\Install-LocalModule.ps1 -BuildVersion "1.2.0"
    
    # Force reinstall
    .\Install-LocalModule.ps1 -Force
    
    # Install for all users (requires admin)
    .\Install-LocalModule.ps1 -Scope AllUsers
    
    # Test what would be installed
    .\Install-LocalModule.ps1 -WhatIf
#>
