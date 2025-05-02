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

# Check root
if [[ $EUID -ne 0 ]]; then
    error "Please run this script as root or with sudo."
fi

TARGET_USER="${SUDO_USER:-$(whoami)}"

read -p "This script will set up a dev environment + Hyprland on Fedora. Continue? (y/N): " proceed
[[ "$proceed" =~ ^[Yy]$ ]] || { warn "Aborted."; exit 1; }

info "Updating system..."
dnf -y update

# Core tools
info "Installing base tools..."
dnf install -y git curl wget gnupg2 unzip tar || error "Core tools install failed."

# VSCode
info "Setting up VS Code..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat <<EOF > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
dnf install -y code || error "VS Code install failed."

# Brave Browser
info "Installing Brave browser..."
curl -fsS https://dl.brave.com/install.sh | bash || error "Brave install failed."

# NVM & Node.js LTS
info "Installing Node.js LTS via NVM..."
if [[ ! -d "$HOME/.nvm" ]]; then
    su - "$TARGET_USER" -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
fi
export NVM_DIR="/home/$TARGET_USER/.nvm"
source "$NVM_DIR/nvm.sh"
su - "$TARGET_USER" -c "source $NVM_DIR/nvm.sh && nvm install --lts && npm install -g yarn"

# Python 3
info "Installing Python 3..."
dnf install -y python3 python3-pip || error "Python install failed."

# JDK 21
read -p "Install OpenJDK 21? (y/N): " jdk
[[ "$jdk" =~ ^[Yy]$ ]] && dnf install -y java-21-openjdk java-21-openjdk-devel || true

# GCC & G++
info "Installing GCC..."
dnf install -y gcc gcc-c++ || error "GCC install failed."

# Docker
info "Installing Docker..."
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error "Docker install failed."
systemctl enable --now docker

read -p "Add '$TARGET_USER' to docker group? (y/N): " dockergroup
[[ "$dockergroup" =~ ^[Yy]$ ]] && usermod -aG docker "$TARGET_USER"

# Performance tweaks
info "Enabling system optimizations..."
systemctl enable fstrim.timer
systemctl enable --now systemd-oomd
dnf install -y preload && systemctl enable --now preload

# ZRAM setup
info "Enabling ZRAM swap..."
dnf install -y zram-generator
mkdir -p /etc/systemd/zram-generator.conf.d
cat <<EOF > /etc/systemd/zram-generator.conf.d/zram.conf
[zram0]
zram-size = 8192
compression-algorithm = zstd
EOF
systemctl daemon-reexec
systemctl enable --now systemd-zram-setup@zram0.service
systemctl restart systemd-zram-setup@zram0.service

# Hyprland Dotfiles (JaKooLit)
read -p "Install Hyprland (JaKooLit) setup? (y/N): " hypr
[[ "$hypr" =~ ^[Yy]$ ]] && su - "$TARGET_USER" -c 'sh <(curl -L https://raw.githubusercontent.com/JaKooLit/Fedora-Hyprland/main/auto-install.sh)' || true

success "All setup complete! Please reboot your system to apply all changes."
