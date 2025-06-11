Function Get-SPSMondayConfiguration {
<#
.SYNOPSIS
    Get information about the current SPSMonday configuration
.DESCRIPTION
    This function displays information about the currently active configuration,
    including the configuration name and base URL being used.
.EXAMPLE
    Get-SPSMondayConfiguration
    
    Displays the current configuration information
.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
    Returns null if no configuration is currently active.
#>
    [CmdletBinding()]
    Param()

    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
    }
    
    Process {
        try {
            if ($Script:SPSMondayConfigName) {
                $configInfo = [PSCustomObject]@{
                    Name = $Script:SPSMondayConfigName
                    BaseURL = $Script:BaseURL
                    ConfigDirectory = $Script:SPSMondayConfigDir
                    IsAuthenticated = $null -ne $Script:MondayApiAuthHeader
                }
                
                # Add type name for formatting
                $configInfo.PSObject.TypeNames.Insert(0, 'Monday.Configuration')
                
                Write-Verbose -Message "Configuration info retrieved"
                return $configInfo
            }
            else {
                Write-Warning -Message "No configuration is currently active. Use Set-SPSMondayConfiguration to activate a configuration."
                return $null
            }
        }
        catch {
            Write-Error -Message "Error retrieving configuration: $($_.Exception.Message)"
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
