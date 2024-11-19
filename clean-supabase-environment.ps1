<#
.SYNOPSIS
    Reinstalls and starts Supabase development environment.

.DESCRIPTION
    This script performs a clean reinstallation of Supabase using Scoop package manager.
    It removes existing Supabase bucket and installation, adds the latest bucket,
    reinstalls Supabase, and starts the development environment.

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

    # Add latest Supabase bucket
    Write-Host "Adding latest Supabase bucket..." -ForegroundColor Cyan
    scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add Supabase bucket"
    }

    # Install Supabase
    Write-Host "Installing Supabase..." -ForegroundColor Cyan
    scoop install supabase
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Supabase"
    }

    # Start Supabase
    Write-Host "Starting Supabase..." -ForegroundColor Cyan
    supabase start
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start Supabase"
    }

    Write-Host "`nSupabase setup completed successfully!" -ForegroundColor Green
}
catch {
    Write-ErrorLog -Message "Script execution failed" -ErrorRecord $_
    exit 1
}
finally {
    # Cleanup or additional tasks if needed
    # Currently no cleanup required
}