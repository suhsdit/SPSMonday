# Test script for SPSMonday module
# This script helps you quickly test module functionality

param(
    [Parameter(Mandatory=$false)]
    [switch]$ImportFromSource,
    
    [Parameter(Mandatory=$false)]
    [switch]$ListCommands,
    
    [Parameter(Mandatory=$false)]
    [switch]$TestBasicFunctions
)

$moduleName = 'SPSMonday'

Write-Host "SPSMonday Module Testing" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green

if ($ImportFromSource) {
    # Import directly from source for development testing
    Write-Host "Importing module from source..." -ForegroundColor Yellow
    try {
        $manifestPath = ".\SPSMonday\SPSMonday.psd1"
        Import-Module $manifestPath -Force -ErrorAction Stop
        Write-Host "✓ Module imported from source" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import from source: $_"
        exit 1
    }
} else {
    # Import installed module
    Write-Host "Importing installed module..." -ForegroundColor Yellow
    try {
        Import-Module $moduleName -Force -ErrorAction Stop
        Write-Host "✓ Module imported from installation" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import installed module: $_"
        Write-Host "Try installing first with: .\Install-LocalModule.ps1" -ForegroundColor Yellow
        Write-Host "Or use -ImportFromSource to test from source" -ForegroundColor Yellow
        exit 1
    }
}

# Get module info
$module = Get-Module $moduleName
if ($module) {
    Write-Host "`nModule Information:" -ForegroundColor Cyan
    Write-Host "  Name: $($module.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($module.Version)" -ForegroundColor Gray
    Write-Host "  Path: $($module.ModuleBase)" -ForegroundColor Gray
    Write-Host "  Commands: $($module.ExportedCommands.Keys.Count)" -ForegroundColor Gray
}

if ($ListCommands -or $PSBoundParameters.Count -eq 0) {
    Write-Host "`nAvailable Commands:" -ForegroundColor Cyan
    $module.ExportedCommands.Keys | Sort-Object | ForEach-Object {
        $command = Get-Command $_ -Module $moduleName
        Write-Host "  - $($_)" -ForegroundColor White
        if ($command.Synopsis -and $command.Synopsis -ne $_) {
            Write-Host "    $($command.Synopsis)" -ForegroundColor Gray
        }
    }
}

if ($TestBasicFunctions) {
    Write-Host "`nTesting Basic Functions:" -ForegroundColor Cyan
    
    # Test configuration functions
    Write-Host "Testing configuration functions..." -ForegroundColor Yellow
    try {
        Write-Host "  Testing Get-SPSMondayConfiguration..." -ForegroundColor Gray
        $config = Get-SPSMondayConfiguration -ErrorAction SilentlyContinue
        if ($config) {
            Write-Host "    ✓ Configuration exists" -ForegroundColor Green
        } else {
            Write-Host "    ℹ No configuration found (expected for new setup)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "    ⚠ Error testing configuration: $_" -ForegroundColor Red
    }
    
    # Test API function
    Write-Host "  Testing Invoke-MondayApi..." -ForegroundColor Gray
    try {
        Get-Help Invoke-MondayApi -ErrorAction Stop | Out-Null
        Write-Host "    ✓ Function help available" -ForegroundColor Green
    }
    catch {
        Write-Host "    ⚠ Error getting help: $_" -ForegroundColor Red
    }
    
    # Test other functions
    $functionTests = @('Get-MondayBoard', 'Get-MondayBoardDetail', 'Get-MondayBoardItem')
    foreach ($func in $functionTests) {
        Write-Host "  Testing $func..." -ForegroundColor Gray
        try {
            Get-Help $func -ErrorAction Stop | Out-Null
            Write-Host "    ✓ Function available and documented" -ForegroundColor Green
        }
        catch {
            Write-Host "    ⚠ Error with function: $_" -ForegroundColor Red
        }
    }
    
    Write-Host "`n✓ Basic function tests completed" -ForegroundColor Green
    Write-Host "`nTo test with real data:" -ForegroundColor Yellow
    Write-Host "  1. Set up configuration: New-SPSMondayConfiguration" -ForegroundColor White
    Write-Host "  2. Test a board query: Get-MondayBoard -BoardId <your-board-id>" -ForegroundColor White
}

if ($PSBoundParameters.Count -eq 0) {
    Write-Host "`nUsage Examples:" -ForegroundColor Yellow
    Write-Host "  .\Test-Module.ps1 -ImportFromSource    # Test from source code" -ForegroundColor White
    Write-Host "  .\Test-Module.ps1 -ListCommands        # Show all commands" -ForegroundColor White
    Write-Host "  .\Test-Module.ps1 -TestBasicFunctions  # Run basic tests" -ForegroundColor White
    Write-Host "  .\Test-Module.ps1 -ImportFromSource -TestBasicFunctions  # Full test" -ForegroundColor White
}

<#
.SYNOPSIS
    Test script for the SPSMonday module.

.DESCRIPTION
    This script helps you quickly test the SPSMonday module functionality,
    either from the installed version or directly from source code.

.PARAMETER ImportFromSource
    Import the module directly from source code instead of installed version.

.PARAMETER ListCommands
    List all available commands in the module.

.PARAMETER TestBasicFunctions
    Run basic functionality tests on the module.

.EXAMPLES
    # Basic module info and command list
    .\Test-Module.ps1
    
    # Test from source code during development
    .\Test-Module.ps1 -ImportFromSource
    
    # Run comprehensive tests
    .\Test-Module.ps1 -TestBasicFunctions
    
    # Full development testing
    .\Test-Module.ps1 -ImportFromSource -TestBasicFunctions
#>
