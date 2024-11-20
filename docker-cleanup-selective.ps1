# Description: PowerShell script to remove selected Docker containers, images, and volumes

# Add this new function at the start of the file
<#
.SYNOPSIS
Expands a string representation of a number or range into an array of integers.

.DESCRIPTION
This function takes a string input that represents either a single number or a range of numbers
(e.g., "5" or "1-5") and converts it into an array of integers. For single numbers, it returns
a single-element array. For ranges, it returns an array containing all numbers in that range,
inclusive of start and end values.

.PARAMETER range
A string representing either a single number (e.g., "5") or a range of numbers (e.g., "1-5").

.EXAMPLE
Expand-NumberRange "5"
Returns: @(5)

.EXAMPLE
Expand-NumberRange "1-5"
Returns: @(1, 2, 3, 4, 5)

.OUTPUTS
System.Int32[] - An array of integers representing the expanded range.

.THROWS
System.Exception - Throws an exception if:
- The range format is invalid
- The start number is greater than the end number in a range
- The input cannot be parsed as integers

.NOTES
Valid input formats:
- Single number: "5"
- Number range: "1-5"
#>
function Expand-NumberRange {
    param (
        # The string to parse, either a single number or a range (e.g., "5" or "1-5")
        [Parameter(Mandatory = $true)]
        [string]$range
    )
    
    # Check if the input is a range (contains hyphen)
    # Format: "start-end" (e.g., "1-5")
    if ($range -match '^(\d+)-(\d+)$') {
        # Extract start and end numbers from the matches
        # $Matches[1] contains the first capture group (start number)
        # $Matches[2] contains the second capture group (end number)
        $start = [int]$Matches[1]
        $end = [int]$Matches[2]
        
        # Validate that the start number isn't greater than the end number
        # Example: "5-3" would be invalid
        if ($start -gt $end) {
            throw "Invalid range: start number ($start) cannot be greater than end number ($end)"
        }
        
        # Return an array containing all numbers in the range (inclusive)
        # The '..' operator in PowerShell creates a range of numbers
        return $start..$end
    }
    # Check if the input is a single number
    # Format: "number" (e.g., "5")
    elseif ($range -match '^\d+$') {
        # Convert the string to an integer and return it
        return [int]$range
    }
    else {
        # If the input doesn't match either format, throw an error
        throw "Invalid format: Input must be either a single number or a range (e.g., '5' or '1-5')"
    }
}

# Validates if a comma-separated string contains only integers within a valid range
# Parameters:
#   $numbers  - String containing comma-separated integers (e.g., "1,3,5")
#   $maxValue - Maximum allowed number (typically the count of available containers)
# Returns:
#   Boolean - true if all numbers are valid integers, false otherwise
function Test-ValidNumbers {
    param (
        [string]$numbers,
        [int]$maxValue
    )
    
    try {
        if ([string]::IsNullOrWhiteSpace($numbers)) { return $false }

        # Updated regex to allow for ranges (e.g., "1-5,6,8-10")
        if (-not ($numbers -match '^(\d+(-\d+)?)(,\d+(-\d+)?)*$')) { return $false }

        # Split into individual numbers and ranges
        $parts = $numbers -split ',' | ForEach-Object { $_.Trim() }
        
        # Expand all numbers and ranges
        $expandedNumbers = @()
        foreach ($part in $parts) {
            $expandedNumbers += Expand-NumberRange $part
        }

        # Check for duplicates
        if (($expandedNumbers | Group-Object | Where-Object { $_.Count -gt 1 }).Count -gt 0) {
            Write-Host "Invalid input: Duplicate numbers detected"
            return $false
        }

        # Check for overlapping ranges
        $sortedNumbers = $expandedNumbers | Sort-Object
        for ($i = 0; $i -lt $sortedNumbers.Count - 1; $i++) {
            if ($sortedNumbers[$i] -eq $sortedNumbers[$i + 1]) {
                Write-Host "Invalid input: Overlapping ranges detected"
                return $false
            }
        }

        # Validate range
        return ($expandedNumbers | Where-Object { $_ -lt 1 -or $_ -gt $maxValue }).Count -eq 0
    }
    catch {
        Write-Host "Error validating numbers: $_"
        return $false
    }
}

# Retrieve and process all Docker containers with their associated volume information
# This section creates a custom object array containing container details and their mounted volumes

# Execute 'docker ps -a' command with custom format output
# Format: ContainerID|Image|Names|Status
# -a flag includes all containers (running and stopped)
$containers = docker ps -a --format "{{.ID}}|{{.Image}}|{{.Names}}|{{.Status}}" | ForEach-Object {
    # Split the output into parts using the pipe character as delimiter
    $parts = $_ -split '\|'
    $containerId = $parts[0]
    
    # Inspect the container to get detailed information including volume mounts
    # ConvertFrom-Json transforms the JSON output into a PowerShell object
    $mountInfo = docker inspect $containerId | ConvertFrom-Json

    # Extract volume information:
    # 1. Get all mounts from the container
    # 2. Filter to include only volume type mounts (excluding bind mounts)
    # 3. Extract just the volume names
    $volumeMounts = $mountInfo.Mounts | 
                   Where-Object { $_.Type -eq 'volume' } | 
                   ForEach-Object { $_.Name }

    # Create a comma-separated list of volumes
    # If no volumes are found, set to "No volumes"
    $volumeList = if ($volumeMounts) { 
        $volumeMounts -join ', ' 
    } else { 
        "No volumes" 
    }
    
    # Create a custom PowerShell object with container details
    # This makes the data easily accessible and manageable
    [PSCustomObject]@{
        ContainerID = $containerId  # Container's unique identifier
        Image = $parts[1]           # Name of the Docker image
        Name = $parts[2]            # Container's name
        Status = $parts[3]          # Current status (running, exited, etc.)
        Volumes = $volumeList       # List of attached volumes or "No volumes"
    }
}

# Check if any containers were found in the system
# If no containers exist, inform the user and exit the script
if ($containers.Count -eq 0) {
    Write-Host "No containers found."  # Display message to user
    exit                               # Exit script execution
}

# Display all containers with numbered indices for user selection
Write-Host "`nList of Docker containers:`n"

$indexed = @{}

# Create custom table entries with proper volume handling
$tableEntries = for ($i = 0; $i -lt $containers.Count; $i++) {
    $index = $i + 1
    $container = $containers[$i]
    
    # Handle volumes display
    $volumeList = if ($container.Volumes -ne "No volumes") {
        # Split volumes into array and format each on new line without indent
        ($container.Volumes -split ',').Trim() -join "`n"
    } else {
        "None"
    }
    
    # Create custom object for table display
    [PSCustomObject]@{
        '#' = "[$index]"
        'Container Name' = $container.Name
        'Container ID' = $container.ContainerID
        'Image' = $container.Image
        'Status' = $container.Status
        'Volumes' = $volumeList
    }
    
    # Store container in indexed lookup
    $indexed[$index] = $container
}

# Display formatted table with left alignment
$tableEntries | Format-Table -AutoSize -Wrap -Property @(
    @{Label='#'; Expression={$_.'#'}; Align='Left'},
    @{Label='Container Name'; Expression={$_.'Container Name'}; Align='Left'},
    @{Label='Container ID'; Expression={$_.'Container ID'}; Align='Left'},
    @{Label='Image'; Expression={$_.Image}; Align='Left'},
    @{Label='Status'; Expression={$_.Status}; Align='Left'},
    @{Label='Volumes'; Expression={$_.Volumes}; Align='Left'}
)

# User Input Section
# This section handles container selection through a validation loop
# It ensures that users provide valid container numbers before proceeding

do {
    # Prompt user for input with formatting instructions
    # Users can either:
    # 1. Enter comma-separated numbers (e.g., "1,3,5")
    # 2. Press Enter to cancel the operation
    $numbers = Read-Host "`nEnter the numbers of containers to remove (comma-separated, e.g., 1,3,5,7-10,13) or press Enter to cancel"
    
    # Check if user wants to cancel the operation
    # This happens when:
    # - User presses Enter without input
    # - User enters only whitespace
    if ([string]::IsNullOrWhiteSpace($numbers)) { 
        Write-Host "Operation cancelled."
        exit 
    }

    # Validate the user input using Test-ValidNumbers function
    # Parameters:
    # - numbers: The user's input string
    # - maxValue: Total number of available containers
    # Returns true only if:
    # - All inputs are valid integers
    # - All numbers are within range (1 to container count)
    # - Numbers are properly comma-separated
    $valid = Test-ValidNumbers -numbers $numbers -maxValue $containers.Count
    
    # If validation fails, inform user of proper input format
    # Loop will continue until valid input is received
    if (-not $valid) {
        Write-Host "Invalid input. Please enter only numbers between 1 and $($containers.Count), separated by commas (e.g., 1,3,5,7-10,13)"
    }
} while (-not $valid)

# Resource Collection Initialization
# This section prepares data structures for tracking all Docker resources that will be removed

# Convert the validated user input string into an array of integers
# Example: "1,3,5" becomes @(1, 3, 5)
$selectedNumbers = $numbers -split ',' | ForEach-Object { 
    Expand-NumberRange $_.Trim()
} | Sort-Object

# Initialize a hashtable to track all Docker resources marked for removal
# This structure will store:
# - Containers: Container IDs to be removed
# - Images: Image names that will be removed
# - Volumes: Volume names that will be removed
$resourcesToRemove = @{
    Containers = @()    # Array to store container IDs/names
    Images = @()        # Array to store image names
    Volumes = @()       # Array to store volume names
}

# Resource Collection Loop
# Process each selected container and collect all associated resources for removal

foreach ($num in $selectedNumbers) {
    # Retrieve the container object from our indexed lookup table
    # $num corresponds to the display number shown to user (e.g., [1], [2], etc.)
    $container = $indexed[$num]
    
    # Add container to removal list
    # This stores the full container object with all its properties
    $resourcesToRemove.Containers += $container
    
    # Add the container's image to removal list
    # Note: Same image might be added multiple times if used by multiple containers
    # Duplicates will be handled during cleanup
    $resourcesToRemove.Images += $container.Image
    
    # Process volume information if the container has any volumes
    # Volumes are stored as comma-separated string, need to split into individual volumes
    if ($container.Volumes -ne "No volumes") {
        # Split the volume string into individual volume names
        # Trim any whitespace from volume names
        # Add each volume to the removal list
        $resourcesToRemove.Volumes += $container.Volumes.Split(',').Trim()
    }
}

# Resource Removal Summary and Confirmation Section
# Displays all resources that will be removed and gets user confirmation

# Display header for removal summary
Write-Host "`nThe following items will be removed:"

# Display all containers marked for removal
# Format: Container Name (ID: ContainerID)
Write-Host "`nContainers:"
$resourcesToRemove.Containers | ForEach-Object {
    Write-Host "- $($_.Name) (ID: $($_.ContainerID))"
}

# Display all unique images marked for removal
# Note: Select-Object -Unique removes duplicate image entries
# (same image might be used by multiple containers)
Write-Host "`nAssociated Images:"
$resourcesToRemove.Images | Select-Object -Unique | ForEach-Object {
    Write-Host "- $_"
}

# Display volumes only if there are any to remove
# Prevents showing empty "Associated Volumes:" section
if ($resourcesToRemove.Volumes.Count -gt 0) {
    Write-Host "`nAssociated Volumes:"
    # Show unique volume names (removes duplicates)
    $resourcesToRemove.Volumes | Select-Object -Unique | ForEach-Object {
        Write-Host "- $_"
    }
}

# User Confirmation Section
# Get explicit confirmation before proceeding with removal
$confirm = Read-Host "`nDo you want to proceed with removal? (y/n)"

# Exit if user doesn't confirm with 'y'
if ($confirm -ne 'y') {
    Write-Host "Operation cancelled."
    exit
}

# Container Removal Section
# Removes all selected containers using force removal
# Containers must be removed first before images and volumes

# Display header for container removal process
Write-Host "`nRemoving selected containers..."

# Process each container in the removal list
foreach ($container in $resourcesToRemove.Containers) {
    # Inform user which container is being processed
    Write-Host "Removing container: $($container.Name) (ID: $($container.ContainerID))"
    
    try {
        # Execute docker rm command with:
        # -f flag: Forces removal of running containers
        # Out-Null: Suppresses command output for cleaner logs
        # ContainerID: Uses ID instead of name for more reliable removal
        docker rm -f $container.ContainerID | Out-Null
    }
    catch {
        # Handle any errors during container removal
        # Displays error in red for visibility
        # Continues processing other containers even if one fails
        Write-Host "Error removing container $($container.ContainerID): $_" -ForegroundColor Red
    }
}

# Image Removal Section
# Removes all Docker images associated with the removed containers
# Images are removed after containers to resolve dependencies

# Display header for image removal process
Write-Host "`nRemoving associated images..."

# Process each unique image in the removal list
# Select-Object -Unique prevents attempting to remove the same image multiple times
foreach ($image in ($resourcesToRemove.Images | Select-Object -Unique)) {
    # Inform user which image is being processed
    Write-Host "Removing image: $image"
    
    try {
        # Execute docker rmi command with:
        # -f flag: Forces removal of the image
        # Out-Null: Suppresses command output for cleaner logs
        # $image: References the full image name (e.g., nginx:latest)
        docker rmi -f $image | Out-Null
    }
    catch {
        # Handle any errors during image removal
        # Common errors include:
        # - Image in use by other containers
        # - Image already removed
        # - Network/permission issues
        Write-Host "Error removing image $image : $_" -ForegroundColor Red
    }
}

# Volume Removal Section
# Removes all Docker volumes that were associated with the removed containers
# Volumes are removed last to ensure no container dependencies exist

# Only process volumes if there are any to remove
if ($resourcesToRemove.Volumes.Count -gt 0) {
    # Display header for volume removal process
    Write-Host "`nRemoving associated volumes..."
    
    # Process each unique volume in the removal list
    # Select-Object -Unique prevents attempting to remove the same volume multiple times
    foreach ($volume in ($resourcesToRemove.Volumes | Select-Object -Unique)) {
        # Inform user which volume is being processed
        Write-Host "Removing volume: $volume"
        
        try {
            # Execute docker volume rm command
            # Note: No -f flag as volumes can't be removed if in use
            # Out-Null: Suppresses command output for cleaner logs
            docker volume rm $volume | Out-Null
        }
        catch {
            # Handle any errors during volume removal
            # Common errors include:
            # - Volume still in use by other containers
            # - Volume already removed
            # - Permission issues
            Write-Host "Error removing volume $volume : $_" -ForegroundColor Red
        }
    }
}

# Inform user of successful completion
Write-Host "`nOperation completed."  