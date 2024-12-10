#!/usr/bin/env zsh

# DESCRIPTION
#    This script removes existing Supabase bucket and installation

# Enable strict error handling
set -e
set -u

# Function to handle errors
error_log() {
    local message=$1
    echo "\033[31mError: $message\033[0m"
}

# Function to print colored output
print_status() {
    local message=$1
    echo "\033[36m$message\033[0m"
}

# Main script
main() {
    # Change to the project directory
    print_status "Changing to project directory..."
    cd "/path/to/your/supabase/project" || {
        error_log "Failed to change directory"
        exit 1
    }

    # Remove existing Supabase bucket
    print_status "Removing existing Supabase bucket..."
    scoop bucket rm supabase 2>/dev/null || true

    # Uninstall existing Supabase
    print_status "Uninstalling existing Supabase..."
    scoop uninstall supabase 2>/dev/null || true

    echo "\033[32m\nSupabase removal completed successfully!\033[0m"
}

# Wrap the main script in a try-catch block
{
    main
} always {
    # Change back to docker-scripts directory
    print_status "Changing back to docker-scripts folder..."
    cd "/path/to/your/docker-scripts" || {
        error_log "Failed to change back to docker-scripts directory"
        exit 1
    }
} 