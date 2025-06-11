Function Test-MondayApiConnection {
<#
.SYNOPSIS
    Test the connection to Monday.com API
.DESCRIPTION
    This private function tests if the current configuration can successfully
    connect to the Monday.com API by making a simple query.
.OUTPUTS
    System.Boolean
.NOTES
    This is a private function used internally by the module.
#>
    [CmdletBinding()]
    Param()
    
    try {
        # Simple test query to check authentication
        $testQuery = "query { me { id name } }"
        $response = Invoke-MondayApi -Query $testQuery -ErrorAction Stop
        
        if ($response.me) {
            Write-Verbose -Message "API connection test successful. Connected as: $($response.me.name)"
            return $true
        } else {
            Write-Verbose -Message "API connection test failed. No user data returned."
            return $false
        }
    }
    catch {
        Write-Verbose -Message "API connection test failed: $($_.Exception.Message)"
        return $false
    }
}

Function ConvertTo-MondayGraphQLString {
<#
.SYNOPSIS
    Convert a PowerShell string to a properly escaped GraphQL string
.DESCRIPTION
    This private function handles proper escaping of strings for GraphQL queries.
.PARAMETER InputString
    The string to escape for GraphQL
.OUTPUTS
    System.String
.NOTES
    This is a private function used internally by the module.
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$InputString
    )
    
    if ([string]::IsNullOrEmpty($InputString)) {
        return '""'
    }
    
    # Escape special characters for GraphQL
    $escaped = $InputString -replace '\\', '\\\\' -replace '"', '\"' -replace '\n', '\n' -replace '\r', '\r' -replace '\t', '\t'
    
    return "`"$escaped`""
}

Function Write-MondayVerbose {
<#
.SYNOPSIS
    Standardized verbose logging for the SPSMonday module
.DESCRIPTION
    This private function provides consistent verbose output formatting across the module.
.PARAMETER Message
    The message to write
.PARAMETER FunctionName
    The name of the calling function
.OUTPUTS
    None
.NOTES
    This is a private function used internally by the module.
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Message,
        
        [Parameter(Mandatory=$false)]
        [String]$FunctionName
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = if ($FunctionName) { "[$timestamp] $FunctionName" } else { "[$timestamp] SPSMonday" }
    
    Write-Verbose -Message "$prefix : $Message"
}
