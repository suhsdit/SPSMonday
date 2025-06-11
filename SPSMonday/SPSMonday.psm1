# Template for module courtesy of RamblingCookieMonster
#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
Foreach($import in @($Public + $Private))
{
    Try
    {
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

# Here I might...
# Read in or create an initial config file and variable

# Export Public functions ($Public.BaseName) for WIP modules

# Monday.com Config info, set script variables
New-Variable -Name SPSMondayConfigName -Scope Script -Force
New-Variable -Name SPSMondayConfigRoot -Scope Script -Force
$SPSMondayConfigRoot = "$Env:USERPROFILE\AppData\Local\powershell\SPSMonday"
New-Variable -Name SPSMondayConfigDir -Scope Script -Force
New-Variable -Name Config -Scope Script -Force
New-Variable -Name APIKey -Scope Script -Force
New-Variable -Name BaseURL -Scope Script -Force
New-Variable -Name MondayApiAuthHeader -Scope Script -Force

# Set default API URL
$Script:BaseURL = "https://api.monday.com/v2"

Export-ModuleMember -Function $Public.Basename
