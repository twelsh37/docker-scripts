#!/bin/bash

# Function to validate number input
validate_numbers() {
    local numbers=$1
    local max_value=$2
    
    # Check if empty
    if [[ -z "${numbers// }" ]]; then
        return 1
    fi
    
    # Check if all numbers are valid
    IFS=',' read -ra nums <<< "$numbers"
    for num in "${nums[@]}"; do
        # Remove whitespace
        num=$(echo "$num" | tr -d '[:space:]')
        # Check if it's a number and in range
        if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "$max_value" ]; then
            return 1
        fi
    done
    return 0
}

# Get all containers with their mount information
containers=()
container_data=$(docker ps -a --format "{{.ID}}|{{.Image}}|{{.Names}}|{{.Status}}")

# Exit if no containers found
if [ -z "$container_data" ]; then
    echo "No containers found."
    exit 0
fi

# Process container data
index=1
declare -A container_map
echo -e "\nList of Docker containers:\n"

while IFS= read -r line; do
    IFS='|' read -r id image name status <<< "$line"
    
    # Get volume mounts using inspect
    volumes=$(docker inspect "$id" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}')
    volumes=${volumes:="No volumes"}
    
    # Store container info
    container_map["$index"]="$id|$image|$name|$status|$volumes"
    
    # Display container
    echo "[$index] Container: $name (ID: $id) Image: $image Volumes: $volumes Status: $status"
    
    ((index++))
done <<< "$container_data"

max_containers=$((index - 1))

# Get user selection
while true; do
    echo -e "\nEnter the numbers of containers to remove (comma-separated, e.g., 1,3,5) or press Enter to cancel"
    read -r numbers
    
    # Check for cancel
    if [ -z "$numbers" ]; then
        echo "Operation cancelled."
        exit 0
    fi
    
    # Validate input
    if validate_numbers "$numbers" "$max_containers"; then
        break
    else
        echo "Invalid input. Please enter numbers between 1 and $max_containers"
    fi
done

# Collect resources to remove
declare -a containers_to_remove=()
declare -a images_to_remove=()
declare -a volumes_to_remove=()

IFS=',' read -ra selected_nums <<< "$numbers"
for num in "${selected_nums[@]}"; do
    num=$(echo "$num" | tr -d '[:space:]')
    IFS='|' read -r id image name status volumes <<< "${container_map[$num]}"
    
    containers_to_remove+=("$id|$name")
    images_to_remove+=("$image")
    
    if [ "$volumes" != "No volumes" ]; then
        for volume in $volumes; do
            volumes_to_remove+=("$volume")
        done
    fi
done

# Show summary
echo -e "\nThe following items will be removed:"

echo -e "\nContainers:"
for container in "${containers_to_remove[@]}"; do
    IFS='|' read -r id name <<< "$container"
    echo "- $name (ID: $id)"
done

echo -e "\nAssociated Images:"
printf '%s\n' "${images_to_remove[@]}" | sort -u | while read -r image; do
    echo "- $image"
done

if [ ${#volumes_to_remove[@]} -gt 0 ]; then
    echo -e "\nAssociated Volumes:"
    printf '%s\n' "${volumes_to_remove[@]}" | sort -u | while read -r volume; do
        echo "- $volume"
    done
fi

# Confirm and process
echo -e "\nDo you want to proceed with removal? (y/n)"
read -r confirm
if [ "$confirm" != "y" ]; then
    echo "Operation cancelled."
    exit 0
fi

# Remove containers
echo -e "\nRemoving selected containers..."
for container in "${containers_to_remove[@]}"; do
    IFS='|' read -r id name <<< "$container"
    echo "Removing container: $name (ID: $id)"
    if ! docker rm -f "$id" > /dev/null 2>&1; then
        echo "Error removing container $id" >&2
    fi
done

# Remove images
echo -e "\nRemoving associated images..."
printf '%s\n' "${images_to_remove[@]}" | sort -u | while read -r image; do
    echo "Removing image: $image"
    if ! docker rmi -f "$image" > /dev/null 2>&1; then
        echo "Error removing image $image" >&2
    fi
done

# Remove volumes
if [ ${#volumes_to_remove[@]} -gt 0 ]; then
    echo -e "\nRemoving associated volumes..."
    printf '%s\n' "${volumes_to_remove[@]}" | sort -u | while read -r volume; do
        echo "Removing volume: $volume"
        if ! docker volume rm "$volume" > /dev/null 2>&1; then
            echo "Error removing volume $volume" >&2
        fi
    done
fi

echo -e "\nOperation completed."