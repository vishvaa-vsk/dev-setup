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

# Configure DNF for faster downloads
info "Configuring DNF for faster downloads..."
if ! grep -q "max_parallel_downloads" /etc/dnf/dnf.conf; then
    echo "Adding max_parallel_downloads=10 to dnf.conf"
    echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
fi

if ! grep -q "fastestmirror" /etc/dnf/dnf.conf; then
    echo "Adding fastestmirror=true to dnf.conf"
    echo "fastestmirror=true" >> /etc/dnf/dnf.conf
fi
success "DNF configured for faster downloads"

TARGET_USER="${SUDO_USER:-$(whoami)}"

read -p "This script will set up a dev environment + Hyprland on Fedora Workstation. Continue? (y/N): " proceed
[[ "$proceed" =~ ^[Yy]$ ]] || { warn "Aborted."; exit 1; }

info "Updating system..."
dnf -y update
fwupdmgr refresh --force
fwupdmgr update

info "Enableing RPM Fusion repositories..."
dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm -y
dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
dnf upgrade --refresh

info "De-bloating the GNOME desktop..."
dnf remove gnome-tour gnome-maps gnome-weather gnome-contacts gnome-clocks yelp gnome-web evince rhythmbox totem

# Core tools
info "Installing base tools..."
dnf install -y git curl wget gnupg2 unzip tar ssh || error "Core tools install failed."

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

read -p "Remove Firefox? (y/N): " remove_firefox
if [[ "$remove_firefox" =~ ^[Yy]$ ]]; then
    info "Removing Firefox..."
    dnf remove -y firefox || error "Firefox removal failed."
else
    info "Keeping Firefox installed."
fi

# Brave Browser
info "Installing Brave browser..."
curl -fsS https://dl.brave.com/install.sh | bash || error "Brave install failed."

# Node.js & Python development setup
read -p "Install Node.js development environment (NVM with npm and yarn)? (Y/n): " node_dev
if [[ ! $node_dev =~ ^[Nn]$ ]]; then
    info "Setting up Node.js development environment with nvm and yarn..."
    bash "$(dirname "$0")/setup_node_dev.sh" || warn "Node.js setup failed!"
fi

read -p "Install Python with pyenv? (Y/n): " python_dev
if [[ ! $python_dev =~ ^[Nn]$ ]]; then
    info "Setting up Python environment (system Python with pyenv)..."
    bash "$(dirname "$0")/setup_python_dev.sh" || warn "Python setup failed!"
fi

# JDK 21
read -p "Install OpenJDK 21? (y/N): " jdk
[[ "$jdk" =~ ^[Yy]$ ]] && dnf install -y java-21-openjdk java-21-openjdk-devel || true

# Android development setup
read -p "Install Android development environment? (y/N): " android_dev
if [[ "$android_dev" =~ ^[Yy]$ ]]; then
    info "Setting up Android development environment..."
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    ANDROID_SCRIPT="$SCRIPT_DIR/setup_android_dev.sh"
    
    # Copy script to user's home directory temporarily to ensure it's accessible
    cp "$ANDROID_SCRIPT" "/home/$TARGET_USER/setup_android_dev_temp.sh"
    chmod +x "/home/$TARGET_USER/setup_android_dev_temp.sh"
    
    su - "$TARGET_USER" -c "bash /home/$TARGET_USER/setup_android_dev_temp.sh" || warn "Android setup failed!"
    
    # Clean up temporary script
    rm -f "/home/$TARGET_USER/setup_android_dev_temp.sh"
fi

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

# Add legacy docker-compose command
info "Setting up legacy docker-compose command..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | sed -e 's/.*"tag_name": "v\(.*\)".*/\1/')
if [[ -n "$DOCKER_COMPOSE_VERSION" ]]; then
  success "Found Docker Compose version: $DOCKER_COMPOSE_VERSION"
  curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
  success "Legacy docker-compose command installed successfully. You can now use both 'docker compose' and 'docker-compose'."
else
  warn "Could not determine latest Docker Compose version. Setting up wrapper script instead."
  cat > /usr/local/bin/docker-compose << 'EOF'
#!/bin/bash
docker compose "$@"
EOF
  chmod +x /usr/local/bin/docker-compose
  ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
  success "Legacy docker-compose wrapper script installed. You can now use both 'docker compose' and 'docker-compose'."
fi

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

# Zsh with Oh My Zsh setup
read -p "Install Zsh with Oh My Zsh? (y/N): " install_zsh
if [[ "$install_zsh" =~ ^[Yy]$ ]]; then
    info "Installing Zsh..."
    dnf install -y zsh || error "Zsh installation failed."
    
    # Install Oh My Zsh for the target user
    info "Installing Oh My Zsh for $TARGET_USER..."
    su - "$TARGET_USER" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' || warn "Oh My Zsh installation failed!"
    
    # Install popular plugins
    info "Installing useful Zsh plugins..."
    
    # zsh-syntax-highlighting
    su - "$TARGET_USER" -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting' || warn "zsh-syntax-highlighting installation failed!"
    
    
    # powerlevel10k theme (popular theme with nice features)
    su - "$TARGET_USER" -c 'git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k' || warn "powerlevel10k theme installation failed!"
    
    # Update .zshrc to use the plugins and theme
    su - "$TARGET_USER" -c 'sed -i "s/ZSH_THEME=.*/ZSH_THEME=\"powerlevel10k\/powerlevel10k\"/" ~/.zshrc'
    su - "$TARGET_USER" -c 'sed -i "s/plugins=(git)/plugins=(git zsh-syntax-highlighting)/" ~/.zshrc'

    # Set Zsh as default shell for the user
    read -p "Set Zsh as the default shell for $TARGET_USER? (y/N): " set_zsh_default
    if [[ "$set_zsh_default" =~ ^[Yy]$ ]]; then
        info "Setting Zsh as default shell for $TARGET_USER..."
        chsh -s /bin/zsh "$TARGET_USER" || warn "Failed to change default shell to Zsh!"
        success "Zsh is now the default shell for $TARGET_USER!"
        info "You'll need to log out and back in for the shell change to take effect."
    fi
    
    success "Zsh with Oh My Zsh has been installed successfully!"
fi

success "All setup complete! Please reboot your system to apply all changes."