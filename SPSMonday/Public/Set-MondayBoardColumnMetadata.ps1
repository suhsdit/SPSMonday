Function Set-MondayBoardColumnMetadata {
<#
.SYNOPSIS
    Update metadata properties of a Monday.com board column
.DESCRIPTION
    This function updates the metadata of an existing column on a Monday.com board using the Monday.com API.
    Currently supports updating the column's title and description properties.
.PARAMETER BoardId
    The ID of the board containing the column
.PARAMETER ColumnId
    The ID of the column to update
.PARAMETER Property
    The metadata property to update (title or description)
.PARAMETER Value
    The new value for the specified property
.PARAMETER PassThru
    Return the updated column information
.EXAMPLE
    Set-MondayBoardColumnMetadata -BoardId 1234567890 -ColumnId "status" -Property description -Value "Current project status"
    
    Updates the description of the status column
.EXAMPLE
    Set-MondayBoardColumnMetadata -BoardId 1234567890 -ColumnId "person" -Property title -Value "Project Manager"
    
    Updates the title of the person column
.EXAMPLE
    Set-MondayBoardColumnMetadata -BoardId 1234567890 -ColumnId "date4" -Property description -Value "Project deadline" -PassThru
    
    Updates the description and returns the updated column information
.INPUTS
    System.Int64
    System.String
.OUTPUTS
    System.String (default)
    Monday.Column (when -PassThru is used)
.NOTES
    This function requires 'boards:write' scope in your API token.
    Currently only supports updating 'title' and 'description' properties.
.LINK
    https://developer.monday.com/api-reference/reference/columns#change-column-metadata
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true)]
        [Alias('board_id')]
        [Int64]$BoardId,
        
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [Alias('Id')]
        [String]$ColumnId,
        
        [Parameter(Mandatory=$true,
            Position=1)]
        [ValidateSet('title', 'description')]
        [String]$Property,
        
        [Parameter(Mandatory=$true,
            Position=2)]
        [String]$Value,
        
        [Parameter(Mandatory=$false)]
        [Switch]$PassThru
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
    }
    
    Process {
        try {
            Write-Verbose -Message "Updating $Property of column '$ColumnId' on board $BoardId to '$Value'"
            
            # Build the mutation arguments
            $mutationArgs = @(
                "board_id: $BoardId"
                "column_id: `"$ColumnId`""
                "column_property: $Property"
                "value: `"$($Value -replace '"', '\"')`""
            )
            
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
            $mutation = "mutation { change_column_metadata ($argumentString) { $fieldString } }"
            
            Write-Verbose -Message "GraphQL Mutation: $mutation"
            
            # Execute the mutation
            $response = Invoke-MondayApi -Query $mutation
            
            if ($response.change_column_metadata) {
                $updatedColumn = $response.change_column_metadata
                
                if ($PassThru) {
                    # Add type information and return the column
                    $updatedColumn.PSObject.TypeNames.Insert(0, 'Monday.Column')
                    Write-Verbose -Message "Successfully updated column metadata and returning updated object"
                    return $updatedColumn
                }
                else {
                    # Return success message
                    $newValue = if ($Property -eq 'title') { $updatedColumn.title } else { $updatedColumn.description }
                    $message = "Successfully updated $Property of column '$ColumnId' to '$newValue'"
                    Write-Verbose -Message $message
                    return $message
                }
            }
            else {
                throw "No response data received from Monday.com API"
            }
        }
        catch {
            $errorMessage = "Error updating column metadata for column '$ColumnId' on board ${BoardId}: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
