Function Set-SPSMondayConfiguration {
<#
.SYNOPSIS
    Set the active configuration for the SPSMonday module
.DESCRIPTION
    This function activates a previously created configuration profile for the SPSMonday module.
    It loads the API token and sets up the authentication headers for API calls.
.PARAMETER Name
    The name of the configuration profile to activate
.EXAMPLE
    Set-SPSMondayConfiguration -Name "production"
    
    Activates the "production" configuration profile
.INPUTS
    System.String
.OUTPUTS
    None
.NOTES
    The configuration must be created first using New-SPSMondayConfiguration.
.LINK
    https://developer.monday.com/api-reference/docs/authentication
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [String]$Name
    )

    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
        Write-Verbose -Message "Parameters: Name = '$Name'"
    }
    
    Process {
        try {
            # Check if configuration exists
            $configDir = "$Script:SPSMondayConfigRoot\$Name"
            if (!(Test-Path -Path $configDir)) {
                throw "Configuration '$Name' not found. Please create it first using New-SPSMondayConfiguration."
            }
            
            Write-Verbose -Message "Loading configuration from: $configDir"
            
            # Set active configuration
            $Script:SPSMondayConfigName = $Name
            $Script:SPSMondayConfigDir = $configDir
            
            # Load configuration metadata
            $configPath = "$configDir\config.json"
            if (Test-Path -Path $configPath) {
                $Script:Config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
                Write-Verbose -Message "Configuration metadata loaded"
            } else {
                Write-Warning -Message "Configuration metadata file not found. Using defaults."
                $Script:Config = @{
                    Name = $Name
                    BaseURL = "https://api.monday.com/v2"
                }
            }
            
            # Set base URL
            $Script:BaseURL = $Script:Config.BaseURL
            Write-Verbose -Message "Base URL set to: $Script:BaseURL"
            
            # Load API token
            $tokenPath = "$configDir\token.xml"
            if (!(Test-Path -Path $tokenPath)) {
                throw "API token file not found for configuration '$Name'. Please recreate the configuration."
            }
            
            $tokenCredential = Import-Clixml -Path $tokenPath
            $apiToken = $tokenCredential.GetNetworkCredential().Password
            Write-Verbose -Message "API token loaded successfully"
            
            # Set up authentication headers
            $Script:MondayApiAuthHeader = @{
                "Authorization" = $apiToken
            }
            
            Write-Output "Configuration '$Name' activated successfully."
            Write-Verbose -Message "Authentication headers configured"
            
        }
        catch {
            Write-Error -Message "Error setting configuration: $($_.Exception.Message)"
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
