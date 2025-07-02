Function New-MondayBoardItem {
<#
.SYNOPSIS
    Create a new item (row) in a Monday.com board
.DESCRIPTION
    This function creates a new item in a Monday.com board using the Monday.com API.
    You can specify the item name and optionally set initial column values when creating the item.
    The function supports all Monday.com column types and provides smart data formatting.
.PARAMETER BoardId
    The ID of the board where the item will be created
.PARAMETER ItemName
    The name/title of the new item
.PARAMETER GroupId
    Optional group ID within the board where the item should be created. If not specified, the item will be created in the first group.
.PARAMETER ColumnValues
    Hashtable of initial column values to set when creating the item. Keys should be column IDs, values should be the data for that column.
    The value format depends on the column type (see Monday.com column types documentation).
.PARAMETER ColumnValuesJson
    JSON string containing the initial column values. Use this for complex column types or when you have 
    pre-formatted JSON. This parameter is mutually exclusive with ColumnValues.
.PARAMETER CreateLabelsIfMissing
    Creates status/dropdown labels if they are missing (requires permission to change board structure)
.PARAMETER ReturnFullItem
    Return the complete created item object with all details including column values
.EXAMPLE
    New-MondayBoardItem -BoardId 1234567890 -ItemName "New Task"
    
    Creates a new item with just a name
.EXAMPLE
    New-MondayBoardItem -BoardId 1234567890 -ItemName "Project Task" -ColumnValues @{
        "status" = "Working on it"
        "text" = "Task description"
        "date" = "2025-07-15"
        "numbers" = 42
    }
    
    Creates a new item with initial column values
.EXAMPLE
    New-MondayBoardItem -BoardId 1234567890 -ItemName "Urgent Task" -GroupId "group123" -ReturnFullItem
    
    Creates a new item in a specific group and returns the complete item object
.EXAMPLE
    1..5 | ForEach-Object {
        New-MondayBoardItem -BoardId 1234567890 -ItemName "Test Item $_" -ColumnValues @{
            "status" = "Not Started"
            "text" = "Dummy data for testing"
        }
    }
    
    Creates multiple test items with dummy data
.INPUTS
    System.Int64
.OUTPUTS
    Monday.Item
.NOTES
    This function requires 'boards:write' scope in your API token.
    Column value formats vary by column type - refer to Get-MondayBoardColumn -IncludeExamples for formatting help.
    
    Common column formats:
    - Text: Simple string value
    - Status: String with label name
    - Date: ISO date string (YYYY-MM-DD)
    - Numbers: Numeric value
    - Person: User ID or array of user IDs
.LINK
    https://developer.monday.com/api-reference/reference/items#create-item
.LINK
    https://developer.monday.com/api-reference/reference/column-types-reference
#>
    [CmdletBinding(DefaultParameterSetName = 'Hashtable')]
    Param(
        [Parameter(Mandatory=$true)]
        [Int64]$BoardId,
        
        [Parameter(Mandatory=$true)]
        [String]$ItemName,
        
        [Parameter(Mandatory=$false)]
        [String]$GroupId,
        
        [Parameter(Mandatory=$false, ParameterSetName = 'Hashtable')]
        [Hashtable]$ColumnValues = @{},
        
        [Parameter(Mandatory=$false, ParameterSetName = 'Json')]
        [String]$ColumnValuesJson,
        
        [Parameter(Mandatory=$false)]
        [Switch]$CreateLabelsIfMissing,
        
        [Parameter(Mandatory=$false)]
        [Switch]$ReturnFullItem
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
    }
    
    Process {
        try {
            Write-Verbose -Message "Creating new item '$ItemName' in board $BoardId"
            
            # Build the mutation arguments
            $mutationArgs = @(
                "board_id: $BoardId"
                "item_name: `"$($ItemName -replace '"', '\"')`""
            )
            
            if ($GroupId) {
                $mutationArgs += "group_id: `"$GroupId`""
                Write-Verbose -Message "Creating in group: $GroupId"
            }
            
            # Handle column values if provided
            if ($PSCmdlet.ParameterSetName -eq 'Hashtable' -and $ColumnValues.Count -gt 0) {
                # Convert hashtable to JSON using the same logic as Set-MondayBoardItem
                Write-Verbose -Message "Converting hashtable to JSON for $($ColumnValues.Keys.Count) columns"
                
                $jsonObject = @{}
                foreach ($columnId in $ColumnValues.Keys) {
                    $value = $ColumnValues[$columnId]
                    Write-Verbose -Message "Processing column '$columnId' with value: $value"
                    
                    # Handle different value types appropriately with smart detection
                    if ($value -is [string]) {
                        # For string values, apply smart formatting based on column ID patterns
                        if ($columnId -match "(status|dropdown)") {
                            # For status columns, wrap in label object
                            $jsonObject[$columnId] = @{ "label" = $value }
                        } 
                        elseif ($columnId -match "date" -and $value -match "^\d{4}-\d{2}-\d{2}$") {
                            # For date columns with ISO date format, use as-is
                            $jsonObject[$columnId] = $value
                        }
                        else {
                            # For other string columns (text, etc.)
                            $jsonObject[$columnId] = $value
                        }
                    }
                    elseif ($value -is [datetime]) {
                        # Convert DateTime to ISO date string
                        $jsonObject[$columnId] = $value.ToString("yyyy-MM-dd")
                    }
                    elseif ($value -is [int] -or $value -is [long]) {
                        # Handle user IDs for person columns
                        if ($columnId -match "person|people|user") {
                            # Auto-format as person column
                            $jsonObject[$columnId] = @{ "personsAndTeams" = @(@{ "id" = $value; "kind" = "person" }) }
                        } else {
                            # For numbers columns, use as-is
                            $jsonObject[$columnId] = $value
                        }
                    }
                    elseif ($value -is [array] -and $columnId -match "person|people|user") {
                        # Handle multiple user IDs for person columns
                        $personsArray = $value | ForEach-Object { @{ "id" = $_; "kind" = "person" } }
                        $jsonObject[$columnId] = @{ "personsAndTeams" = $personsArray }
                    }
                    elseif ($value -is [hashtable] -or $value -is [PSCustomObject]) {
                        # Use the object as-is for complex column types
                        $jsonObject[$columnId] = $value
                    }
                    else {
                        # For other simple types, use as-is
                        $jsonObject[$columnId] = $value
                    }
                }
                
                $columnValuesString = ($jsonObject | ConvertTo-Json -Compress -Depth 5)
                # Escape the JSON string for GraphQL
                $escapedJson = $columnValuesString -replace '\\', '\\\\' -replace '"', '\"'
                $mutationArgs += "column_values: `"$escapedJson`""
                
                Write-Verbose -Message "Column values JSON: $columnValuesString"
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Json' -and $ColumnValuesJson) {
                # Use the provided JSON string
                $escapedJson = $ColumnValuesJson -replace '\\', '\\\\' -replace '"', '\"'
                $mutationArgs += "column_values: `"$escapedJson`""
                Write-Verbose -Message "Using provided JSON string"
            }
            
            if ($CreateLabelsIfMissing) {
                $mutationArgs += "create_labels_if_missing: true"
                Write-Verbose -Message "Will create missing labels if needed"
            }
            
            # Build the response fields
            $responseFields = @(
                'id',
                'name',
                'state',
                'created_at',
                'updated_at',
                'creator { id name email }',
                'board { id name }'
            )
            
            if ($ReturnFullItem) {
                # Include more fields when returning the full item
                $responseFields += @(
                    'group { id title }',
                    'column_values { 
                        id 
                        text 
                        value 
                        type
                        column { id title type }
                    }',
                    'subitems { id name }'
                )
                Write-Verbose -Message "Will return full item details"
            }
            
            $fieldString = $responseFields -join ' '
            $argumentString = $mutationArgs -join ', '
            
            # Build the complete mutation
            $mutation = "mutation { create_item ($argumentString) { $fieldString } }"
            
            Write-Verbose -Message "GraphQL Mutation: $mutation"
            
            # Execute the mutation
            $response = Invoke-MondayApi -Query $mutation
            
            if ($response.create_item) {
                $newItem = $response.create_item
                
                # Add type information
                $newItem.PSObject.TypeNames.Insert(0, 'Monday.Item')
                
                Write-Verbose -Message "Successfully created item $($newItem.id) ('$($newItem.name)')"
                return $newItem
            }
            else {
                Write-Error -Message "Failed to create item - no response received from API"
            }
        }
        catch {
            $errorMessage = "Error creating item '$ItemName' in board ${BoardId}: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
