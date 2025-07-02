Function Remove-MondayBoardItem {
<#
.SYNOPSIS
    Remove (delete or archive) Monday.com board items
.DESCRIPTION
    This function removes Monday.com board items using the Monday.com API.
    By default, items are permanently deleted. Use -Archive to archive items instead (soft delete).
    Multiple items can be removed in a single operation for efficiency.
.PARAMETER ItemId
    The ID(s) of the item(s) to remove. Accepts single ID or array of IDs.
.PARAMETER BoardId
    The ID of the board containing the item(s). This parameter is for reference and validation purposes only - the Monday.com API identifies items uniquely without requiring board context for removal operations.
.PARAMETER Archive
    Archive the item(s) instead of permanently deleting them. Archived items can be restored from the Monday.com interface.
.PARAMETER Confirm
    Prompt for confirmation before removing items (especially useful for permanent deletion)
.PARAMETER PassThru
    Return information about the removed items
.EXAMPLE
    Remove-MondayBoardItem -ItemId 1234567890
    
    Permanently deletes the specified item
.EXAMPLE
    Remove-MondayBoardItem -ItemId 1234567890 -BoardId 9876543210
    
    Permanently deletes the specified item from a specific board
.EXAMPLE
    Remove-MondayBoardItem -ItemId 1234567890 -Archive
    
    Archives the specified item (soft delete - can be restored)
.EXAMPLE
    Remove-MondayBoardItem -ItemId @(1234567890, 1234567891, 1234567892) -Archive -Confirm:$false
    
    Archives multiple items without confirmation prompt
.EXAMPLE
    Get-MondayBoardItem -BoardId 1234567890 | Where-Object {$_.name -like "*test*"} | Remove-MondayBoardItem
    
    Pipeline example: Permanently deletes all items with "test" in the name
.EXAMPLE
    Remove-MondayBoardItem -ItemId 1234567890 -Archive -PassThru
    
    Archives an item and returns information about the removed item
.INPUTS
    System.Int64
    System.Int64[]
.OUTPUTS
    System.String (default)
    PSCustomObject (when -PassThru is used)
.NOTES
    - By default, items are permanently deleted and cannot be recovered
    - Use -Archive to archive items instead - archived items can be restored from the Monday.com web interface
    - Use -Confirm parameter for safety with permanent deletions
    - Monday.com API rate limits apply for bulk operations
.LINK
    https://developer.monday.com/api-reference/reference/items
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    Param(
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [Alias('Id')]
        [Int64[]]$ItemId,
        
        [Parameter(Mandatory=$false)]
        [Int64]$BoardId,
        
        [Parameter(Mandatory=$false)]
        [Switch]$Archive,
        
        [Parameter(Mandatory=$false)]
        [Switch]$PassThru
    )
    
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName)..."
        
        # Collection to hold all item IDs for batch processing
        $allItemIds = @()
    }
    
    Process {
        # Collect all item IDs for batch processing
        $allItemIds += $ItemId
    }
    
    End {
        try {
            Write-Verbose -Message "Processing removal of $($allItemIds.Count) item(s)"
            
            if ($allItemIds.Count -eq 0) {
                Write-Warning -Message "No items specified for removal"
                return
            }
            
            # Determine the action and mutation to use
            $action = if ($Archive) { "archive" } else { "permanently delete" }
            
            # Monday.com API mutations for item removal
            # For archiving: archive_item
            # For permanent deletion: delete_item  
            $mutationName = if ($Archive) { "archive_item" } else { "delete_item" }
            
            # Process items individually or in batches depending on the API limitations
            $results = @()
            $successCount = 0
            
            foreach ($singleItemId in $allItemIds) {
                # Confirm action if requested
                $target = "item $singleItemId"
                if ($PSCmdlet.ShouldProcess($target, $action)) {
                    Write-Verbose -Message "$(if ($Archive) { 'Archiving' } else { 'Permanently deleting' }) item ID: $singleItemId"
                    
                    # Build the mutation - archive_item and delete_item only take item_id, not board_id
                    $mutation = "mutation { $mutationName (item_id: $singleItemId) { id } }"
                    
                    if ($BoardId) {
                        Write-Verbose -Message "Board ID provided: $BoardId (for context only, not used in mutation)"
                    }
                    
                    Write-Verbose -Message "GraphQL Mutation: $mutation"
                    
                    # Execute the mutation
                    try {
                        $response = Invoke-MondayApi -Query $mutation
                        
                        if ($response.$mutationName -and $response.$mutationName.id) {
                            $removedId = $response.$mutationName.id
                            $successCount++
                            
                            if ($PassThru) {
                                # Create return object with removal details
                                $result = [PSCustomObject]@{
                                    ItemId = [Int64]$removedId
                                    Action = if ($Archive) { "Archived" } else { "PermanentlyDeleted" }
                                    Timestamp = Get-Date
                                    Recoverable = $Archive
                                }
                                $result.PSObject.TypeNames.Insert(0, 'Monday.RemovedItem')
                                $results += $result
                            }
                            
                            $actionPast = if ($Archive) { "archived" } else { "permanently deleted" }
                            Write-Verbose -Message "Successfully $actionPast item $removedId"
                        }
                        else {
                            Write-Warning -Message "No confirmation received for removal of item $singleItemId"
                        }
                    }
                    catch {
                        $errorMessage = "Failed to remove item ${singleItemId}: $($_.Exception.Message)"
                        Write-Error -Message $errorMessage
                        
                        # Continue processing other items even if one fails
                        continue
                    }
                }
                else {
                    Write-Verbose -Message "Skipped removal of item $singleItemId (user declined or WhatIf)"
                }
            }
            
            # Return results
            if ($PassThru) {
                return $results
            }
            else {
                # Return summary message based on actual success count
                if ($successCount -gt 0) {
                    $actionPast = if ($Archive) { "archived" } else { "permanently deleted" }
                    $summary = "Successfully $actionPast $successCount item(s)"
                    Write-Verbose -Message $summary
                    return $summary
                }
                else {
                    return "No items were removed"
                }
            }
        }
        catch {
            $errorMessage = "Error during item removal operation: $($_.Exception.Message)"
            Write-Error -Message $errorMessage
            throw $_
        }
        finally {
            Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
        }
    }
}
