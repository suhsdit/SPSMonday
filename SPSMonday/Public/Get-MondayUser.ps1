Function Get-MondayUser {
<#
.SYNOPSIS
    Get user information from Monday.com
.DESCRIPTION
    This function retrieves user information from Monday.com, making it easy to find user IDs 
    for use with people columns in Set-MondayBoardItem. You can search by name, email, or get all users.
.PARAMETER UserId
    Specific user ID to retrieve information for
.PARAMETER SearchName
    Search for users by name (partial matches supported)
.PARAMETER SearchEmail
    Search for users by email (partial matches supported)
.PARAMETER IncludeGuests
    Include guest users in the results (default: false, only team members)
.PARAMETER Limit
    Maximum number of users to return (default: 50)
.EXAMPLE
    Get-MondayUser
    
    Gets all team members in your Monday.com account
.EXAMPLE
    Get-MondayUser -SearchName "Jesse"
    
    Finds all users with "Jesse" in their name
.EXAMPLE
    Get-MondayUser -SearchEmail "jgeron"
    
    Finds users with "jgeron" in their email address
.EXAMPLE
    Get-MondayUser -UserId 17582583
    
    Gets specific user information by ID
.EXAMPLE
    Get-MondayUser -IncludeGuests -Limit 100
    
    Gets up to 100 users including guest users
.INPUTS
    System.Int64 (UserId)
    System.String (SearchName, SearchEmail)
.OUTPUTS
    Monday.User[]
.NOTES
    User IDs returned by this function can be used directly in Set-MondayBoardItem for people columns.
    The enhanced Set-MondayBoardItem function will automatically format user IDs correctly.
.LINK
    https://developer.monday.com/api-reference/reference/users
#>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName = 'ById')]
        [Int64]$UserId,
        
        [Parameter(Mandatory=$false, ParameterSetName = 'All')]
        [Parameter(Mandatory=$false, ParameterSetName = 'Search')]
        [String]$SearchName,
        
        [Parameter(Mandatory=$false, ParameterSetName = 'All')]
        [Parameter(Mandatory=$false, ParameterSetName = 'Search')]
        [String]$SearchEmail,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeGuests,
        
        [Parameter(Mandatory=$false, ParameterSetName = 'All')]
        [Parameter(Mandatory=$false, ParameterSetName = 'Search')]
        [ValidateRange(1, 500)]
        [Int]$Limit = 50
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
        Write-Verbose -Message "Parameter Set: $($PSCmdlet.ParameterSetName)"
    }
    
    Process {
        try {
            # Build the GraphQL query based on parameter set
            $fields = @(
                'id',
                'name',
                'email',
                'enabled',
                'is_guest',
                'is_pending',
                'title',
                'location',
                'phone',
                'mobile_phone',
                'created_at',
                'last_activity'
            )
            
            $fieldString = $fields -join ' '
            
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                # Query specific user by ID
                $query = "query { users (ids: [$UserId]) { $fieldString } }"
                Write-Verbose -Message "Querying user by ID: $UserId"
            }
            else {
                # Query users with optional filtering
                $queryArgs = @("limit: $Limit")
                
                if (!$IncludeGuests) {
                    $queryArgs += 'kind: non_guests'
                    Write-Verbose -Message "Excluding guest users"
                }
                
                $argumentString = $queryArgs -join ', '
                $query = "query { users ($argumentString) { $fieldString } }"
                Write-Verbose -Message "Querying up to $Limit users"
            }
            
            Write-Verbose -Message "GraphQL Query: $query"
            
            # Execute the query
            $response = Invoke-MondayApi -Query $query
            
            if ($response.users) {
                $users = $response.users
                
                # Apply client-side filtering for search parameters
                if ($SearchName) {
                    $users = $users | Where-Object { $_.name -like "*$SearchName*" }
                    Write-Verbose -Message "Filtered by name: '$SearchName' - found $($users.Count) matches"
                }
                
                if ($SearchEmail) {
                    $users = $users | Where-Object { $_.email -like "*$SearchEmail*" }
                    Write-Verbose -Message "Filtered by email: '$SearchEmail' - found $($users.Count) matches"
                }
                
                # Add type information to each user
                foreach ($user in $users) {
                    $user.PSObject.TypeNames.Insert(0, 'Monday.User')
                }
                
                Write-Verbose -Message "Retrieved $($users.Count) users"
                return $users
            }
            else {
                Write-Verbose -Message "No users found"
                return @()
            }
        }
        catch {
            $errorMessage = "Error retrieving Monday users: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
