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
PYENV_ROOT="/home/$TARGET_USER/.pyenv"

printf "\n========================================================"
printf "\n=== Python Development Environment Setup Script ========"
printf "\n========================================================\n"

# Install system Python
info "Installing system Python 3..."
if [ "$(id -u)" -ne 0 ]; then
    error "Please run this script as root or with sudo to install packages."
fi

# Install Python 3 from the distribution's repository
dnf install -y python3 python3-pip || error "Python install failed."
success "System Python installed successfully."

# Check for required dependencies for pyenv
required_pkgs="curl git gcc make zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel"

printf "\nChecking pyenv dependencies...\n"
missing_pkgs=""

# Check the main required packages
for pkg in $required_pkgs; do
    base_pkg=${pkg%%-devel}
    if ! rpm -q $base_pkg &>/dev/null; then
        missing_pkgs="$missing_pkgs $pkg"
    fi
done

if [ -n "$missing_pkgs" ]; then
    printf "Missing dependencies:$missing_pkgs\n"
    printf "Installing pyenv dependencies...\n"
    dnf install -y --skip-unavailable $missing_pkgs
    
    # Check if critical packages were installed
    critical_failure=0
    for pkg in curl git gcc make; do
        if ! rpm -q $pkg &>/dev/null; then
            printf "Critical package $pkg failed to install!\n"
            critical_failure=1
        fi
    done
    
    if [ $critical_failure -eq 1 ]; then
        printf "Failed to install critical packages. pyenv might not work properly.\n"
    else
        printf "Dependencies installed successfully.\n"
    fi
else
    printf "All dependencies are installed.\n"
fi

# Install pyenv
info "Setting up Pyenv for Python version management..."

# Install pyenv for the target user
su - "$TARGET_USER" -c "curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash"

# Add pyenv to shell configuration
shell_config=""
if [ -f "/home/$TARGET_USER/.bashrc" ]; then
    shell_config="/home/$TARGET_USER/.bashrc"
elif [ -f "/home/$TARGET_USER/.zshrc" ]; then
    shell_config="/home/$TARGET_USER/.zshrc"
fi

if [ -n "$shell_config" ]; then
    # Check if pyenv is already in config
    if ! grep -q "pyenv init" "$shell_config"; then
        # Add pyenv init to the shell configuration file
        su - "$TARGET_USER" -c "cat >> $shell_config << 'EOF'

# Pyenv setup
export PYENV_ROOT=\"\$HOME/.pyenv\"
export PATH=\"\$PYENV_ROOT/bin:\$PATH\"
eval \"\$(pyenv init --path)\"
eval \"\$(pyenv init -)\"
eval \"\$(pyenv virtualenv-init -)\"
EOF"
        success "Added pyenv configuration to $shell_config"
    else
        info "Pyenv configuration already exists in $shell_config"
    fi
else
    warn "Could not find shell configuration file (.bashrc or .zshrc)"
    info "Please add the following lines to your shell configuration file:"
    echo 'export PYENV_ROOT="$HOME/.pyenv"'
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"'
    echo 'eval "$(pyenv init --path)"'
    echo 'eval "$(pyenv init -)"'
    echo 'eval "$(pyenv virtualenv-init -)"'
fi

info "Python setup completed with system Python and pyenv for version management."
info "You may need to restart your shell or run 'source $shell_config' to use pyenv."

printf "\n========================================================"
printf "\nPython environment setup complete!"
printf "\n========================================================\n\n"
