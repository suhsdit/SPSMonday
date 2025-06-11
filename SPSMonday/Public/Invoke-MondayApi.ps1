Function Invoke-MondayApi {
<#
.SYNOPSIS
    Core function for making authenticated requests to the Monday.com API
.DESCRIPTION
    This function handles all HTTP requests to the Monday.com GraphQL API with proper authentication,
    error handling, and response processing. It serves as the foundation for all other module functions.
.PARAMETER Query
    The GraphQL query to execute
.PARAMETER Variables
    Optional variables for the GraphQL query
.PARAMETER Method
    HTTP method to use (defaults to POST for GraphQL)
.EXAMPLE
    Invoke-MondayApi -Query "query { me { id name } }"
    
    Gets basic information about the authenticated user
.EXAMPLE
    $query = "query { boards { id name } }"
    Invoke-MondayApi -Query $query
    
    Retrieves all boards the user has access to
.INPUTS
    System.String
.OUTPUTS
    PSCustomObject
.NOTES
    This function requires a valid Monday.com API token to be configured via Set-SPSMondayConfiguration
.LINK
    https://developer.monday.com/api-reference/docs/authentication
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Query,
        
        [Parameter(Mandatory=$false)]
        [Hashtable]$Variables = @{},
        
        [Parameter(Mandatory=$false)]
        [String]$Method = "POST"
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
        Write-Verbose -Message "Parameters: Query length = $($Query.Length), Method = $Method"
        
        # Check if authentication is configured
        if (-not $Script:MondayApiAuthHeader) {
            throw "Monday.com API authentication not configured. Please run Set-SPSMondayConfiguration first."
        }
    }
    
    Process {
        try {
            # Prepare the request body
            $requestBody = @{
                query = $Query
            }
            
            if ($Variables.Count -gt 0) {
                $requestBody.variables = $Variables
            }
            
            $jsonBody = $requestBody | ConvertTo-Json -Depth 10
            Write-Verbose -Message "Request body: $jsonBody"
            
            # Prepare headers
            $headers = $Script:MondayApiAuthHeader.Clone()
            $headers['Content-Type'] = 'application/json'
            
            Write-Verbose -Message "Making request to: $Script:BaseURL"
            
            # Make the API call
            $response = Invoke-RestMethod -Uri $Script:BaseURL -Method $Method -Headers $headers -Body $jsonBody -ErrorAction Stop
            
            Write-Verbose -Message "API call successful"
            
            # Check for GraphQL errors
            if ($response.errors) {
                $errorMessage = "GraphQL errors: " + ($response.errors | ForEach-Object { $_.message } | Join-String -Separator "; ")
                Write-Error -Message $errorMessage
                throw $errorMessage
            }
            
            # Return the data portion of the response
            return $response.data
        }
        catch {
            $errorMessage = "Error calling Monday.com API: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            
            # Additional error details for debugging
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode
                Write-Verbose -Message "HTTP Status Code: $statusCode"
                
                if ($statusCode -eq 401) {
                    Write-Error -Message "Authentication failed. Please check your API token configuration."
                }
                elseif ($statusCode -eq 429) {
                    Write-Error -Message "Rate limit exceeded. Please wait before making more requests."
                }
            }
            
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
