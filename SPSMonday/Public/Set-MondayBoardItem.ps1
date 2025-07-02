Function Set-MondayBoardItem {
<#
.SYNOPSIS
    Update column values for a Monday.com item
.DESCRIPTION
    This function updates column values for a specific Monday.com item using the Monday.com API.
    It supports updating any column type by providing column values as a hashtable or JSON string.
    The function can update a single column or multiple columns in one operation.
.PARAMETER ItemId
    The ID of the item to update
.PARAMETER BoardId
    The ID of the board containing the item (required for some API operations)
.PARAMETER ColumnValues
    Hashtable of column values to update. Keys should be column IDs, values should be the data for that column.
    The value format depends on the column type (see Monday.com column types documentation).
.PARAMETER ColumnValuesJson
    JSON string containing the column values to update. Use this for complex column types or when you have 
    pre-formatted JSON. This parameter is mutually exclusive with ColumnValues.
.PARAMETER CreateLabelsIfMissing
    Creates status/dropdown labels if they are missing (requires permission to change board structure)
.PARAMETER ReturnUpdatedItem
    Return the updated item object after the update operation
.EXAMPLE
    Set-MondayBoardItem -ItemId 1234567890 -ColumnValues @{ "status" = "Done"; "text" = "Updated text" }
    
    Updates the status and text columns for the specified item
.EXAMPLE
    $columnData = @{
        "status" = "In Progress"
        "date" = "2025-07-15"
        "numbers" = 42
        "text" = "Updated via PowerShell"
    }
    Set-MondayBoardItem -ItemId 1234567890 -ColumnValues $columnData -ReturnUpdatedItem
    
    Updates multiple columns and returns the updated item
.EXAMPLE
    $jsonData = '{"status":{"label":"Done"},"date":"2025-07-15","text":"Updated text"}'
    Set-MondayBoardItem -ItemId 1234567890 -ColumnValuesJson $jsonData
    
    Updates columns using pre-formatted JSON
.EXAMPLE
    Get-MondayItem -BoardIds @(1234567890) | ForEach-Object { 
        Set-MondayBoardItem -ItemId $_.id -ColumnValues @{ "status" = "Reviewed" } 
    }
    
    Pipeline example: Updates the status column for all items in a board
.INPUTS
    System.Int64
.OUTPUTS
    Monday.Item (when ReturnUpdatedItem is specified)
    System.String (success message when ReturnUpdatedItem is not specified)
.NOTES
    Column value formats vary by column type:
    - Text: Simple string value
    - Status: String with label name, or object with label property
    - Date: ISO date string (YYYY-MM-DD)
    - Numbers: Numeric value
    - Person: User ID or array of user IDs
    - Timeline: Object with from/to dates
    
    For complex column types, refer to the Monday.com column types documentation.
    
    This function requires 'boards:write' scope in your API token.
.LINK
    https://developer.monday.com/api-reference/reference/column-types-reference
.LINK
    https://developer.monday.com/api-reference/reference/items#change-column-values
#>
    [CmdletBinding(DefaultParameterSetName = 'Hashtable')]
    Param(
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [Alias('Id')]
        [Int64]$ItemId,
        
        [Parameter(Mandatory=$false)]
        [Int64]$BoardId,
        
        [Parameter(Mandatory=$true, ParameterSetName = 'Hashtable')]
        [Hashtable]$ColumnValues,
        
        [Parameter(Mandatory=$true, ParameterSetName = 'Json')]
        [String]$ColumnValuesJson,
        
        [Parameter(Mandatory=$false)]
        [Switch]$CreateLabelsIfMissing,
        
        [Parameter(Mandatory=$false)]
        [Switch]$ReturnUpdatedItem
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
        Write-Verbose -Message "Parameter Set: $($PSCmdlet.ParameterSetName)"
    }
    
    Process {
        try {
            Write-Verbose -Message "Updating item ID: $ItemId"
            
            # Build the column values JSON string
            $columnValuesString = ""
            
            if ($PSCmdlet.ParameterSetName -eq 'Hashtable') {
                # Convert hashtable to JSON
                Write-Verbose -Message "Converting hashtable to JSON for $($ColumnValues.Keys.Count) columns"
                
                # Build a proper JSON object for Monday.com API
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
            }
            else {
                # Use the provided JSON string
                $columnValuesString = $ColumnValuesJson
                Write-Verbose -Message "Using provided JSON string"
            }
            
            Write-Verbose -Message "Column values JSON: $columnValuesString"
            
            # Escape the JSON string for GraphQL
            $escapedJson = $columnValuesString -replace '\\', '\\\\' -replace '"', '\"'
            
            # Build the mutation arguments
            $mutationArgs = @(
                "item_id: $ItemId"
                "column_values: `"$escapedJson`""
            )
            
            if ($BoardId) {
                $mutationArgs += "board_id: $BoardId"
                Write-Verbose -Message "Including board ID: $BoardId"
            }
            
            if ($CreateLabelsIfMissing) {
                $mutationArgs += "create_labels_if_missing: true"
                Write-Verbose -Message "Will create missing labels if needed"
            }
            
            # Determine which mutation to use
            # Monday.com has both change_column_value (single) and change_multiple_column_values (multiple)
            # We'll use change_multiple_column_values for flexibility
            $mutationName = "change_multiple_column_values"
            $argumentString = $mutationArgs -join ', '
            
            # Build the response fields
            $responseFields = @(
                'id',
                'name', 
                'state',
                'updated_at'
            )
            
            if ($ReturnUpdatedItem) {
                # Include more fields when returning the updated item
                $responseFields += @(
                    'created_at',
                    'creator { id name email }',
                    'board { id name }',
                    'group { id title }',
                    'column_values { 
                        id 
                        text 
                        value 
                        type
                        column { id title type }
                    }'
                )
                Write-Verbose -Message "Will return updated item with full details"
            }
            
            $fieldString = $responseFields -join ' '
            
            # Build the complete mutation
            $mutation = "mutation { $mutationName ($argumentString) { $fieldString } }"
            
            Write-Verbose -Message "GraphQL Mutation: $mutation"
            
            # Execute the mutation
            $response = Invoke-MondayApi -Query $mutation
            
            if ($response.$mutationName) {
                $updatedItem = $response.$mutationName
                
                if ($ReturnUpdatedItem) {
                    # Add type information and return the item
                    $updatedItem.PSObject.TypeNames.Insert(0, 'Monday.Item')
                    Write-Verbose -Message "Successfully updated item $ItemId and returning updated object"
                    return $updatedItem
                }
                else {
                    # Return success message
                    $message = "Successfully updated item $ItemId"
                    if ($updatedItem.name) {
                        $message += " ('$($updatedItem.name)')"
                    }
                    Write-Verbose -Message $message
                    return $message
                }
            }
            else {
                throw "No response data received from Monday.com API"
            }
        }
        catch {
            $errorMessage = "Error updating Monday item ${ItemId}: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
