# Simple test script to verify the SPSMonday module functionality
# Remove any existing module
Remove-Module SPSMonday -Force -ErrorAction SilentlyContinue

# Import the module
$moduleDirectory = "c:\Users\jgeron\VSCode\SPSMonday\SPSMonday"
Import-Module "$moduleDirectory\SPSMonday.psd1" -Force -Global

Write-Host "SPSMonday Module Test Script" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

try {
    # Test 1: Check if module loaded
    Write-Host "`n1. Testing module import..." -ForegroundColor Yellow
    $module = Get-Module SPSMonday
    if ($module) {
        Write-Host "   ✓ Module loaded successfully: $($module.Name) version $($module.Version)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Module failed to load" -ForegroundColor Red
        exit 1
    }

    # Test 2: List available functions
    Write-Host "`n2. Available functions:" -ForegroundColor Yellow
    $functions = Get-Command -Module SPSMonday -CommandType Function
    foreach ($func in $functions) {
        Write-Host "   - $($func.Name)" -ForegroundColor Cyan
    }

    # Test 3: Test configuration functions (without actually configuring)
    Write-Host "`n3. Testing configuration functions..." -ForegroundColor Yellow
    
    # Test Get-SPSMondayConfiguration (should return null/warning when not configured)
    Write-Host "   Testing Get-SPSMondayConfiguration (should show warning):" -ForegroundColor Gray
    $config = Get-SPSMondayConfiguration
    if ($null -eq $config) {
        Write-Host "   ✓ Get-SPSMondayConfiguration works correctly (no config active)" -ForegroundColor Green
    }

    # Test 4: Test help system
    Write-Host "`n4. Testing help documentation..." -ForegroundColor Yellow
    $helpTest = Get-Help Get-MondayBoard -ErrorAction SilentlyContinue
    if ($helpTest) {
        Write-Host "   ✓ Help documentation available" -ForegroundColor Green
        Write-Host "   Example synopsis: $($helpTest.Synopsis)" -ForegroundColor Gray
    } else {
        Write-Host "   ⚠ Help documentation may need improvement" -ForegroundColor Yellow
    }

    # Test 5: Test parameter validation
    Write-Host "`n5. Testing parameter validation..." -ForegroundColor Yellow
    $getBoardCmd = Get-Command Get-MondayBoard
    $limitParam = $getBoardCmd.Parameters['Limit']
    if ($limitParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }) {
        Write-Host "   ✓ Parameter validation is properly configured" -ForegroundColor Green
    }

    Write-Host "`n✓ Module basic tests completed successfully!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Run: New-SPSMondayConfiguration -Name 'test'" -ForegroundColor White
    Write-Host "2. Run: Set-SPSMondayConfiguration -Name 'test'" -ForegroundColor White
    Write-Host "3. Run: Get-MondayBoard -Limit 5" -ForegroundColor White
}
catch {
    Write-Host "`n✗ Error during testing: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "`nTest completed." -ForegroundColor Green
