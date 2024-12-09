<#
.SYNOPSIS
    Creates a local install of Supabase. You can use all their tools locally

.DESCRIPTION
    This script creates a local install of a,Supabase environment using Scoop package manager.
    It adds the Supabase bucket, installs Supabase, and starts the development environment.

.NOTES
    Last Updated: 2024-12-08
    Requirements:
        - Scoop package manager
        - Administrator privileges may be required
        - Internet connection for GitHub access

    This is primarily for my own installs so has my paths embedded. I may get round to 
    making it more dynamic.

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

    # Add Windows Forms assembly for folder browser dialog
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Create and show folder browser dialog in a separate thread
    $form = New-Object System.Windows.Forms.Form -Property @{
        TopMost = $true
        TopLevel = $true
    }
    $form.ShowInTaskbar = $false
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized

    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select installation directory for Supabase"
    $folderBrowser.RootFolder = [System.Environment+SpecialFolder]::MyComputer
    $folderBrowser.ShowNewFolderButton = $true

    $form.Add_Shown({
        $form.Activate()
        $result = $folderBrowser.ShowDialog($form)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:projectPath = $folderBrowser.SelectedPath
        } else {
            $script:projectPath = $null
        }
        $form.Close()
    })
    $form.ShowDialog()

    if ($null -eq $projectPath) {
        throw "Installation cancelled by user"
    }

    # Check if project directory exists
    if (-not (Test-Path -Path $projectPath)) {
        Write-Host "Creating project directory at $projectPath..." -ForegroundColor Cyan
        New-Item -Path $projectPath -ItemType Directory -Force | Out-Null
    }

    # Change to the project directory
    Write-Host "Changing to project directory..." -ForegroundColor Cyan
    Set-Location -Path $projectPath -ErrorAction Stop

    # Add latest Supabase bucket if it doesn't exist
    Write-Host "Checking Supabase bucket..." -ForegroundColor Cyan
    $existingBuckets = (scoop bucket list) | ForEach-Object { $_.Name }
    if ($existingBuckets -notcontains "supabase") {
        Write-Host "Adding Supabase bucket..." -ForegroundColor Cyan
        scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to add Supabase bucket"
        }
    } else {
        Write-Host "Supabase bucket already exists, skipping..." -ForegroundColor Yellow
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