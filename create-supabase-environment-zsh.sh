#!/bin/zsh

# Enable error handling
set -e

# Function to handle errors
function error_log() {
    local message=$1
    echo "\033[31mError: $message\033[0m"
}

# Function to print colored output
function print_status() {
    local message=$1
    echo "\033[36m$message\033[0m"
}

function print_success() {
    local message=$1
    echo "\033[32m$message\033[0m"
}

function print_warning() {
    local message=$1
    echo "\033[33m$message\033[0m"
}

try {
    # Store original directory
    original_dir=$(pwd)

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error_log "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        error_log "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi

    # Prompt for installation directory
    print_status "Enter the installation directory path (or press Enter for current directory):"
    read project_path

    if [[ -z "$project_path" ]]; then
        project_path=$(pwd)
    fi

    # Create directory if it doesn't exist
    if [[ ! -d "$project_path" ]]; then
        print_status "Creating project directory at $project_path..."
        mkdir -p "$project_path"
    fi

    # Change to project directory
    print_status "Changing to project directory..."
    cd "$project_path"

    # Install Supabase CLI
    print_status "Installing Supabase CLI..."
    if ! command -v supabase &> /dev/null; then
        brew install supabase/tap/supabase
    else
        print_warning "Supabase CLI already installed, skipping..."
    fi

    # Initialize Supabase project
    print_status "Initializing Supabase project..."
    supabase init

    # Start Supabase
    print_status "Starting Supabase..."
    supabase start

    print_success "\nSupabase environment created and started successfully!"

} always {
    # Change back to original directory
    print_status "Changing back to original directory..."
    cd "$original_dir"
}