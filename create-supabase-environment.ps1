<#
.SYNOPSIS
    Creates and starts a new Supabase development environment.

.DESCRIPTION
    This script creates a new Supabase development environment using Scoop package manager.
    It adds the Supabase bucket, installs Supabase, and starts the development environment.

.NOTES
    Last Updated: 2024-03-19
    Requirements:
        - Scoop package manager
        - Administrator privileges may be required
        - Internet connection for GitHub access

.EXAMPLE
    .\create-supabase-environment.ps1

.OUTPUTS
    Success or error messages with color coding
#>

# Enable strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to handle errors
function Write-ErrorLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    Write-Host "Error: $Message" -ForegroundColor Red
    if ($ErrorRecord) {
        Write-Host "Details: $($ErrorRecord.Exception.Message)" -ForegroundColor Red
    }
}

try {
    # Check if Scoop is installed
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        throw "Scoop is not installed. Please install Scoop first."
    }

    # Check if project directory exists
    $projectPath = "E:\data\vscodeproject\supabase"
    if (-not (Test-Path -Path $projectPath)) {
        Write-Host "Creating project directory..." -ForegroundColor Cyan
        New-Item -Path $projectPath -ItemType Directory -Force | Out-Null
    }

    # Change to the project directory
    Write-Host "Changing to project directory..." -ForegroundColor Cyan
    Set-Location -Path $projectPath -ErrorAction Stop

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

    Write-Host "`nSupabase environment created and started successfully!" -ForegroundColor Green
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