#!/bin/bash

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

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

info "Downloading setup scripts from repository..."

# Download all required scripts
BASE_URL="https://raw.githubusercontent.com/vishvaa-vsk/dev-setup/main"
curl -fsSL "$BASE_URL/setup.sh" -o setup.sh || error "Failed to download main setup script"
curl -fsSL "$BASE_URL/setup_android_dev.sh" -o setup_android_dev.sh || error "Failed to download Android setup script"
curl -fsSL "$BASE_URL/setup_node_dev.sh" -o setup_node_dev.sh || error "Failed to download Node.js setup script" 
curl -fsSL "$BASE_URL/setup_python_dev.sh" -o setup_python_dev.sh || error "Failed to download Python setup script"

# Make scripts executable
chmod +x setup.sh setup_android_dev.sh setup_node_dev.sh setup_python_dev.sh

success "All scripts downloaded successfully."
info "Running main setup script..."

# Run the main setup script
sudo bash setup.sh

# Clean up
cd / && rm -rf "$TEMP_DIR"
