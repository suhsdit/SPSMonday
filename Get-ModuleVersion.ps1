# Helper script to check current and next versions
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$VersionBump = 'Patch',
    
    [Parameter(Mandatory=$false)]
    [string]$Repository = "PSGallery"
)

$moduleName = 'SPSMonday'
$manifestPath = Join-Path -Path $PWD -ChildPath "$moduleName\$moduleName.psd1"

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

Write-Host "SPSMonday Module Version Information" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Get current version from manifest
try {
    $currentManifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    $currentVersion = $currentManifest.Version
    Write-Host "Current manifest version: $currentVersion" -ForegroundColor Cyan
}
catch {
    Write-Error "Could not read module manifest: $_"
    exit 1
}

# Check what's the latest version on PowerShell Gallery
try {
    $galleryModule = Find-Module -Name $moduleName -Repository $Repository -ErrorAction Stop
    $galleryVersion = $galleryModule.Version
    Write-Host "Latest PowerShell Gallery version: $galleryVersion" -ForegroundColor Yellow
    
    if ($galleryVersion -gt $currentVersion) {
        Write-Host "⚠️  Gallery version is newer than manifest!" -ForegroundColor Red
        $baseVersion = $galleryVersion
    } elseif ($galleryVersion -eq $currentVersion) {
        Write-Host "⚠️  Versions are the same - increment needed" -ForegroundColor Yellow
        $baseVersion = $currentVersion
    } else {
        Write-Host "✓ Manifest version is newer" -ForegroundColor Green
        $baseVersion = $currentVersion
    }
}
catch {
    Write-Host "Module not found on PowerShell Gallery" -ForegroundColor Gray
    $baseVersion = $currentVersion
}

# Calculate next versions
Write-Host "`nNext version options:" -ForegroundColor Green
Write-Host "  Patch: $($baseVersion) -> $(Get-NextVersion -CurrentVersion $baseVersion -BumpType 'Patch')" -ForegroundColor White
Write-Host "  Minor: $($baseVersion) -> $(Get-NextVersion -CurrentVersion $baseVersion -BumpType 'Minor')" -ForegroundColor White
Write-Host "  Major: $($baseVersion) -> $(Get-NextVersion -CurrentVersion $baseVersion -BumpType 'Major')" -ForegroundColor White

$recommendedVersion = Get-NextVersion -CurrentVersion $baseVersion -BumpType $VersionBump
Write-Host "`nRecommended next version ($VersionBump): $recommendedVersion" -ForegroundColor Green

Write-Host "`nTo deploy with auto-increment:" -ForegroundColor Yellow
Write-Host "  .\deploy.ps1 -NuGetApiKey `$apiKey -VersionBump $VersionBump" -ForegroundColor White
Write-Host "`nTo deploy with specific version:" -ForegroundColor Yellow
Write-Host "  .\deploy.ps1 -NuGetApiKey `$apiKey -BuildVersion '$recommendedVersion'" -ForegroundColor White
