# SPSMonday PowerShell Module

A PowerShell module for interfacing with the Monday.com API to retrieve board data and manage Monday.com workflows.

## Features

- **Board Information Retrieval**: Get comprehensive board data from your Monday.com instance
- **Detailed Board Views**: Access detailed board information including items, columns, groups, and updates
- **Item Management**: Retrieve, filter, and update items (rows) from boards with comprehensive data
- **Flexible Filtering**: Filter boards and items by various criteria (workspace, board type, state, etc.)
- **Pipeline Support**: Seamlessly pipe objects between functions for efficient data processing
- **Robust API Integration**: Built-in authentication, error handling, and verbose logging
- **Configuration Management**: Secure storage and management of API credentials

## Available Functions

| Function | Description |
|----------|-------------|
| `Get-MondayBoard` | Retrieve board information with filtering options |
| `Get-MondayBoardDetail` | Get detailed information for a specific board |
| `Get-MondayBoardItem` | Retrieve items (rows) from Monday.com boards |
| `Set-MondayBoardItem` | Update column values for Monday.com items |
| `Get-MondayUser` | Get user information and IDs for people columns |
| `Invoke-MondayApi` | Core API function for making authenticated requests |
| `New-SPSMondayConfiguration` | Create new authentication configuration |
| `Set-SPSMondayConfiguration` | Set active configuration |
| `Get-SPSMondayConfiguration` | Get current configuration information |

## Installation

Install from PowerShell Gallery:

```powershell
Install-Module -Name SPSMonday -Scope CurrentUser
```

## Quick Start

### 1. Configure Authentication

First, get your Monday.com API token:
1. Log into your Monday.com account
2. Click on your profile picture (top right)
3. Select 'Developers'
4. Click 'My Access Tokens' > 'Show'
5. Copy your personal token

Then configure the module:

```powershell
# Import the module
Import-Module SPSMonday

# Create a new configuration
New-SPSMondayConfiguration -Name "production"

# Activate the configuration
Set-SPSMondayConfiguration -Name "production"
```

### 2. Basic Usage Examples

```powershell
# Get all boards (limited to first 25 for performance)
Get-MondayBoard -Limit 10

# Get boards from a specific workspace
Get-MondayBoard -WorkspaceIds @(12345) -Limit 5

# Filter boards by type
Get-MondayBoard -BoardKind public -Limit 20

# Get detailed information for a specific board
Get-MondayBoardDetail -BoardId 1234567890 -IncludeItems -IncludeColumns

# Get items from a board with their data
Get-MondayBoardItem -BoardIds @(1234567890) -IncludeColumnValues -Limit 50

# Update an item's column values
Set-MondayBoardItem -ItemId 1111111111 -ColumnValues @{ "status" = "Done"; "text" = "Updated text" }

# Pipeline example: Get board details for all accessible boards
Get-MondayBoard | Get-MondayBoardDetail -IncludeItems
```

## Configuration Management

The module supports multiple configuration profiles for different environments:

```powershell
# Create configurations for different environments
New-SPSMondayConfiguration -Name "production"
New-SPSMondayConfiguration -Name "staging"

# Switch between configurations
Set-SPSMondayConfiguration -Name "staging"

# Check current configuration
Get-SPSMondayConfiguration
```

## Function Reference

### Get-MondayBoard

Retrieves Monday.com boards with filtering options.

**Parameters:**
- `BoardIds` - Array of specific board IDs to retrieve
- `WorkspaceIds` - Array of workspace IDs to filter boards by
- `BoardKind` - The type of boards to retrieve (public, private, share)
- `State` - The state of boards to retrieve (active, archived, deleted, all)
- `Limit` - Maximum number of boards to return (default: 25)
- `Page` - Page number for pagination
- `IncludeItems` - Include basic item information
- `IncludeColumns` - Include column information
- `IncludeGroups` - Include group information

**Returns:** Array of Monday.Board objects

### Get-MondayBoardDetail

Gets detailed information about a specific Monday.com board.

**Parameters:**
- `BoardId` - The ID of the board to retrieve (supports pipeline input)
- `IncludeItems` - Include all items in the board
- `IncludeColumns` - Include detailed column information
- `IncludeGroups` - Include group information
- `IncludeUpdates` - Include board updates/activity
- `ItemsLimit` - Maximum number of items to retrieve (default: 100)

**Returns:** Monday.BoardDetail object

### Get-MondayBoardItem

Retrieves items (rows) from Monday.com boards.

**Parameters:**
- `ItemIds` - Array of specific item IDs to retrieve
- `BoardIds` - Array of board IDs to retrieve items from
- `Limit` - Maximum number of items to return (default: 25)
- `IncludeColumnValues` - Include column values (data) for each item
- `IncludeUpdates` - Include updates/activity for each item
- `IncludeSubitems` - Include subitems for each item

**Returns:** Array of Monday.Item objects

### Set-MondayBoardItem

Updates column values for a Monday.com item.

**Parameters:**
- `ItemId` - The ID of the item to update (required)
- `BoardId` - The ID of the board containing the item (optional)
- `ColumnValues` - Hashtable of column values to update (column ID → value)
- `ColumnValuesJson` - JSON string containing column values (alternative to hashtable)
- `CreateLabelsIfMissing` - Creates status/dropdown labels if missing
- `ReturnUpdatedItem` - Return the updated item object after update

**Returns:** Success message or Monday.Item object (when ReturnUpdatedItem is specified)

## Error Handling

The module includes comprehensive error handling with informative error messages:

```powershell
try {
    $boards = Get-MondayBoard -Limit 10
}
catch {
    Write-Error "Failed to retrieve boards: $_"
}
```

## Advanced Usage

### Working with Large Datasets

For boards with many items, use pagination:

```powershell
# Get items in batches
$allItems = @()
for ($page = 1; $page -le 5; $page++) {
    $items = Get-MondayBoardItem -BoardIds @(1234567890) -Page $page -Limit 100 -IncludeColumnValues
    $allItems += $items
    Write-Host "Retrieved page $page with $($items.Count) items"
}
```

### Filtering and Processing Data

```powershell
# Get active boards and process their items
Get-MondayBoard -State active | 
    Where-Object { $_.items_count -gt 0 } | 
    ForEach-Object {
        Write-Host "Processing board: $($_.name)"
        Get-MondayBoardItem -BoardIds @($_.id) -IncludeColumnValues
    }
```

## Authentication and Security

- API tokens are stored securely using PowerShell's `Export-Clixml`
- Configuration files are stored in user profile: `$env:USERPROFILE\AppData\Local\powershell\SPSMonday`
- Multiple configuration profiles supported for different environments
- All API calls use HTTPS

## Requirements

- PowerShell 5.1 or later
- Monday.com account with API access
- Valid Monday.com API token

## Contributing

Issues and pull requests are welcome. Please ensure all tests pass before submitting.

## License

Copyright (c) Jesse Geron. All rights reserved.

## Links

- [Monday.com API Documentation](https://developer.monday.com/api-reference/)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/SPSMonday)
- [Monday.com Developer Center](https://developer.monday.com/)

## Support

For issues related to this module, please create an issue in the repository.
For Monday.com API questions, refer to the [Monday.com Developer Documentation](https://developer.monday.com/api-reference/docs) PowerShell Module

A PowerShell module for interfacing with the Monday.com API, providing easy access to boards, items, and other Monday.com data.

## Features

- **Board Information Retrieval**: Get comprehensive board data from your Monday.com instance
- **Item Management**: Access items (rows) with filtering options, column data, and update capabilities
- **Detailed Views**: Get detailed information including columns, groups, and updates
- **Flexible Filtering**: Filter by workspace, board type, state, and more
- **Pipeline Support**: Seamlessly pipe objects between functions
- **Robust API Integration**: Built-in authentication, error handling, and verbose logging
- **Configuration Management**: Secure storage and management of API credentials

## Available Functions

| Function | Description |
|----------|-------------|
| `Get-MondayBoard` | Retrieve board information with filtering options |
| `Get-MondayBoardDetail` | Get detailed information for a specific board |
| `Get-MondayBoardItem` | Retrieve items (rows) from boards with data |
| `Set-MondayBoardItem` | Update column values for Monday.com items |
| `Invoke-MondayApi` | Core API function for making authenticated GraphQL requests |
| `New-SPSMondayConfiguration` | Create new API configuration |
| `Set-SPSMondayConfiguration` | Activate a configuration profile |
| `Get-SPSMondayConfiguration` | Display current configuration information |

## Prerequisites

1. **Monday.com Account**: You need access to a Monday.com instance
2. **API Token**: Personal API token from Monday.com
3. **PowerShell 5.1+**: Module requires PowerShell 5.1 or later

## Quick Start

### 1. Install and Import the Module

```powershell
# Import the module
Import-Module .\SPSMonday\SPSMonday.psd1

# Create and configure authentication
New-SPSMondayConfiguration -Name "production"
```

### 2. Basic Usage Examples

```powershell
# Get all boards (limited to first 25)
Get-MondayBoard

# Get boards from a specific workspace
Get-MondayBoard -WorkspaceIds @(12345) -Limit 10

# Get only public boards
Get-MondayBoard -BoardKind public

# Get detailed information for a specific board
Get-MondayBoardDetail -BoardId 1234567890 -IncludeItems -IncludeColumns

# Get items from a board with their data
Get-MondayBoardItem -BoardIds @(1234567890) -IncludeColumnValues

# Update item column values
Set-MondayBoardItem -ItemId 1111111111 -ColumnValues @{ "status" = "Done"; "text" = "Updated" }

# Pipeline example: Get board details for all boards
Get-MondayBoard | Get-MondayBoardDetail -IncludeItems
```

## Configuration Setup

### Step 1: Get Your API Token

1. **Log into Monday.com**:
   - Go to your Monday.com account
   - Click on your profile picture in the top right corner

2. **Access Developer Center**:
   - Select "Developers" from the menu
   - This opens the Developer Center in a new tab

3. **Get Your Token**:
   - Click "My Access Tokens" > "Show"
   - Copy your personal API token

### Step 2: Configure the Module

1. **Create Configuration**:
   ```powershell
   # This will prompt you for your API token
   New-SPSMondayConfiguration -Name "production"
   ```

2. **Activate Configuration**:
   ```powershell
   Set-SPSMondayConfiguration -Name "production"
   ```

3. **Verify Configuration**:
   ```powershell
   # Test with a simple API call
   Get-MondayBoard -Limit 1 -Verbose
   ```

### Configuration Management

```powershell
# Check current configuration
Get-SPSMondayConfiguration

# Switch between configurations
Set-SPSMondayConfiguration -Name "staging"
Set-SPSMondayConfiguration -Name "production"

# Create additional configurations
New-SPSMondayConfiguration -Name "staging"
```

## Function Reference

### Get-MondayBoard

Retrieves board information with filtering options.

**Parameters:**
- `BoardIds` - Array of specific board IDs to retrieve
- `WorkspaceIds` - Filter by workspace IDs
- `BoardKind` - Board type (public, private, share)
- `State` - Board state (active, archived, deleted, all)
- `Limit` - Maximum number of boards (default: 25)
- `Page` - Page number for pagination
- `OrderBy` - Sort order (created_at, used_at)
- `IncludeItems` - Include basic item information
- `IncludeColumns` - Include column information
- `IncludeGroups` - Include group information

**Returns:** Array of Monday.Board objects

### Get-MondayBoardDetail

Retrieves detailed information about a specific board.

**Parameters:**
- `BoardId` - The ID of the board (required)
- `IncludeItems` - Include all items in the board
- `IncludeColumns` - Include detailed column information
- `IncludeGroups` - Include group information
- `IncludeUpdates` - Include board updates
- `IncludeSubscribers` - Include board subscribers
- `IncludeViews` - Include board views
- `ItemsLimit` - Maximum items to retrieve (default: 100)
- `ItemsPage` - Page number for items

**Returns:** Monday.BoardDetail object

### Get-MondayBoardItem

Retrieves items (rows) from boards.

**Parameters:**
- `ItemIds` - Array of specific item IDs
- `BoardIds` - Array of board IDs to get items from
- `GroupIds` - Filter by group IDs (client-side filtering)
- `Limit` - Maximum number of items (default: 25)
- `Page` - Page number for pagination
- `State` - Item state (active, archived, deleted, all)
- `IncludeColumnValues` - Include column data
- `IncludeUpdates` - Include item updates
- `IncludeSubitems` - Include subitems

**Returns:** Array of Monday.Item objects

### Set-MondayBoardItem

Updates column values for Monday.com items.

**Parameters:**
- `ItemId` - The ID of the item to update (required, supports pipeline input)
- `BoardId` - The ID of the board containing the item (optional)
- `ColumnValues` - Hashtable of column values to update (column ID → value)
- `ColumnValuesJson` - JSON string containing column values (alternative to hashtable)
- `CreateLabelsIfMissing` - Creates status/dropdown labels if missing
- `ReturnUpdatedItem` - Return the updated item object after update

**Returns:** Success message or Monday.Item object (when ReturnUpdatedItem is specified)

## Advanced Examples

### Working with Board Data

```powershell
# Get all public boards with their columns
$boards = Get-MondayBoard -BoardKind public -IncludeColumns

# Find boards by name pattern
$projectBoards = Get-MondayBoard | Where-Object { $_.name -like "*Project*" }

# Get detailed info for multiple boards
$boardDetails = $projectBoards | Get-MondayBoardDetail -IncludeItems -IncludeColumns
```

### Working with Items and Data

```powershell
# Get all items from a specific board with their data
$items = Get-MondayBoardItem -BoardIds @(1234567890) -IncludeColumnValues

# Find items by name
$urgentItems = $items | Where-Object { $_.name -like "*Urgent*" }

# Extract specific column data
$statusValues = $items | ForEach-Object { 
    $_.column_values | Where-Object { $_.column.title -eq "Status" } 
}

# Update multiple items with new status
$items | ForEach-Object { 
    Set-MondayBoardItem -ItemId $_.id -ColumnValues @{ "status" = "Reviewed" } 
}

# Update an item with multiple column values
Set-MondayBoardItem -ItemId 1234567890 -ColumnValues @{
    "status" = "In Progress"
    "date" = "2025-07-15"  
    "numbers" = 42
    "text" = "Updated via PowerShell"
} -ReturnUpdatedItem
```

### Pipeline Operations

```powershell
# Get items from all boards in a workspace
Get-MondayBoard -WorkspaceIds @(12345) | 
    ForEach-Object { Get-MondayBoardItem -BoardIds @($_.id) -IncludeColumnValues }

# Get detailed information for boards with many items
Get-MondayBoard | 
    Where-Object { $_.items_count -gt 50 } | 
    Get-MondayBoardDetail -IncludeItems -IncludeColumns
```

## Error Handling

The module includes comprehensive error handling:

- **Authentication Errors**: Clear messages when API tokens are invalid
- **Rate Limiting**: Automatic detection of rate limit responses
- **GraphQL Errors**: Detailed error messages from the API
- **Network Issues**: Helpful error messages for connectivity problems

## Module Architecture

- **Consistent API Calls**: All functions use `Invoke-MondayApi` for standardized error handling
- **Type Safety**: Objects are typed as `Monday.Board`, `Monday.BoardDetail`, and `Monday.Item`
- **Pipeline Support**: Functions support ValueFromPipeline and ValueFromPipelineByPropertyName
- **Verbose Logging**: Comprehensive logging for troubleshooting and debugging
- **Configuration Management**: Secure credential storage and configuration handling

## API Rate Limits

Monday.com has API rate limits. The module will detect rate limit responses and provide appropriate error messages. Consider:

- Using pagination for large datasets
- Implementing delays between large batches of requests
- Monitoring your API usage in the Monday.com Developer Center

## Security

- API tokens are stored securely using PowerShell's `Export-Clixml` functionality
- Tokens are encrypted with user-specific keys
- Configuration files are stored in user-specific directories

## Troubleshooting

### Common Issues

1. **401 Unauthorized**: Check your API token is valid
2. **403 Forbidden**: Ensure you have permission to access the requested resources
3. **No boards returned**: Check your workspace permissions

### Debugging

Enable verbose output to see detailed information:

```powershell
Get-MondayBoard -Verbose
Get-SPSMondayConfiguration
```

## Contributing

This module follows PowerShell best practices and is designed to be extensible. To add new functionality:

1. Create new functions in the `Public` folder
2. Follow the established patterns for error handling and logging
3. Add comprehensive comment-based help
4. Include proper parameter validation

## Links

- [Monday.com API Documentation](https://developer.monday.com/api-reference/)
- [Monday.com Developer Center](https://monday.com/developers/)
- [GraphQL Documentation](https://graphql.org/learn/)
