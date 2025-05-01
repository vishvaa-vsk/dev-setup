#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Check if script is run as root or sudo
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

# Determine the user to add to docker group (original user if sudo, else current user)
if [[ -n "$SUDO_USER" ]]; then
    TARGET_USER="$SUDO_USER"
else
    TARGET_USER="$(whoami)"
fi

# Confirm to proceed
read -p "This script will install a developer environment and Hyprland dotfiles on Fedora. Continue? (y/N) " proceed
if [[ ! "$proceed" =~ ^[Yy] ]]; then
    echo "Aborted by user."
    exit 1
fi

echo "Updating system packages..."
dnf -y update

# 1. Install core tools
echo "Installing core tools (git, curl, wget, gnupg2, unzip, tar)..."
dnf install -y git curl wget gnupg2 unzip tar || { echo "Failed to install core tools."; exit 1; }

# 2. Install VS Code via Microsoft RPM repo
echo "Setting up Visual Studio Code repository..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc || { echo "Failed to import Microsoft GPG key for VS Code."; exit 1; }
cat <<EOF | tee /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
echo "Installing Visual Studio Code..."
dnf install -y code || { echo "Failed to install VS Code."; exit 1; }

# 3. Install Brave browser via official RPM repo
echo "Setting up Brave browser repository..."
dnf install -y dnf-plugins-core || { echo "Failed to install dnf-plugins-core for Brave."; exit 1; }
dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || { echo "Failed to add Brave repo."; exit 1; }
echo "Installing Brave browser..."
dnf install -y brave-browser || { echo "Failed to install Brave browser."; exit 1; }

# 4. Install Node.js LTS via NVM and Yarn
echo "Installing NVM (Node Version Manager)..."
if [[ ! -d "$HOME/.nvm" ]]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1090
source "$NVM_DIR/nvm.sh"
echo "Installing Node.js LTS..."
nvm install --lts || { echo "Failed to install Node.js LTS."; exit 1; }
nvm use --lts
echo "Installing Yarn globally..."
npm install -g yarn || { echo "Failed to install Yarn."; exit 1; }

# 5. Install Python 3 and pip
echo "Installing Python3 and pip..."
dnf install -y python3 python3-pip || { echo "Failed to install Python3/pip."; exit 1; }

# 6. Install JDK 21 (OpenJDK)
read -p "Do you want to install JDK 21 from OpenJDK ? (y/N) " jdk
if [[ "$jdk" =~ ^[Yy] ]]; then
    echo "Installing OpenJDK 21..."
    dnf install -y java-21-openjdk java-21-openjdk-devel || { echo "Failed to install OpenJDK 21."; exit 1; }
fi

# 7. Install GCC and G++
echo "Installing GCC and G++..."
dnf install -y gcc gcc-c++ || { echo "Failed to install GCC/G++."; exit 1; }

# Optional: Development tools (make, etc.)
read -p "Install additional development tools (make, etc.)? (y/N) " devtools
if [[ "$devtools" =~ ^[Yy] ]]; then
    echo "Installing Development Tools group..."
    dnf groupinstall "Development Tools" || { echo "Failed to install Development Tools."; exit 1; }
fi

# 8. Install Docker
echo "Setting up Docker repository..."
dnf install -y dnf-plugins-core || { echo "Failed to install dnf-plugins-core for Docker."; exit 1; }
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || { echo "Failed to add Docker repo."; exit 1; }
echo "Installing Docker CE and related packages..."
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo "Failed to install Docker."; exit 1; }
echo "Enabling and starting Docker service..."
systemctl enable --now docker || { echo "Failed to start Docker."; exit 1; }

# Add user to docker group (optional)
read -p "Add user '$TARGET_USER' to the docker group? (y/N) " dockergroup
if [[ "$dockergroup" =~ ^[Yy] ]]; then
    usermod -aG docker "$TARGET_USER" || { echo "Failed to add user to docker group."; exit 1; }
    echo "User '$TARGET_USER' added to docker group. You may need to log out and log back in for this change to take effect."
fi

# 9. Run Hyprland dotfiles setup
read -p "Run Hyprland dotfiles setup (this will clone and run the Fedora setup script from GitHub)? (y/N) " hypr
if [[ "$hypr" =~ ^[Yy] ]]; then
    echo "Running Hyprland dotfiles setup..."
    bash <(curl -fsSL https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/setup-fedora.sh) || { echo "Hyprland setup script failed."; exit 1; }
    echo "Hyprland dotfiles setup completed."
fi

echo "Developer environment setup complete!"
