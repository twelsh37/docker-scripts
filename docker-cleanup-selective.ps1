# Function to validate number input
function Test-ValidNumbers {
    param (
        [string]$numbers,
        [int]$maxValue
    )
    
    try {
        if ([string]::IsNullOrWhiteSpace($numbers)) { return $false }
        $numArray = $numbers -split ',' | ForEach-Object { [int]$_.Trim() }
        return ($numArray | Where-Object { $_ -lt 1 -or $_ -gt $maxValue }).Count -eq 0
    }
    catch {
        return $false
    }
}

# Get all containers with their mount information
$containers = docker ps -a --format "{{.ID}}|{{.Image}}|{{.Names}}|{{.Status}}" | ForEach-Object {
    $parts = $_ -split '\|'
    $containerId = $parts[0]
    
    # Get volume mounts using inspect
    $mountInfo = docker inspect $containerId | ConvertFrom-Json
    $volumeMounts = $mountInfo.Mounts | Where-Object { $_.Type -eq 'volume' } | ForEach-Object { $_.Name }
    $volumeList = if ($volumeMounts) { $volumeMounts -join ', ' } else { "No volumes" }
    
    [PSCustomObject]@{
        ContainerID = $containerId
        Image = $parts[1]
        Name = $parts[2]
        Status = $parts[3]
        Volumes = $volumeList
    }
}

if ($containers.Count -eq 0) {
    Write-Host "No containers found."
    exit
}

# Display containers with index horizontally
Write-Host "`nList of Docker containers:`n"
$indexed = @{}
for ($i = 0; $i -lt $containers.Count; $i++) {
    $index = $i + 1
    $container = $containers[$i]
    Write-Host "[$index] Container: $($container.Name) (ID: $($container.ContainerID)) Image: $($container.Image) Volumes: $($container.Volumes) Status: $($container.Status)"
    $indexed[$index] = $container
}

# Get user selection
do {
    $numbers = Read-Host "`nEnter the numbers of containers to remove (comma-separated, e.g., 1,3,5) or press Enter to cancel"
    if ([string]::IsNullOrWhiteSpace($numbers)) { 
        Write-Host "Operation cancelled."
        exit 
    }
    $valid = Test-ValidNumbers -numbers $numbers -maxValue $containers.Count
    if (-not $valid) {
        Write-Host "Invalid input. Please enter numbers between 1 and $($containers.Count)"
    }
} while (-not $valid)

# Collect all resources to be removed
$selectedNumbers = $numbers -split ',' | ForEach-Object { [int]$_.Trim() }
$resourcesToRemove = @{
    Containers = @()
    Images = @()
    Volumes = @()
}

foreach ($num in $selectedNumbers) {
    $container = $indexed[$num]
    $resourcesToRemove.Containers += $container
    $resourcesToRemove.Images += $container.Image
    
    if ($container.Volumes -ne "No volumes") {
        $resourcesToRemove.Volumes += $container.Volumes.Split(',').Trim()
    }
}

# Show summary
Write-Host "`nThe following items will be removed:"
Write-Host "`nContainers:"
$resourcesToRemove.Containers | ForEach-Object {
    Write-Host "- $($_.Name) (ID: $($_.ContainerID))"
}

Write-Host "`nAssociated Images:"
$resourcesToRemove.Images | Select-Object -Unique | ForEach-Object {
    Write-Host "- $_"
}

if ($resourcesToRemove.Volumes.Count -gt 0) {
    Write-Host "`nAssociated Volumes:"
    $resourcesToRemove.Volumes | Select-Object -Unique | ForEach-Object {
        Write-Host "- $_"
    }
}

# Confirm and process
$confirm = Read-Host "`nDo you want to proceed with removal? (y/n)"
if ($confirm -ne 'y') {
    Write-Host "Operation cancelled."
    exit
}

# Remove containers first
Write-Host "`nRemoving selected containers..."
foreach ($container in $resourcesToRemove.Containers) {
    Write-Host "Removing container: $($container.Name) (ID: $($container.ContainerID))"
    try {
        docker rm -f $container.ContainerID | Out-Null
    }
    catch {
        Write-Host "Error removing container $($container.ContainerID): $_" -ForegroundColor Red
    }
}

# Remove images
Write-Host "`nRemoving associated images..."
foreach ($image in ($resourcesToRemove.Images | Select-Object -Unique)) {
    Write-Host "Removing image: $image"
    try {
        docker rmi -f $image | Out-Null
    }
    catch {
        Write-Host "Error removing image $image : $_" -ForegroundColor Red
    }
}

# Remove volumes
if ($resourcesToRemove.Volumes.Count -gt 0) {
    Write-Host "`nRemoving associated volumes..."
    foreach ($volume in ($resourcesToRemove.Volumes | Select-Object -Unique)) {
        Write-Host "Removing volume: $volume"
        try {
            docker volume rm $volume | Out-Null
        }
        catch {
            Write-Host "Error removing volume $volume : $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nOperation completed."