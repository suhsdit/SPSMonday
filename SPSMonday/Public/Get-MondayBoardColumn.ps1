Function Get-MondayBoardColumn {
<#
.SYNOPSIS
    Get column information for a Monday.com board
.DESCRIPTION
    This function retrieves detailed column information for a Monday.com board,
    including column IDs, types, and descriptions for use with Set-MondayBoardItem.
.PARAMETER BoardId
    The ID of the board to get column information from
.PARAMETER IncludeExamples
    Include example formatting for each column type to help with Set-MondayBoardItem usage
.EXAMPLE
    Get-MondayBoardColumn -BoardId 1234567890
    
    Gets all column information for the specified board
.EXAMPLE
    Get-MondayBoardColumn -BoardId 1234567890 -IncludeExamples
    
    Gets column information including example formatting for each column type
.EXAMPLE
    Get-MondayBoardColumn -BoardId 1234567890 | Where-Object Type -eq "status"
    
    Gets only status columns from the board
.EXAMPLE
    $columns = Get-MondayBoardColumn -BoardId 1234567890
    $columns | Format-Table -AutoSize
    
    Gets column information and displays it in a formatted table
.INPUTS
    System.Int64
.OUTPUTS
    PSCustomObject[]
.NOTES
    This function helps users understand the column structure before using Set-MondayBoardItem.
    The Type field shows the Monday.com column type, which determines the expected data format.
    Use -IncludeExamples to see example formatting for each column type.
.LINK
    https://developer.monday.com/api-reference/reference/column-types-reference
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
        [Switch]$IncludeExamples
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
    }
    
    Process {
        try {
            Write-Verbose -Message "Getting column information for board ID: $BoardId"
            
            # Get board details with columns
            $board = Get-MondayBoardDetail -BoardId $BoardId -IncludeColumns
            
            if ($board -and $board.columns) {
                Write-Verbose -Message "Found $($board.columns.Count) columns"
                
                # Return user-friendly column info
                $board.columns | ForEach-Object {
                    $column = $_
                    
                    # Create base object with essential properties
                    $columnInfo = [PSCustomObject]@{
                        ColumnId = $column.id
                        Title = $column.title
                        Type = $column.type
                        Description = $column.description
                        Archived = $column.archived
                    }
                    
                    # Add example format if requested
                    if ($IncludeExamples) {
                        $exampleFormat = switch ($column.type) {
                            'status' { '"Working on it"  # Status label name' }
                            'dropdown' { '"Option 1"  # Dropdown option name' }
                            'date' { '"2025-07-15"  # ISO date format' }
                            'people' { '17582583  # User ID (auto-formatted)' }
                            'person' { '17582583  # User ID (auto-formatted)' }
                            'text' { '"Simple text value"  # Plain text' }
                            'long_text' { '"Long text content"  # Multi-line text' }
                            'numbers' { '42  # Numeric value' }
                            'rating' { '5  # Rating value (1-5)' }
                            'checkbox' { '@{ "checked" = "true" }  # Boolean' }
                            'timeline' { '@{ "from" = "2025-07-01"; "to" = "2025-07-15" }  # Date range' }
                            'email' { '@{ "email" = "user@domain.com"; "text" = "Display Name" }  # Email' }
                            'phone' { '@{ "phone" = "+1234567890"; "countryShortName" = "US" }  # Phone' }
                            'link' { '@{ "url" = "https://example.com"; "text" = "Link Text" }  # URL' }
                            'location' { '@{ "address" = "123 Main St"; "lat" = 40.7128; "lng" = -74.0060 }  # Location' }
                            'tags' { '@{ "tag_ids" = @(123, 456) }  # Tag IDs array' }
                            'formula' { '# Read-only, calculated field' }
                            'autonumber' { '# Auto-generated, read-only' }
                            'creation_log' { '# Auto-generated, read-only' }
                            'last_updated' { '# Auto-generated, read-only' }
                            'mirror' { '# Mirrored from another board' }
                            default { '"Check Monday.com column types docs"  # Complex type' }
                        }
                        
                        # Add the ExampleFormat property
                        $columnInfo | Add-Member -MemberType NoteProperty -Name "ExampleFormat" -Value $exampleFormat
                    }
                    
                    # Return the column info object
                    $columnInfo
                }
            }
            else {
                Write-Warning -Message "No columns found for board $BoardId or board not accessible"
                return @()
            }
        }
        catch {
            $errorMessage = "Error retrieving column information for board ${BoardId}: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
