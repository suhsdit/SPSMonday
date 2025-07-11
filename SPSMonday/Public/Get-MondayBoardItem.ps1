Function Get-MondayBoardItem {
<#
.SYNOPSIS
    Get items from a Monday.com board
.DESCRIPTION
    This function retrieves items (rows) from a specific Monday.com board. You can retrieve all items, or specify one or more ItemIds to fetch only those items from the board.
.PARAMETER BoardId
    The ID of the board to retrieve items from
.PARAMETER ItemIds
    Optional. Array of specific item IDs to retrieve from the board. If not specified, all items are retrieved.
.PARAMETER IncludeColumnValues
    Include column values (data) for each item. This shows the actual data stored in each cell.
.PARAMETER IncludeUpdates
    Include recent updates/activity for each item
.PARAMETER IncludeSubitems
    Include subitems for each item
.PARAMETER GroupIds
    Filter items to only those in specific groups (group IDs)
.PARAMETER State
    The state of items to retrieve (active, archived, deleted, all). Default is 'active'.
.PARAMETER Limit
    Maximum number of items to return per request (default: 100, max: 500)
.PARAMETER AllItems
    Retrieve ALL items from the board using pagination. Overrides the Limit parameter.
.EXAMPLE
    Get-MondayBoardItem -BoardId 1234567890
    
    Gets all active items from the specified board (basic info only)
.EXAMPLE
    Get-MondayBoardItem -BoardId 1234567890 -IncludeColumnValues
    
    Gets all items from the board including their column data
.EXAMPLE
    Get-MondayBoardItem -BoardId 1234567890 -ItemIds 1111111111
    
    Gets a specific item from the board by its ID
.EXAMPLE
    Get-MondayBoardItem -BoardId 1234567890 -ItemIds 1111111111,2222222222 -IncludeColumnValues
    
    Gets specific items by their IDs from the board, including their column values
.EXAMPLE
    Get-MondayBoardItem -BoardId 1234567890 -GroupIds @("group1", "group2") -IncludeColumnValues
    
    Gets items from specific groups within the board, including their data
.EXAMPLE
    Get-MondayBoard | Get-MondayBoardItem -IncludeColumnValues
    
    Pipeline example: Gets all items with data from all accessible boards
.EXAMPLE
    Get-MondayBoardItem -BoardId 1234567890 -AllItems -IncludeColumnValues
    
    Gets ALL items from a large board using automatic pagination
.INPUTS
    System.Int64 (BoardId from pipeline)
.OUTPUTS
    Monday.BoardItem[]
.NOTES
    If you specify -ItemIds, only those items will be returned (if they belong to the specified board). If not specified, all items are returned (with optional filters).
    When using -AllItems on very large boards, the function will make multiple API calls to retrieve all items using pagination.
.LINK
    https://developer.monday.com/api-reference/reference/items
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [Alias('Id')]
        [Int64]$BoardId,
        
        [Parameter(Mandatory=$false)]
        [Int64[]]$ItemIds,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeColumnValues,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeUpdates,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeSubitems,
        
        [Parameter(Mandatory=$false)]
        [String[]]$GroupIds,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('active', 'archived', 'deleted', 'all')]
        [String]$State = 'active',
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 500)]
        [Int]$Limit = 100,
        
        [Parameter(Mandatory=$false)]
        [Switch]$AllItems
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
    }
    
    Process {
        try {
            Write-Verbose -Message "Getting items from board ID: $BoardId"
            
            # Build fields for items
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
            
            if ($ItemIds) {
                # Query specific items by ID, but only those that belong to this board
                $itemIdList = ($ItemIds | ForEach-Object { $_ }) -join ', '
                $query = "query { items (ids: [$itemIdList]) { $fieldString board { id } } }"
                Write-Verbose -Message "Querying items by IDs: $itemIdList"
                $response = Invoke-MondayApi -Query $query
                if ($response.items) {
                    # Filter to only items that belong to the specified board
                    $items = $response.items | Where-Object { $_.board.id -eq $BoardId }
                    # Add type info
                    foreach ($item in $items) {
                        $item.PSObject.TypeNames.Insert(0, 'Monday.BoardItem')
                    }
                    if ($GroupIds) {
                        $items = $items | Where-Object { $_.group.id -in $GroupIds }
                        Write-Verbose -Message "Applied group filtering for groups: $($GroupIds -join ', ')"
                    }
                    if ($State -ne 'all') {
                        $items = $items | Where-Object { $_.state -eq $State }
                    }
                    Write-Verbose -Message "Retrieved $($items.Count) items by ItemIds from board $BoardId"
                    return $items
                } else {
                    Write-Verbose -Message "No items found for specified ItemIds on board $BoardId"
                    return @()
                }
            }
            
            $collectedItems = @()
            $cursor = $null
            $currentPage = 1
            
            do {
                # Build query arguments
                $queryArgs = @("limit: $Limit")
                
                if ($cursor) {
                    $queryArgs += "cursor: `"$cursor`""
                }
                
                $argumentString = $queryArgs -join ', '
                
                # Build the complete query
                $itemsQuery = "items_page ($argumentString) { 
                    cursor
                    items { $fieldString } 
                }"
                
                $query = "query { boards (ids: [$BoardId]) { $itemsQuery } }"
                
                Write-Verbose -Message "Executing query for page $currentPage (cursor: $($null -ne $cursor))"
                
                # Execute the query
                $response = Invoke-MondayApi -Query $query
                
                if ($response.boards -and $response.boards.Count -gt 0) {
                    $itemsPage = $response.boards[0].items_page
                    $items = $itemsPage.items
                    
                    if ($items) {
                        # Apply group filtering if specified
                        if ($GroupIds) {
                            $items = $items | Where-Object { $_.group.id -in $GroupIds }
                            Write-Verbose -Message "Applied group filtering for groups: $($GroupIds -join ', ')"
                        }
                        
                        # Apply state filtering (API might not support all state filtering)
                        if ($State -ne 'all') {
                            $items = $items | Where-Object { $_.state -eq $State }
                        }
                        
                        # Add type information to each item
                        foreach ($item in $items) {
                            $item.PSObject.TypeNames.Insert(0, 'Monday.BoardItem')
                        }
                        
                        $collectedItems += $items
                        Write-Verbose -Message "Retrieved $($items.Count) items from page $currentPage (total so far: $($collectedItems.Count))"
                    }
                    
                    # Update cursor for next page
                    $cursor = $itemsPage.cursor
                    $currentPage++
                    
                    # If not using -AllItems, break after first page
                    if (-not $AllItems) {
                        break
                    }
                }
                else {
                    Write-Warning -Message "Board with ID $BoardId not found or access denied"
                    return @()
                }
                
            } while ($cursor -and $AllItems)
            
            if ($collectedItems.Count -gt 0) {
                Write-Verbose -Message "Successfully retrieved $($collectedItems.Count) items from board $BoardId"
                return $collectedItems
            }
            else {
                Write-Verbose -Message "No items found in board $BoardId"
                return @()
            }
        }
        catch {
            $errorMessage = "Error retrieving items from Monday board ${BoardId}: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
