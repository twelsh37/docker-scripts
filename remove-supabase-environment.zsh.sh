#!/usr/bin/env zsh

# Function to print colored output
print_status() {
    local message=$1
    echo "\033[36m$message\033[0m"
}

# Function to handle errors
error_log() {
    local message=$1
    echo "\033[31mError: $message\033[0m"
}

# Main script
main() {
    print_status "Uninstalling Supabase..."
    brew uninstall supabase 2>/dev/null || {
        error_log "Failed to uninstall Supabase"
        exit 1
    }

    print_status "Supabase has been successfully uninstalled!"
}

# Run main script
main
