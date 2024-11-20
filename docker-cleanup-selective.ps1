# Description: PowerShell script to remove selected Docker containers, images, and volumes

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
        # Check if the input string is empty or contains only whitespace
        if ([string]::IsNullOrWhiteSpace($numbers)) { return $false }

        # Check if the input matches the pattern of integers separated by commas
        # This regex ensures only digits and commas are allowed (no spaces)
        if (-not ($numbers -match '^(\d+,)*\d+$')) { return $false }

        # Convert the comma-separated string into an array of integers
        $numArray = $numbers -split ',' | ForEach-Object { [int]$_ }

        # Validate that all numbers are within range (between 1 and maxValue)
        return ($numArray | Where-Object { $_ -lt 1 -or $_ -gt $maxValue }).Count -eq 0
    }
    catch {
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
    $numbers = Read-Host "`nEnter the numbers of containers to remove (comma-separated, e.g., 1,3,5) or press Enter to cancel"
    
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
        Write-Host "Invalid input. Please enter only numbers between 1 and $($containers.Count), separated by commas (e.g., 1,3,5)"
    }
} while (-not $valid)

# Resource Collection Initialization
# This section prepares data structures for tracking all Docker resources that will be removed

# Convert the validated user input string into an array of integers
# Example: "1,3,5" becomes @(1, 3, 5)
$selectedNumbers = $numbers -split ',' | ForEach-Object { [int]$_.Trim() }

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