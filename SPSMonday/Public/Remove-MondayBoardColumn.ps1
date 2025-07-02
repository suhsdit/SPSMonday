Function Remove-MondayBoardColumn {
<#
.SYNOPSIS
    Delete a column from a Monday.com board
.DESCRIPTION
    This function deletes a column from a Monday.com board using the Monday.com API.
    WARNING: This permanently deletes the column and all data in it. This action cannot be undone.
.PARAMETER BoardId
    The ID of the board containing the column to delete
.PARAMETER ColumnId
    The ID of the column to delete
.PARAMETER Confirm
    Prompt for confirmation before deleting the column (recommended for safety)
.PARAMETER PassThru
    Return information about the deleted column
.EXAMPLE
    Remove-MondayBoardColumn -BoardId 1234567890 -ColumnId "status_column"
    
    Deletes the specified column (with confirmation prompt)
.EXAMPLE
    Remove-MondayBoardColumn -BoardId 1234567890 -ColumnId "old_column" -Confirm:$false
    
    Deletes the column without confirmation prompt
.EXAMPLE
    Remove-MondayBoardColumn -BoardId 1234567890 -ColumnId "temp_column" -PassThru
    
    Deletes the column and returns information about the deleted column
.EXAMPLE
    Get-MondayBoardColumn -BoardId 1234567890 | Where-Object { $_.Title -like "*temp*" } | Remove-MondayBoardColumn
    
    Pipeline example: Deletes all columns with "temp" in the title
.INPUTS
    System.Int64
    System.String
.OUTPUTS
    System.String (default)
    Monday.Column (when -PassThru is used)
.NOTES
    - This permanently deletes the column and ALL DATA in it
    - The deletion cannot be undone
    - Use -Confirm parameter for safety
    - This function requires 'boards:write' scope in your API token
    
    WARNING: Be very careful when using this function as it permanently removes data!
.LINK
    https://developer.monday.com/api-reference/reference/columns#delete-column
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param(
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true)]
        [Alias('board_id')]
        [Int64]$BoardId,
        
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [Alias('Id', 'ColumnID')]
        [String]$ColumnId,
        
        [Parameter(Mandatory=$false)]
        [Switch]$PassThru
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
        
        # Collection to hold all column deletions for batch processing
        $allDeletions = @()
    }
    
    Process {
        # Collect all deletion requests for batch processing
        $allDeletions += @{
            BoardId = $BoardId
            ColumnId = $ColumnId
        }
    }
    
    End {
        try {
            Write-Verbose -Message "Processing deletion of $($allDeletions.Count) column(s)"
            
            if ($allDeletions.Count -eq 0) {
                Write-Warning -Message "No columns specified for deletion"
                return
            }
            
            $results = @()
            $successCount = 0
            
            foreach ($deletion in $allDeletions) {
                $currentBoardId = $deletion.BoardId
                $currentColumnId = $deletion.ColumnId
                
                # Confirm action if requested
                $target = "column '$currentColumnId' from board $currentBoardId"
                if ($PSCmdlet.ShouldProcess($target, "permanently delete column and all its data")) {
                    Write-Verbose -Message "Deleting column '$currentColumnId' from board $currentBoardId"
                    
                    # Build the mutation
                    $mutation = "mutation { delete_column (board_id: $currentBoardId, column_id: `"$currentColumnId`") { id title type } }"
                    
                    Write-Verbose -Message "GraphQL Mutation: $mutation"
                    
                    # Execute the mutation
                    try {
                        $response = Invoke-MondayApi -Query $mutation
                        
                        if ($response.delete_column -and $response.delete_column.id) {
                            $deletedColumn = $response.delete_column
                            $successCount++
                            
                            if ($PassThru) {
                                # Create return object with deletion details
                                $result = [PSCustomObject]@{
                                    ColumnId = $deletedColumn.id
                                    Title = $deletedColumn.title
                                    Type = $deletedColumn.type
                                    BoardId = $currentBoardId
                                    Action = "PermanentlyDeleted"
                                    Timestamp = Get-Date
                                    Recoverable = $false
                                }
                                $result.PSObject.TypeNames.Insert(0, 'Monday.DeletedColumn')
                                $results += $result
                            }
                            
                            Write-Verbose -Message "Successfully deleted column '$currentColumnId' ('$($deletedColumn.title)') from board $currentBoardId"
                        }
                        else {
                            Write-Warning -Message "No confirmation received for deletion of column '$currentColumnId' from board $currentBoardId"
                        }
                    }
                    catch {
                        $errorMessage = "Failed to delete column '$currentColumnId' from board ${currentBoardId}: $($_.Exception.Message)"
                        Write-Error -Message $errorMessage
                        
                        # Continue processing other columns even if one fails
                        continue
                    }
                }
                else {
                    Write-Verbose -Message "Skipped deletion of column '$currentColumnId' from board $currentBoardId (user declined or WhatIf)"
                }
            }
            
            # Return results
            if ($PassThru) {
                return $results
            }
            else {
                # Return summary message based on actual success count
                if ($successCount -gt 0) {
                    $summary = "Successfully deleted $successCount column(s)"
                    Write-Verbose -Message $summary
                    return $summary
                }
                else {
                    return "No columns were deleted"
                }
            }
        }
        catch {
            $errorMessage = "Error during column deletion operation: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
        finally {
            Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
        }
    }
}
