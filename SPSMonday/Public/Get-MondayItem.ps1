Function Get-MondayItem {
<#
.SYNOPSIS
    Retrieve items (rows) from Monday.com boards
.DESCRIPTION
    This function retrieves items from Monday.com boards with various filtering options.
    Items are the individual rows within boards that contain the actual data.
.PARAMETER ItemIds
    Array of specific item IDs to retrieve
.PARAMETER BoardIds
    Array of board IDs to retrieve items from
.PARAMETER GroupIds
    Array of group IDs to filter items by
.PARAMETER Limit
    Maximum number of items to return (default: 25)
.PARAMETER Page
    Page number for pagination (starts at 1)
.PARAMETER State
    The state of items to retrieve (active, archived, deleted, all)
.PARAMETER IncludeColumnValues
    Include column values (data) for each item
.PARAMETER IncludeUpdates
    Include updates/activity for each item
.PARAMETER IncludeSubitems
    Include subitems for each item
.EXAMPLE
    Get-MondayItem -BoardIds @(1234567890)
    
    Gets the first 25 items from the specified board
.EXAMPLE
    Get-MondayItem -ItemIds @(1111111111, 2222222222) -IncludeColumnValues
    
    Gets specific items by their IDs and includes their column values
.EXAMPLE
    Get-MondayItem -BoardIds @(1234567890) -Limit 50 -IncludeColumnValues
    
    Gets 50 items from a board including their data
.EXAMPLE
    Get-MondayBoard | ForEach-Object { Get-MondayItem -BoardIds @($_.id) -IncludeColumnValues }
    
    Pipeline example: Gets items with data for all accessible boards
.INPUTS
    System.Int64[]
.OUTPUTS
    Monday.Item[]
.NOTES
    Items contain the actual data within Monday.com boards. Use IncludeColumnValues 
    to get the actual data stored in each item.
.LINK
    https://developer.monday.com/api-reference/reference/items
#>
    [CmdletBinding(DefaultParameterSetName = 'ByBoard')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName = 'ByItemId')]
        [Int64[]]$ItemIds,
        
        [Parameter(Mandatory=$true, ParameterSetName = 'ByBoard')]
        [Int64[]]$BoardIds,
        
        [Parameter(Mandatory=$false, ParameterSetName = 'ByBoard')]
        [String[]]$GroupIds,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 100)]
        [Int]$Limit = 25,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, [Int]::MaxValue)]
        [Int]$Page = 1,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('active', 'archived', 'deleted', 'all')]
        [String]$State = 'active',
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeColumnValues,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeUpdates,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeSubitems
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
        Write-Verbose -Message "Parameter Set: $($PSCmdlet.ParameterSetName)"
        Write-Verbose -Message "Parameters: Limit=$Limit, Page=$Page, State=$State"
    }
    
    Process {
        try {
            # Build basic fields
            $fields = @(
                'id',
                'name',
                'state',
                'created_at',
                'updated_at',
                'creator { id name email }',
                'board { id name }',
                'group { id title color }'
            )
            
            # Add optional fields
            if ($IncludeColumnValues) {
                $fields += @(
                    'column_values { 
                        id 
                        text 
                        value 
                        type
                        column { id title type }
                    }'
                )
                Write-Verbose -Message "Including column values"
            }
            
            if ($IncludeUpdates) {
                $fields += @(
                    'updates (limit: 10) { 
                        id 
                        body 
                        created_at 
                        creator { id name email }
                    }'
                )
                Write-Verbose -Message "Including updates"
            }
            
            if ($IncludeSubitems) {
                $fields += @(
                    'subitems { 
                        id 
                        name 
                        state
                        created_at
                        column_values { id text value type }
                    }'
                )
                Write-Verbose -Message "Including subitems"
            }
            
            $fieldString = $fields -join ' '
            $query = ""
            
            if ($PSCmdlet.ParameterSetName -eq 'ByItemId') {
                # Query specific items by ID
                $itemIdList = ($ItemIds | ForEach-Object { $_ }) -join ', '
                $query = "query { items (ids: [$itemIdList]) { $fieldString } }"
                Write-Verbose -Message "Querying items by IDs: $itemIdList"
            }
            else {
                # Query items by board
                foreach ($boardId in $BoardIds) {
                    Write-Verbose -Message "Querying items from board ID: $boardId"
                    
                    # Build arguments for items_page query within board
                    $arguments = @("limit: $Limit", "page: $Page")
                    
                    if ($GroupIds) {
                        # Note: Monday.com API doesn't directly support group filtering in items_page
                        # This would need to be filtered client-side or use a different approach
                        Write-Warning -Message "Group filtering is not directly supported by Monday.com API and will be applied client-side"
                    }
                    
                    $argumentString = $arguments -join ', '
                    $itemsQuery = "items_page ($argumentString) { 
                        cursor
                        items { $fieldString } 
                    }"
                    
                    $boardQuery = "query { boards (ids: [$boardId]) { $itemsQuery } }"
                    
                    Write-Verbose -Message "GraphQL Query: $boardQuery"
                    
                    # Execute the query
                    $response = Invoke-MondayApi -Query $boardQuery
                    
                    if ($response.boards -and $response.boards.Count -gt 0) {
                        $items = $response.boards[0].items_page.items
                        
                        # Apply client-side group filtering if specified
                        if ($GroupIds -and $items) {
                            $items = $items | Where-Object { $_.group.id -in $GroupIds }
                            Write-Verbose -Message "Applied client-side group filtering"
                        }
                        
                        if ($items) {
                            # Add type information to each item
                            foreach ($item in $items) {
                                $item.PSObject.TypeNames.Insert(0, 'Monday.Item')
                            }
                            
                            Write-Verbose -Message "Retrieved $($items.Count) items from board $boardId"
                            
                            # Return items for this board
                            $items
                        }
                    }
                }
                return  # Exit here for board-based queries since we're using foreach
            }
            
            # Execute query for item ID based queries
            if ($query) {
                Write-Verbose -Message "GraphQL Query: $query"
                $response = Invoke-MondayApi -Query $query
                
                if ($response.items) {
                    # Add type information to each item
                    foreach ($item in $response.items) {
                        $item.PSObject.TypeNames.Insert(0, 'Monday.Item')
                    }
                    
                    Write-Verbose -Message "Retrieved $($response.items.Count) items"
                    return $response.items
                }
                else {
                    Write-Verbose -Message "No items found"
                    return @()
                }
            }
        }
        catch {
            $errorMessage = "Error retrieving Monday items: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
