<#
.SYNOPSIS
    Removes Supabase bucket and installation

.DESCRIPTION
    This script removes existing Supabase bucket and installation

.NOTES
    Last Updated: 2024-11-19
    Requirements:
        - Scoop package manager
        - Administrator privileges may be required
        - Internet connection for GitHub access
#>

# Enable strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to handle errors
function Write-ErrorLog {
    param(
        [string]$Message,
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    Write-Host "Error: $Message" -ForegroundColor Red
    if ($ErrorRecord) {
        Write-Host "Details: $($ErrorRecord.Exception.Message)" -ForegroundColor Red
    }
}

try {
    # Change to the project directory
    Write-Host "Changing to project directory..." -ForegroundColor Cyan
    Set-Location -Path "E:\data\vscodeproject\supabase" -ErrorAction Stop

    # Remove existing Supabase bucket
    Write-Host "Removing existing Supabase bucket..." -ForegroundColor Cyan
    $null = (scoop bucket rm supabase) 2>&1
    
    # Uninstall existing Supabase
    Write-Host "Uninstalling existing Supabase..." -ForegroundColor Cyan
    # Fix: Capture and ignore output instead of using -ErrorAction
    $null = (scoop uninstall supabase) 2>&1

    Write-Host "`nSupabase removal completed successfully!" -ForegroundColor Green
}
catch {
    Write-ErrorLog -Message "Script execution failed" -ErrorRecord $_
    exit 1
}
finally {
    # Change back to docker-scripts directory
    Write-Host "Changing back to docker-scripts folder..." -ForegroundColor Cyan
    Set-Location -Path "E:\data\vscodeproject\docker-scripts" -ErrorAction Stop
}