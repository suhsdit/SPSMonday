Function New-MondayBoardColumn {
<#
.SYNOPSIS
    Create a new column on a Monday.com board
.DESCRIPTION
    This function creates a new column on a Monday.com board using the Monday.com API.
    You can specify the column type, title, description, and positioning. For status and 
    dropdown columns, you can also define custom labels.
.PARAMETER BoardId
    The ID of the board where the column will be created
.PARAMETER Title
    The title/name of the new column
.PARAMETER ColumnType
    The type of column to create (status, text, numbers, date, person, etc.)
.PARAMETER Description
    Optional description for the column
.PARAMETER ColumnId
    Optional custom ID for the column. Must be 1-20 characters, lowercase letters and underscores only.
    Must be unique on the board and cannot be reused even if previously deleted.
.PARAMETER AfterColumnId
    The ID of the column after which this new column should be positioned
.PARAMETER Defaults
    JSON string containing default settings for the column (especially useful for status/dropdown columns with custom labels)
.PARAMETER StatusLabels
    Hashtable of status labels for status columns. Keys are label IDs (numbers), values are label names.
    Example: @{ "1" = "Not Started"; "2" = "In Progress"; "3" = "Done" }
.PARAMETER DropdownOptions
    Array of dropdown option names for dropdown columns.
    Example: @("Option 1", "Option 2", "Option 3")
.EXAMPLE
    New-MondayBoardColumn -BoardId 1234567890 -Title "Priority" -ColumnType status
    
    Creates a basic status column with default labels
.EXAMPLE
    New-MondayBoardColumn -BoardId 1234567890 -Title "Project Status" -ColumnType status -StatusLabels @{
        "1" = "Planning"
        "2" = "In Progress" 
        "3" = "Review"
        "4" = "Complete"
    }
    
    Creates a status column with custom labels
.EXAMPLE
    New-MondayBoardColumn -BoardId 1234567890 -Title "Department" -ColumnType dropdown -DropdownOptions @("Engineering", "Marketing", "Sales", "Support")
    
    Creates a dropdown column with predefined options
.EXAMPLE
    New-MondayBoardColumn -BoardId 1234567890 -Title "Due Date" -ColumnType date -Description "Project deadline" -AfterColumnId "status"
    
    Creates a date column positioned after the status column
.INPUTS
    System.Int64
.OUTPUTS
    Monday.Column
.NOTES
    This function requires 'boards:write' scope in your API token.
    
    Common column types:
    - text: Plain text column
    - numbers: Numeric values
    - status: Status with colored labels
    - dropdown: Dropdown selection
    - date: Date picker
    - person: People/team assignment
    - timeline: Date range
    - checkbox: Boolean checkbox
    - rating: Star rating
    - email: Email addresses
    - phone: Phone numbers
    - link: URLs
    - location: Geographic location
    - tags: Tag selection
.LINK
    https://developer.monday.com/api-reference/reference/columns#create-column
.LINK
    https://developer.monday.com/api-reference/reference/column-types-reference
#>
    [CmdletBinding(DefaultParameterSetName = 'Basic')]
    Param(
        [Parameter(Mandatory=$true)]
        [Int64]$BoardId,
        
        [Parameter(Mandatory=$true)]
        [String]$Title,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('status', 'text', 'numbers', 'date', 'person', 'dropdown', 
                     'timeline', 'checkbox', 'rating', 'email', 'phone', 'link', 
                     'location', 'tags', 'long_text', 'color_picker', 'country',
                     'hour', 'week', 'item_id', 'creation_log', 'last_updated')]
        [String]$ColumnType,
        
        [Parameter(Mandatory=$false)]
        [String]$Description,
        
        [Parameter(Mandatory=$false)]
        [ValidatePattern('^[a-z_]{1,20}$')]
        [String]$ColumnId,
        
        [Parameter(Mandatory=$false)]
        [String]$AfterColumnId,
        
        [Parameter(Mandatory=$false, ParameterSetName = 'Advanced')]
        [String]$Defaults,
        
        [Parameter(Mandatory=$false, ParameterSetName = 'StatusLabels')]
        [Hashtable]$StatusLabels,
        
        [Parameter(Mandatory=$false, ParameterSetName = 'DropdownOptions')]
        [String[]]$DropdownOptions
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
    }
    
    Process {
        try {
            Write-Verbose -Message "Creating new column '$Title' of type '$ColumnType' on board $BoardId"
            
            # Build the mutation arguments
            $mutationArgs = @(
                "board_id: $BoardId"
                "title: `"$($Title -replace '"', '\"')`""
                "column_type: $ColumnType"
            )
            
            if ($Description) {
                $mutationArgs += "description: `"$($Description -replace '"', '\"')`""
                Write-Verbose -Message "Including description: $Description"
            }
            
            if ($ColumnId) {
                $mutationArgs += "id: `"$ColumnId`""
                Write-Verbose -Message "Using custom column ID: $ColumnId"
            }
            
            if ($AfterColumnId) {
                $mutationArgs += "after_column_id: `"$AfterColumnId`""
                Write-Verbose -Message "Positioning after column: $AfterColumnId"
            }
            
            # Handle defaults based on parameter set
            $defaultsJson = ""
            
            if ($PSCmdlet.ParameterSetName -eq 'StatusLabels' -and $StatusLabels) {
                # Build status column defaults
                $labelsObject = @{ "labels" = $StatusLabels }
                $defaultsJson = ($labelsObject | ConvertTo-Json -Compress -Depth 3)
                Write-Verbose -Message "Creating status column with custom labels: $($StatusLabels.Keys.Count) labels"
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'DropdownOptions' -and $DropdownOptions) {
                # Build dropdown column defaults
                $dropdownLabels = @()
                for ($i = 0; $i -lt $DropdownOptions.Count; $i++) {
                    $dropdownLabels += @{
                        "id" = $i + 1
                        "name" = $DropdownOptions[$i]
                    }
                }
                $settingsObject = @{ "settings" = @{ "labels" = $dropdownLabels } }
                $defaultsJson = ($settingsObject | ConvertTo-Json -Compress -Depth 4)
                Write-Verbose -Message "Creating dropdown column with options: $($DropdownOptions -join ', ')"
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Advanced' -and $Defaults) {
                $defaultsJson = $Defaults
                Write-Verbose -Message "Using provided defaults JSON"
            }
            
            if ($defaultsJson) {
                # Escape the JSON string for GraphQL
                $escapedDefaults = $defaultsJson -replace '\\', '\\\\' -replace '"', '\"'
                $mutationArgs += "defaults: `"$escapedDefaults`""
            }
            
            # Build the response fields
            $responseFields = @(
                'id',
                'title',
                'type',
                'description',
                'settings_str',
                'width',
                'archived'
            )
            
            $fieldString = $responseFields -join ' '
            $argumentString = $mutationArgs -join ', '
            
            # Build the complete mutation
            $mutation = "mutation { create_column ($argumentString) { $fieldString } }"
            
            Write-Verbose -Message "GraphQL Mutation: $mutation"
            
            # Execute the mutation
            $response = Invoke-MondayApi -Query $mutation
            
            if ($response.create_column) {
                $newColumn = $response.create_column
                
                # Add type information
                $newColumn.PSObject.TypeNames.Insert(0, 'Monday.Column')
                
                Write-Verbose -Message "Successfully created column $($newColumn.id) ('$($newColumn.title)')"
                return $newColumn
            }
            else {
                Write-Error -Message "Failed to create column - no response received from API"
            }
        }
        catch {
            $errorMessage = "Error creating column '$Title' on board ${BoardId}: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
