Function Get-MondayBoard {
<#
.SYNOPSIS
    Retrieve Monday.com boards with filtering options
.DESCRIPTION
    This function retrieves board information from Monday.com with various filtering and pagination options.
    It supports filtering by board IDs, workspace, board type, state, and provides pagination controls.
.PARAMETER BoardIds
    Array of specific board IDs to retrieve
.PARAMETER WorkspaceIds
    Array of workspace IDs to filter boards by
.PARAMETER BoardKind
    The type of boards to retrieve (public, private, share)
.PARAMETER State
    The state of boards to retrieve (active, archived, deleted, all)
.PARAMETER Limit
    Maximum number of boards to return (default: 25)
.PARAMETER Page
    Page number for pagination (starts at 1)
.PARAMETER OrderBy
    How to order the results (created_at, used_at)
.PARAMETER IncludeItems
    Include basic item information for each board
.PARAMETER IncludeColumns
    Include column information for each board
.PARAMETER IncludeGroups
    Include group information for each board
.EXAMPLE
    Get-MondayBoard
    
    Gets the first 25 active boards
.EXAMPLE
    Get-MondayBoard -Limit 10 -BoardKind public
    
    Gets the first 10 public boards
.EXAMPLE
    Get-MondayBoard -BoardIds @(1234567890, 9876543210)
    
    Gets specific boards by their IDs
.EXAMPLE
    Get-MondayBoard -WorkspaceIds @(12345) -IncludeItems
    
    Gets boards from a specific workspace and includes basic item information
.INPUTS
    System.Int64[]
.OUTPUTS
    Monday.Board[]
.NOTES
    Requires an active Monday.com API configuration. Use Set-SPSMondayConfiguration to set up authentication.
.LINK
    https://developer.monday.com/api-reference/reference/boards
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [Int64[]]$BoardIds,
        
        [Parameter(Mandatory=$false)]
        [Int64[]]$WorkspaceIds,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('public', 'private', 'share')]
        [String]$BoardKind,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('active', 'archived', 'deleted', 'all')]
        [String]$State = 'active',
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 100)]
        [Int]$Limit = 25,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, [Int]::MaxValue)]
        [Int]$Page = 1,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('created_at', 'used_at')]
        [String]$OrderBy,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeItems,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeColumns,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeGroups
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
        Write-Verbose -Message "Parameters: Limit=$Limit, Page=$Page, State=$State"
    }
    
    Process {
        try {
            # Build the GraphQL query
            $queryParts = @()
            
            # Add arguments
            $arguments = @()
            
            if ($BoardIds) {
                $boardIdList = ($BoardIds | ForEach-Object { $_ }) -join ', '
                $arguments += "ids: [$boardIdList]"
                Write-Verbose -Message "Filtering by board IDs: $boardIdList"
            }
            
            if ($WorkspaceIds) {
                $workspaceIdList = ($WorkspaceIds | ForEach-Object { $_ }) -join ', '
                $arguments += "workspace_ids: [$workspaceIdList]"
                Write-Verbose -Message "Filtering by workspace IDs: $workspaceIdList"
            }
            
            if ($BoardKind) {
                $arguments += "board_kind: $BoardKind"
                Write-Verbose -Message "Filtering by board kind: $BoardKind"
            }
            
            if ($State) {
                $arguments += "state: $State"
                Write-Verbose -Message "Filtering by state: $State"
            }
            
            $arguments += "limit: $Limit"
            $arguments += "page: $Page"
            
            if ($OrderBy) {
                $arguments += "order_by: $OrderBy"
                Write-Verbose -Message "Ordering by: $OrderBy"
            }
            
            # Build field selection
            $fields = @(
                'id',
                'name',
                'description',
                'state',
                'board_kind',
                'permissions',
                'url',
                'updated_at',
                'items_count',
                'creator { id name email }',
                'owners { id name email }',
                'workspace { id name }',
                'workspace_id'
            )
            
            if ($IncludeColumns) {
                $fields += 'columns { id title type settings_str }'
                Write-Verbose -Message "Including column information"
            }
            
            if ($IncludeGroups) {
                $fields += 'groups { id title color position }'
                Write-Verbose -Message "Including group information"
            }
            
            if ($IncludeItems) {
                $fields += 'items_page { items { id name } }'
                Write-Verbose -Message "Including basic item information"
            }
            
            # Construct the complete query
            $argumentString = if ($arguments.Count -gt 0) { " (" + ($arguments -join ', ') + ")" } else { "" }
            $fieldString = $fields -join ' '
            
            $query = "query { boards$argumentString { $fieldString } }"
            
            Write-Verbose -Message "GraphQL Query: $query"
            
            # Execute the query
            $response = Invoke-MondayApi -Query $query
            
            if ($response.boards) {
                # Add type information to each board
                foreach ($board in $response.boards) {
                    $board.PSObject.TypeNames.Insert(0, 'Monday.Board')
                }
                
                Write-Verbose -Message "Retrieved $($response.boards.Count) boards"
                return $response.boards
            }
            else {
                Write-Verbose -Message "No boards found"
                return @()
            }
        }
        catch {
            $errorMessage = "Error retrieving Monday boards: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
