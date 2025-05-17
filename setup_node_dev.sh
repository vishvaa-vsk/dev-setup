#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

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

TARGET_USER="${SUDO_USER:-$(whoami)}"
NVM_DIR="/home/$TARGET_USER/.nvm"

printf "\n========================================================"
printf "\n=== Node.js Development Environment Setup Script ======="
printf "\n========================================================\n"

# Check for required dependencies
required_pkgs="curl git"

printf "\nChecking dependencies...\n"
missing_pkgs=""

# Check the main required packages
for pkg in $required_pkgs; do
    if ! rpm -q $pkg &>/dev/null; then
        missing_pkgs="$missing_pkgs $pkg"
    fi
done

if [ -n "$missing_pkgs" ]; then
    printf "Missing dependencies:$missing_pkgs\n"
    
    if [ "$(id -u)" -ne 0 ]; then
        error "Please run this script as root or with sudo to install dependencies."
    fi
    
    printf "Installing missing dependencies...\n"
    dnf install -y $missing_pkgs
    
    # Check if critical packages were installed
    critical_failure=0
    for pkg in curl git; do
        if ! rpm -q $pkg &>/dev/null; then
            printf "Critical package $pkg failed to install!\n"
            critical_failure=1
        fi
    done
    
    if [ $critical_failure -eq 1 ]; then
        printf "Failed to install critical packages. Please install them manually and try again.\n"
        exit 1
    else
        printf "Dependencies installed successfully.\n"
    fi
else
    printf "All dependencies are installed.\n"
fi

# Install NVM
info "Installing Node Version Manager (NVM)..."

# Get latest NVM version
NVM_LATEST=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep 'tag_name' | sed -e 's/.*"tag_name": "v\(.*\)".*/\1/')

if [ -z "$NVM_LATEST" ]; then
    NVM_LATEST="0.40.3" # Fallback version
    warn "Could not determine latest NVM version, using fallback: $NVM_LATEST"
else
    success "Found latest NVM version: $NVM_LATEST"
fi

# Install NVM if not already installed
if [ ! -d "$NVM_DIR" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        info "Installing NVM v$NVM_LATEST for user $TARGET_USER..."
        su - "$TARGET_USER" -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_LATEST/install.sh | bash"
    else
        info "Installing NVM v$NVM_LATEST..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_LATEST/install.sh | bash
    fi
    success "NVM installed successfully."
else
    info "NVM is already installed."
fi

# Install latest LTS Node.js and set it as default
info "Installing Node.js LTS version..."
if [ "$(id -u)" -eq 0 ]; then
    su - "$TARGET_USER" -c "source \"$NVM_DIR/nvm.sh\" && nvm install --lts"
    su - "$TARGET_USER" -c "source \"$NVM_DIR/nvm.sh\" && nvm use --lts"
    su - "$TARGET_USER" -c "source \"$NVM_DIR/nvm.sh\" && nvm alias default \$(nvm current)"
else
    source "$NVM_DIR/nvm.sh" && nvm install --lts
    source "$NVM_DIR/nvm.sh" && nvm use --lts
    source "$NVM_DIR/nvm.sh" && nvm alias default $(nvm current)
fi

# Get current Node.js version
if [ "$(id -u)" -eq 0 ]; then
    NODE_VERSION=$(su - "$TARGET_USER" -c "source \"$NVM_DIR/nvm.sh\" && node --version")
else
    NODE_VERSION=$(source "$NVM_DIR/nvm.sh" && node --version)
fi
success "Node.js $NODE_VERSION installed and set as default."

# Install yarn
info "Installing Yarn..."
if [ "$(id -u)" -eq 0 ]; then
    su - "$TARGET_USER" -c "source \"$NVM_DIR/nvm.sh\" && npm install -g yarn"
else
    source "$NVM_DIR/nvm.sh" && npm install -g yarn
fi
success "Yarn installed successfully."

printf "\n========================================================"
printf "\nNode.js development environment setup complete!"
printf "\n========================================================\n\n"
