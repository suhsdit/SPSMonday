Function Get-MondayBoardDetail {
<#
.SYNOPSIS
    Get detailed information about a specific Monday.com board
.DESCRIPTION
    This function retrieves comprehensive information about a specific Monday.com board,
    including its items, columns, groups, updates, and other detailed properties.
.PARAMETER BoardId
    The ID of the board to retrieve detailed information for
.PARAMETER IncludeItems
    Include all items (rows) in the board
.PARAMETER IncludeColumns
    Include detailed column information
.PARAMETER IncludeGroups
    Include group information
.PARAMETER IncludeUpdates
    Include board updates/activity
.PARAMETER IncludeSubscribers
    Include board subscribers
.PARAMETER IncludeViews
    Include board views
.PARAMETER ItemsLimit
    Maximum number of items to retrieve (default: 100)
.PARAMETER ItemsPage
    Page number for items pagination (default: 1)
.EXAMPLE
    Get-MondayBoardDetail -BoardId 1234567890
    
    Gets basic detailed information about the specified board
.EXAMPLE
    Get-MondayBoardDetail -BoardId 1234567890 -IncludeItems -IncludeColumns
    
    Gets board details including all items and columns
.EXAMPLE
    Get-MondayBoard | Get-MondayBoardDetail -IncludeItems
    
    Pipeline example: Gets details for all boards including their items
.INPUTS
    System.Int64
.OUTPUTS
    Monday.BoardDetail
.NOTES
    This function provides more comprehensive information than Get-MondayBoard.
    Use this when you need complete board data including items and detailed properties.
.LINK
    https://developer.monday.com/api-reference/reference/boards
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
        [Switch]$IncludeItems,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeColumns,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeGroups,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeUpdates,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeSubscribers,
        
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeViews,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 500)]
        [Int]$ItemsLimit = 100,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, [Int]::MaxValue)]
        [Int]$ItemsPage = 1
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
    }
    
    Process {
        try {
            Write-Verbose -Message "Getting detailed information for board ID: $BoardId"
            
            # Build field selection based on parameters
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
                'workspace_id',
                'board_folder_id',
                'communication',
                'item_terminology'
            )
            
            if ($IncludeColumns) {
                $fields += @(
                    'columns { 
                        id 
                        title 
                        type 
                        description 
                        settings_str 
                        archived 
                        width 
                    }'
                )
                Write-Verbose -Message "Including detailed column information"
            }
            
            if ($IncludeGroups) {
                $fields += @(
                    'groups { 
                        id 
                        title 
                        color 
                        position 
                        archived 
                        deleted 
                    }'
                )
                Write-Verbose -Message "Including group information"
            }
            
            if ($IncludeItems) {
                $itemsQuery = "items_page (limit: $ItemsLimit, page: $ItemsPage) { 
                    cursor
                    items { 
                        id 
                        name 
                        state
                        created_at
                        updated_at
                        creator { id name email }
                        group { id title }
                        board { id name }
                        column_values { 
                            id 
                            text 
                            value 
                            type 
                            column { id title type }
                        }
                    } 
                }"
                $fields += $itemsQuery
                Write-Verbose -Message "Including items with limit: $ItemsLimit, page: $ItemsPage"
            }
            
            if ($IncludeUpdates) {
                $fields += @(
                    'updates (limit: 50) { 
                        id 
                        body 
                        created_at 
                        updated_at 
                        creator { id name email }
                        replies { id body created_at creator { id name email } }
                    }'
                )
                Write-Verbose -Message "Including updates"
            }
            
            if ($IncludeSubscribers) {
                $fields += 'subscribers { id name email }'
                Write-Verbose -Message "Including subscribers"
            }
            
            if ($IncludeViews) {
                $fields += @(
                    'views { 
                        id 
                        name 
                        type 
                        settings_str 
                    }'
                )
                Write-Verbose -Message "Including views"
            }
            
            # Construct the query
            $fieldString = $fields -join ' '
            $query = "query { boards (ids: [$BoardId]) { $fieldString } }"
            
            Write-Verbose -Message "GraphQL Query length: $($query.Length) characters"
            
            # Execute the query
            $response = Invoke-MondayApi -Query $query
            
            if ($response.boards -and $response.boards.Count -gt 0) {
                $board = $response.boards[0]
                
                # Add type information
                $board.PSObject.TypeNames.Insert(0, 'Monday.BoardDetail')
                
                Write-Verbose -Message "Retrieved detailed information for board: $($board.name)"
                return $board
            }
            else {
                Write-Warning -Message "Board with ID $BoardId not found or access denied"
                return $null
            }
        }
        catch {
            $errorMessage = "Error retrieving Monday board detail for ID ${BoardId}: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
