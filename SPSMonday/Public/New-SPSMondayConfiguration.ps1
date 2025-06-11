Function New-SPSMondayConfiguration {
<#
.SYNOPSIS
    Create a new configuration for the SPSMonday module
.DESCRIPTION
    This function creates a new configuration profile for connecting to the Monday.com API.
    It will prompt for the necessary API token and save it securely for future use.
.PARAMETER Name
    The name for this configuration profile (e.g., "production", "staging")
.EXAMPLE
    New-SPSMondayConfiguration -Name "production"
    
    Creates a new configuration named "production" and prompts for API token
.EXAMPLE
    New-SPSMondayConfiguration
    
    Prompts for configuration name and API token
.INPUTS
    System.String
.OUTPUTS
    None
.NOTES
    The API token is stored securely using PowerShell's Export-Clixml functionality.
    You can obtain your API token from the Monday.com Developer Center.
.LINK
    https://developer.monday.com/api-reference/docs/authentication
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,
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
            # Prompt for configuration name if not provided
            if (!$Name) {
                $Name = Read-Host "Configuration Name (e.g., production, staging)"
            }
            
            # Validate configuration name
            if ([string]::IsNullOrWhiteSpace($Name)) {
                throw "Configuration name cannot be empty."
            }
            
            Write-Verbose -Message "Creating configuration: $Name"
            
            # Create configuration directory if it doesn't exist
            $configPath = "$Script:SPSMondayConfigRoot\$Name"
            if (!(Test-Path -Path $configPath)) {
                Write-Verbose -Message "Creating directory: $configPath"
                New-Item -ItemType Directory -Path $configPath -Force | Out-Null
                $Script:SPSMondayConfigDir = $configPath
                
                Write-Output ""
                Write-Output "=== Monday.com API Configuration Setup ==="
                Write-Output ""
                Write-Output "To get your API token:"
                Write-Output "1. Log into your Monday.com account"
                Write-Output "2. Click on your profile picture (top right)"
                Write-Output "3. Select 'Developers'"
                Write-Output "4. Click 'My Access Tokens' > 'Show'"
                Write-Output "5. Copy your personal token"
                Write-Output ""
                
                # Prompt for API token securely
                $apiTokenCredential = Get-Credential -UserName "ApiToken" -Message "Enter your Monday.com API Token as the password"
                
                if (!$apiTokenCredential) {
                    throw "API token is required to create configuration."
                }
                
                # Save the API token securely
                $tokenPath = "$configPath\token.xml"
                $apiTokenCredential | Export-Clixml -Path $tokenPath
                Write-Verbose -Message "API token saved to: $tokenPath"
                
                # Create configuration metadata
                $configData = @{
                    Name = $Name
                    Created = Get-Date
                    BaseURL = "https://api.monday.com/v2"
                }
                
                $configPath = "$configPath\config.json"
                $configData | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8
                Write-Verbose -Message "Configuration metadata saved to: $configPath"
                
                Write-Output ""
                Write-Output "Configuration '$Name' created successfully!"
                Write-Output "To activate this configuration, run: Set-SPSMondayConfiguration -Name '$Name'"
                Write-Output ""
            }
            else {
                Write-Warning -Message "Configuration '$Name' already exists."
                Write-Output "To update an existing configuration, delete the folder and recreate it, or use Set-SPSMondayConfiguration to switch to it."
            }
        }
        catch {
            Write-Error -Message "Error creating configuration: $($_.Exception.Message)"
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
