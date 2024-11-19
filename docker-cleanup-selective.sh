#!/bin/bash

# Function: validate_numbers
# Purpose: Validates user input for container selection
# Parameters:
#   $1 - A string containing comma-separated numbers (e.g., "1,3,5")
#   $2 - The maximum allowed value (typically the total container count)
# Returns:
#   0 - If all numbers are valid
#   1 - If any validation fails
validate_numbers() {
    local numbers=$1      # Input string of numbers
    local max_value=$2    # Maximum allowed value
    
    # Check if input is empty or only whitespace
    # ${numbers// /} removes all spaces from the string
    if [[ -z "${numbers// }" ]]; then
        return 1
    fi
    
    # Process each number in the comma-separated list
    # IFS=',' sets the field separator to comma
    # read -ra nums creates an array from the comma-separated string
    IFS=',' read -ra nums <<< "$numbers"
    for num in "${nums[@]}"; do
        # Remove all whitespace from the current number
        # tr -d '[:space:]' removes all whitespace characters
        num=$(echo "$num" | tr -d '[:space:]')

        # Validate the number:
        # 1. ^[0-9]+$ ensures it contains only digits
        # 2. -lt 1 checks if less than 1
        # 3. -gt "$max_value" checks if greater than maximum
        if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "$max_value" ]; then
            return 1
        fi
    done
    return 0
}

# Container Data Collection Section
# Purpose: Retrieves all Docker containers and their basic information
# Creates an array of container data for processing

# Initialize empty array for storing container information
# This will hold all container details for later processing
containers=()

# Get container information using docker ps command
# Flags:
#   -a        : Shows all containers (running and stopped)
# Format string components:
#   {{.ID}}   : Container ID
#   {{.Image}}: Image name
#   {{.Names}}: Container name
#   {{.Status}}: Container status
# Output format: "ContainerID|ImageName|ContainerName|Status"
container_data=$(docker ps -a --format "{{.ID}}|{{.Image}}|{{.Names}}|{{.Status}}")

# Check if any containers exist
# -z tests if the string is empty
# Exit gracefully if no containers are found
if [ -z "$container_data" ]; then
    echo "No containers found."
    exit 0
fi

# Container Processing and Display Section
# Purpose: Process container data, collect volume information, and display to user

# Initialize counter for container numbering
index=1

# Declare associative array for storing container information
# This allows easy lookup using the display number as key
declare -A container_map

# Display header for container list
echo -e "\nList of Docker containers:\n"

# Process each container line from previous docker ps output
while IFS= read -r line; do
    # Split the line into components using | as delimiter
    # Variables:
    #   id     - Container ID
    #   image  - Image name
    #   name   - Container name
    #   status - Container status
    IFS='|' read -r id image name status <<< "$line"
    
    # Get volume information for this container using docker inspect
    # Format string extracts only volume mounts (not bind mounts)
    # --format uses Go template to filter for volume type mounts
    volumes=$(docker inspect "$id" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}')
    
    # Set default value if no volumes found
    volumes=${volumes:="No volumes"}
    
    # Store complete container information in associative array
    # Format: "ContainerID|ImageName|ContainerName|Status|Volumes"
    container_map["$index"]="$id|$image|$name|$status|$volumes"
    
    # Display container information in formatted output
    # [Number] Container: Name (ID: XXX) Image: XXX Volumes: XXX Status: XXX
    echo "[$index] Container: $name (ID: $id) Image: $image Volumes: $volumes Status: $status"
    
    # Increment counter for next container
    ((index++))
done <<< "$container_data"

# Store total number of containers for validation
max_containers=$((index - 1))

# User Selection Section
# Purpose: Get and validate user input for container selection
# Uses validate_numbers function to ensure input correctness

while true; do
    # Prompt user for container selection
    # Provides instruction for:
    # - Format (comma-separated numbers)
    # - Example input
    # - Cancellation option
    echo -e "\nEnter the numbers of containers to remove (comma-separated, e.g., 1,3,5) or press Enter to cancel"
    
    # Read user input into numbers variable
    # -r flag prevents backslash escapes from being interpreted
    read -r numbers
    
    # Check if user wants to cancel operation
    # -z tests if the string is empty (user just pressed Enter)
    if [ -z "$numbers" ]; then
        echo "Operation cancelled."
        exit 0
    fi
    
    # Validate the user input using validate_numbers function
    # Parameters:
    # - $numbers: User input string
    # - $max_containers: Maximum valid container number
    if validate_numbers "$numbers" "$max_containers"; then
        break  # Exit loop if input is valid
    else
        # Display error message if input is invalid
        # Shows valid range to help user correct input
        echo "Invalid input. Please enter numbers between 1 and $max_containers"
    fi
done

# Resource Collection Section
# Purpose: Organize all resources (containers, images, volumes) that will be removed
# Creates separate arrays for each resource type to manage cleanup process

# Initialize arrays for storing resources to be removed
declare -a containers_to_remove=()  # Array for container IDs and names
declare -a images_to_remove=()      # Array for image names
declare -a volumes_to_remove=()     # Array for volume names

# Split the validated user input into array of numbers
# IFS=',' sets comma as delimiter for reading numbers
IFS=',' read -ra selected_nums <<< "$numbers"

# Process each selected container number
for num in "${selected_nums[@]}"; do
    # Remove any whitespace from the number
    num=$(echo "$num" | tr -d '[:space:]')
    
    # Extract container information from container_map
    # Split stored string into components:
    # - id: Container ID
    # - image: Image name
    # - name: Container name
    # - status: Container status
    # - volumes: Associated volumes
    IFS='|' read -r id image name status volumes <<< "${container_map[$num]}"
    
    # Add container to removal list
    # Format: "ContainerID|ContainerName"
    containers_to_remove+=("$id|$name")
    
    # Add container's image to removal list
    images_to_remove+=("$image")
    
    # Process volumes if container has any
    # Skip if container has "No volumes"
    if [ "$volumes" != "No volumes" ]; then
        # Add each volume to removal list
        # Splits volume string on spaces
        for volume in $volumes; do
            volumes_to_remove+=("$volume")
        done
    fi
done

# Resource Removal Summary Section
# Purpose: Display a comprehensive list of all resources that will be removed
# Provides user with final review before confirmation

# Display summary header
echo -e "\nThe following items will be removed:"

# Display containers section
echo -e "\nContainers:"
# Process each container in the removal list
# Format stored: "ContainerID|ContainerName"
for container in "${containers_to_remove[@]}"; do
    # Split container string into ID and name
    IFS='|' read -r id name <<< "$container"
    # Display in user-friendly format
    echo "- $name (ID: $id)"
done

# Display images section
echo -e "\nAssociated Images:"
# Process images with deduplication:
# 1. printf outputs array elements with newlines
# 2. sort -u removes duplicates
# 3. while loop processes each unique image
printf '%s\n' "${images_to_remove[@]}" | sort -u | while read -r image; do
    echo "- $image"
done

# Display volumes section (only if volumes exist)
# ${#volumes_to_remove[@]} gets the array length
if [ ${#volumes_to_remove[@]} -gt 0 ]; then
    echo -e "\nAssociated Volumes:"
    # Process volumes with deduplication (same as images)
    printf '%s\n' "${volumes_to_remove[@]}" | sort -u | while read -r volume; do
        echo "- $volume"
    done
fi

# User Confirmation Section
# Purpose: Get explicit user confirmation before proceeding with resource removal
# Provides last chance to cancel the operation safely

# Display confirmation prompt
# -e flag enables interpretation of backslash escapes (\n for newline)
echo -e "\nDo you want to proceed with removal? (y/n)"

# Read user input
# -r flag prevents backslash escapes from being interpreted in the input
read -r confirm

# Check user's response
# Only proceed if user explicitly enters "y"
# Any other input (including Y, yes, etc.) will cancel the operation
if [ "$confirm" != "y" ]; then
    echo "Operation cancelled."
    exit 0    # Exit successfully without performing removal
fi

# Resource Removal Section
# Purpose: Execute the removal of all selected Docker resources
# Order: Containers → Images → Volumes (to handle dependencies correctly)

# Container Removal
echo -e "\nRemoving selected containers..."
for container in "${containers_to_remove[@]}"; do
    # Split container string into ID and name components
    IFS='|' read -r id name <<< "$container"
    
    # Display current operation
    echo "Removing container: $name (ID: $id)"
    
    # Remove container with force flag (-f)
    # Redirect output to /dev/null for cleaner logs
    # 2>&1 redirects stderr to stdout
    if ! docker rm -f "$id" > /dev/null 2>&1; then
        # Display error message if removal fails
        echo "Error removing container $id" >&2
    fi
done

# Image Removal
echo -e "\nRemoving associated images..."
# Process unique images only (sort -u removes duplicates)
printf '%s\n' "${images_to_remove[@]}" | sort -u | while read -r image; do
    # Display current operation
    echo "Removing image: $image"
    
    # Remove image with force flag (-f)
    # Handle errors similarly to containers
    if ! docker rmi -f "$image" > /dev/null 2>&1; then
        echo "Error removing image $image" >&2
    fi
done

# Volume Removal
# Only process if volumes exist
if [ ${#volumes_to_remove[@]} -gt 0 ]; then
    echo -e "\nRemoving associated volumes..."
    # Process unique volumes only
    printf '%s\n' "${volumes_to_remove[@]}" | sort -u | while read -r volume; do
        # Display current operation
        echo "Removing volume: $volume"
        
        # Remove volume (no force flag available for volumes)
        # Handle errors similarly to other resources
        if ! docker volume rm "$volume" > /dev/null 2>&1; then
            echo "Error removing volume $volume" >&2
        fi
    done
fi

# Inform user of successful completion
echo -e "\nOperation completed."