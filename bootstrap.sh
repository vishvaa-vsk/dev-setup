#!/bin/bash
set -euo pipefail

# Define colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[1;31m"
NC="\033[0m" # No Color

function info() { echo -e "${BLUE}[INFO]${NC} $1"; }
function success() { echo -e "${GREEN}[✔]${NC} $1"; }
function warn() { echo -e "${YELLOW}[!]${NC} $1"; }
function error() { echo -e "${RED}[✘]${NC} $1"; exit 1; }

function show_help() {
    cat << EOF
    
Fedora Dev + Hyprland Setup Bootstrap Script
============================================

This script downloads and runs all the necessary setup scripts to configure 
a complete development environment on Fedora Linux.

Usage:
    sudo bash bootstrap.sh [OPTIONS]

Options:
    -h, --help     Show this help message and exit
    --no-cleanup   Keep downloaded scripts after installation

Note: This script must be run as root or with sudo privileges.

EOF
    exit 0
}

# Parse command line arguments
NO_CLEANUP=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --no-cleanup)
            NO_CLEANUP=1
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo."
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap 'echo "Cleaning up..."; [[ $NO_CLEANUP -eq 0 ]] && rm -rf "$TEMP_DIR"' EXIT
cd "$TEMP_DIR" || exit 1

info "Downloading setup scripts from repository..."

# Download all required scripts
BASE_URL="https://raw.githubusercontent.com/vishvaa-vsk/dev-setup/main"
SCRIPTS=("setup.sh" "setup_android_dev.sh" "setup_node_dev.sh" "setup_python_dev.sh")

for script in "${SCRIPTS[@]}"; do
    info "Downloading $script..."
    if ! curl -fsSL "$BASE_URL/$script" -o "$script"; then
        error "Failed to download $script. Please check your internet connection and try again."
    fi
    chmod +x "$script"
done

success "All scripts downloaded successfully."
info "Running main setup script..."

# Run the main setup script
bash setup.sh

# Keep the scripts if requested
if [[ $NO_CLEANUP -eq 1 ]]; then
    mkdir -p "/home/$SUDO_USER/dev-setup-scripts" 2>/dev/null || true
    cp -f ./* "/home/$SUDO_USER/dev-setup-scripts/"
    success "Scripts saved to /home/$SUDO_USER/dev-setup-scripts/"
fi

success "Setup complete!"
