Function Set-MondayBoardColumnTitle {
<#
.SYNOPSIS
    Change the title of a Monday.com board column
.DESCRIPTION
    This function updates the title of an existing column on a Monday.com board using the Monday.com API.
    This is useful for renaming columns to better reflect their purpose or for standardizing naming conventions.
.PARAMETER BoardId
    The ID of the board containing the column
.PARAMETER ColumnId
    The ID of the column to rename
.PARAMETER NewTitle
    The new title for the column
.PARAMETER PassThru
    Return the updated column information
.EXAMPLE
    Set-MondayBoardColumnTitle -BoardId 1234567890 -ColumnId "status" -NewTitle "Project Status"
    
    Changes the title of the status column to "Project Status"
.EXAMPLE
    Set-MondayBoardColumnTitle -BoardId 1234567890 -ColumnId "person" -NewTitle "Assigned To" -PassThru
    
    Changes the title and returns the updated column information
.EXAMPLE
    Get-MondayBoardColumn -BoardId 1234567890 | Where-Object { $_.Title -eq "Old Name" } | Set-MondayBoardColumnTitle -NewTitle "New Name"
    
    Pipeline example: Finds a column by title and renames it
.INPUTS
    System.Int64
    System.String
.OUTPUTS
    System.String (default)
    Monday.Column (when -PassThru is used)
.NOTES
    This function requires 'boards:write' scope in your API token.
    Only the column title is changed - the column type, data, and settings remain the same.
.LINK
    https://developer.monday.com/api-reference/reference/columns#change-column-title
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
        [String]$NewTitle,
        
        [Parameter(Mandatory=$false)]
        [Switch]$PassThru
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
    }
    
    Process {
        try {
            Write-Verbose -Message "Changing title of column '$ColumnId' on board $BoardId to '$NewTitle'"
            
            # Build the mutation arguments
            $mutationArgs = @(
                "board_id: $BoardId"
                "column_id: `"$ColumnId`""
                "title: `"$($NewTitle -replace '"', '\"')`""
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
            $mutation = "mutation { change_column_title ($argumentString) { $fieldString } }"
            
            Write-Verbose -Message "GraphQL Mutation: $mutation"
            
            # Execute the mutation
            $response = Invoke-MondayApi -Query $mutation
            
            if ($response.change_column_title) {
                $updatedColumn = $response.change_column_title
                
                if ($PassThru) {
                    # Add type information and return the column
                    $updatedColumn.PSObject.TypeNames.Insert(0, 'Monday.Column')
                    Write-Verbose -Message "Successfully updated column title and returning updated object"
                    return $updatedColumn
                }
                else {
                    # Return success message
                    $message = "Successfully changed title of column '$ColumnId' to '$($updatedColumn.title)'"
                    Write-Verbose -Message $message
                    return $message
                }
            }
            else {
                throw "No response data received from Monday.com API"
            }
        }
        catch {
            $errorMessage = "Error updating column title for column '$ColumnId' on board ${BoardId}: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
    }
    
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}
