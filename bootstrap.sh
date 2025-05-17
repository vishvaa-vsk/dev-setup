#!/bin/bash
set -e

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Please use: sudo bash bootstrap-simple.sh"
fi

# Store the actual user (even when sudo is used)
ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~${ACTUAL_USER})

# Create a directory in the user's home to store the scripts
SCRIPTS_DIR="$USER_HOME/dev-setup-scripts"
mkdir -p "$SCRIPTS_DIR"
chown "$ACTUAL_USER:$(id -gn "$ACTUAL_USER")" "$SCRIPTS_DIR"

# Download all required scripts directly to the scripts directory
info "Downloading setup scripts..."
BASE_URL="https://raw.githubusercontent.com/vishvaa-vsk/dev-setup/main"
SCRIPTS=("setup.sh" "setup_android_dev.sh" "setup_node_dev.sh" "setup_python_dev.sh")

cd "$SCRIPTS_DIR"

for script in "${SCRIPTS[@]}"; do
    info "Downloading $script..."
    curl -fsSL "$BASE_URL/$script" -o "$script" || error "Failed to download $script"
    chmod +x "$script"
done

# List files for debugging
info "Downloaded files:"
ls -la

success "All scripts downloaded successfully."

# Run the main setup script
info "Executing setup script..."
bash "$SCRIPTS_DIR/setup.sh"

success "Setup complete!"