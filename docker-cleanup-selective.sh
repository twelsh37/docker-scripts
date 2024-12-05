#!/bin/zsh

# Function: validate_numbers
# Purpose: Validates user input for container selection
# Parameters:
#   $1 - A string containing comma-separated numbers (e.g., "1,3,5")
#   $2 - The maximum allowed value (typically the total container count)
# Returns:
#   0 - If all numbers are valid
#   1 - If any validation fails
validate_numbers() {
    local numbers=$1
    local max_value=$2
    
    if [[ -z "${numbers// }" ]]; then
        return 1
    fi
    
    # Updated regex to allow for ranges
    if ! [[ $numbers =~ ^([0-9]+(-[0-9]+)?)(,[0-9]+(-[0-9]+)?)*$ ]]; then
        return 1
    fi
    
    # Array to store all expanded numbers
    local all_numbers=()
    
    # Process each part (number or range)
    parts=(${(s:,:)numbers})
    for part in "${parts[@]}"; do
        part=$(echo "$part" | tr -d '[:space:]')
        
        # Expand the range and add to array
        while read -r num; do
            if [ -z "$num" ] || [ "$num" -lt 1 ] || [ "$num" -gt "$max_value" ]; then
                return 1
            fi
            all_numbers=($all_numbers $num)
        done < <(expand_number_range "$part")
    done
    
    # Check for duplicates
    if [ "$(printf '%s\n' "${all_numbers[@]}" | sort -n | uniq -d | wc -l)" -gt 0 ]; then
        echo "Invalid input: Duplicate numbers detected" >&2
        return 1
    fi
    
    return 0
}

# Add new function to expand number ranges
expand_number_range() {
    local range="$1"
    
    # Check if input is a range (contains hyphen)
    if [[ $range =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local start="${BASH_REMATCH[1]}"
        local end="${BASH_REMATCH[2]}"
        
        if [ "$start" -gt "$end" ]; then
            return 1
        fi
        
        # Generate sequence of numbers
        seq "$start" "$end"
    # Check if input is a single number
    elif [[ $range =~ ^[0-9]+$ ]]; then
        echo "$range"
    else
        return 1
    fi
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
typeset -A container_map

# Display header for container list
echo -e "\nList of Docker containers:\n"

# First, print the header
printf "%-4s %-30s %-15s %-30s %-20s %-20s\n" \
    "#" "CONTAINER NAME" "CONTAINER ID" "IMAGE" "STATUS" "VOLUMES"
printf "%s\n" "$(printf '=%.0s' {1..120})"  # Separator line

# Process each container line
while IFS= read -r line; do
    IFS='|' read -r id image name container_state <<< "$line"
    
    # Get volume information
    volumes=$(docker inspect "$id" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}')
    volumes=${volumes:="None"}
    
    # Store in container_map (keep this for later use)
    container_map["$index"]="$id|$image|$name|$container_state|$volumes"
    
    # Format the volumes for display (join multiple volumes with comma)
    if [ "$volumes" != "None" ]; then
        volumes=$(echo "$volumes" | tr '\n' ',' | sed 's/,$//')
    fi
    
    # Print table row
    printf "%-4s %-30s %-15s %-30s %-20s %-20s\n" \
        "[$index]" \
        "${name:0:29}" \
        "${id:0:12}" \
        "${image:0:29}" \
        "${container_state:0:19}" \
        "${volumes:0:19}"
    
    ((index++))
done <<< "$container_data"

printf "%s\n" "$(printf '=%.0s' {1..120})"  # Bottom separator line

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
    printf "\nEnter the numbers of containers to remove (comma-separated, e.g., 1,3,5,7-10,13) or press Enter to cancel: "
    
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

# Debug: Print the input numbers
echo "Debug: Input numbers string: $numbers" >&2

selected_nums=()

# Process each part (number or range) using zsh array splitting
parts=(${(s:,:)numbers})  # zsh-specific splitting

echo "Debug: Parts after splitting: ${parts[*]}" >&2

for part in "${parts[@]}"; do
    # Clean the part of any whitespace
    part=$(echo "$part" | tr -d '[:space:]')
    echo "Debug: Processing part: $part" >&2
    
    # Directly process the number if it's not a range
    if [[ ! "$part" =~ "-" ]]; then
        selected_nums+=($part)
    else
        # Process range
        while IFS= read -r num; do
            selected_nums+=($num)
        done < <(expand_number_range "$part")
    fi
done

echo "Debug: Selected numbers: ${selected_nums[*]}" >&2
echo "Debug: Available container map keys: ${(k)container_map[@]}" >&2

# Initialize arrays for storing resources to be removed
containers_to_remove=()
images_to_remove=()
volumes_to_remove=()

# Process each selected container number
for num in "${selected_nums[@]}"; do
    echo "Debug: Processing container number: $num" >&2
    
    # Get container info from map using zsh associative array syntax
    container_info=$container_map[$num]
    echo "Debug: Container info from map: '$container_info'" >&2
    
    # Skip if container info doesn't exist
    if [[ -z "$container_info" ]]; then
        echo "Warning: No container found for number $num" >&2
        continue
    fi
    
    # Split the container info into components using zsh read
    IFS='|' read -r id image name status volumes <<< "$container_info"
    
    # Debug the split values
    echo "Debug: Split values:" >&2
    echo "  ID: '$id'" >&2
    echo "  Image: '$image'" >&2
    echo "  Name: '$name'" >&2
    echo "  Status: '$status'" >&2
    echo "  Volumes: '$volumes'" >&2
    
    # Add to removal lists
    if [[ -n "$id" && -n "$name" ]]; then
        containers_to_remove+=("$id|$name")
        [[ -n "$image" ]] && images_to_remove+=("$image")
        
        # Process volumes
        if [[ "$volumes" != "None" && -n "$volumes" ]]; then
            for volume in ${=volumes}; do
                [[ -n "$volume" ]] && volumes_to_remove+=("$volume")
            done
        fi
    fi
done

# Resource Removal Summary Section
echo -e "\nThe following items will be removed:"

# Display containers section
echo -e "\nContainers:"
for container in "${containers_to_remove[@]}"; do
    IFS='|' read -r id name <<< "$container"
    echo "- $name (ID: ${id:0:12})"
done

# Display images section
echo -e "\nAssociated Images:"
if [ ${#images_to_remove[@]} -gt 0 ]; then
    printf '%s\n' "${images_to_remove[@]}" | sort -u | while read -r image; do
        [ -n "$image" ] && echo "- $image"
    done
fi

# Display volumes section
if [ ${#volumes_to_remove[@]} -gt 0 ]; then
    echo -e "\nAssociated Volumes:"
    printf '%s\n' "${volumes_to_remove[@]}" | sort -u | while read -r volume; do
        [ -n "$volume" ] && echo "- $volume"
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
