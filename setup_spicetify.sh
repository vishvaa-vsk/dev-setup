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

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"

printf "\n========================================================"
printf "\n=== Spotify with Spicetify Setup ====================="
printf "\n========================================================\n"

# setup flatpak with flathub
info "Setting up Flatpak with Flathub..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sleep 1
success "Flatpak setup completed."

# Install Spotify Client
info "Installing Spotify Client..."
flatpak install -y flathub com.spotify.Client
success "Spotify Client installation completed."

# Install Spicetify as the regular user, not as root
info "Installing Spicetify..."
# Create directory for Spicetify
su - "$ACTUAL_USER" -c "mkdir -p ~/.spicetify"

# Get latest version
SPICETIFY_VERSION=$(curl -s https://api.github.com/repos/spicetify/cli/releases/latest | grep 'tag_name' | cut -d'"' -f4 | sed 's/v//')
if [ -z "$SPICETIFY_VERSION" ]; then
    SPICETIFY_VERSION="2.40.7"  # Fallback version
    warn "Could not determine latest version, using fallback: $SPICETIFY_VERSION"
fi
info "Installing Spicetify version $SPICETIFY_VERSION..."

# Download and extract
su - "$ACTUAL_USER" -c "curl -L -o ~/.spicetify/spicetify.tar.gz https://github.com/spicetify/cli/releases/download/v${SPICETIFY_VERSION}/spicetify-${SPICETIFY_VERSION}-linux-amd64.tar.gz"
su - "$ACTUAL_USER" -c "tar -xzf ~/.spicetify/spicetify.tar.gz -C ~/.spicetify"
su - "$ACTUAL_USER" -c "rm ~/.spicetify/spicetify.tar.gz"
su - "$ACTUAL_USER" -c "chmod +x ~/.spicetify/spicetify"

# Add to PATH in both .bashrc and .zshrc if not already there
for rcfile in .bashrc .zshrc; do
    if [ -f "/home/$ACTUAL_USER/$rcfile" ]; then
        if ! grep -q "spicetify" "/home/$ACTUAL_USER/$rcfile"; then
            su - "$ACTUAL_USER" -c "echo 'export PATH=\"\$PATH:\$HOME/.spicetify\"' >> ~/$rcfile"
        fi
    fi
done

# Install marketplace extension manually
info "Installing Spicetify Marketplace..."
su - "$ACTUAL_USER" -c "mkdir -p ~/.config/spicetify/CustomApps"
# Remove existing marketplace directory if it exists
su - "$ACTUAL_USER" -c "rm -rf ~/.config/spicetify/CustomApps/marketplace"
su - "$ACTUAL_USER" -c "curl -L -o ~/.config/spicetify/CustomApps/marketplace.zip https://github.com/spicetify/spicetify-marketplace/archive/refs/heads/main.zip"
su - "$ACTUAL_USER" -c "unzip -o ~/.config/spicetify/CustomApps/marketplace.zip -d ~/.config/spicetify/CustomApps/"
su - "$ACTUAL_USER" -c "mv ~/.config/spicetify/CustomApps/marketplace-main ~/.config/spicetify/CustomApps/marketplace"
su - "$ACTUAL_USER" -c "rm ~/.config/spicetify/CustomApps/marketplace.zip"

success "Spicetify installation completed."

# Configure Spicetify
info "Configuring Spicetify..."

# Make sure the .spicetify directory is properly owned
chown -R "$ACTUAL_USER:$(id -gn "$ACTUAL_USER")" "/home/$ACTUAL_USER/.spicetify"
chown -R "$ACTUAL_USER:$(id -gn "$ACTUAL_USER")" "/home/$ACTUAL_USER/.config/spicetify"

# First set proper permissions for Spotify files
chmod a+wr /var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify
chmod a+wr -R /var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify/Apps

# Set configuration as the user - first make sure the config directory exists
su - "$ACTUAL_USER" -c 'mkdir -p ~/.config/spicetify'

# Set paths in the config-xpui.ini file directly
info "Setting up config-xpui.ini file with correct Spotify paths..."
su - "$ACTUAL_USER" -c 'cat > ~/.config/spicetify/config-xpui.ini << EOF
[Setting]
spotify_path            = /var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify/
prefs_path              = /home/$USER/.var/app/com.spotify.Client/config/spotify/prefs
current_theme           = 
color_scheme            = 
inject_css              = 1
replace_colors          = 1
overwrite_assets        = 0
spotify_launch_flags    = 
check_spicetify_upgrade = 0
always_enable_devtools  = 0
spotify_path_arch       = stable

[Preprocesses]
disable_sentry        = 1
disable_ui_logging    = 1
remove_rtl_rule       = 1
expose_apis           = 1
disable_upgrade_check = 1

[AdditionalOptions]
extensions            = marketplace.js
custom_apps           = marketplace
sidebar_config        = 1

[Patch]

[Backup]
version = 
with    = 2.40.7
EOF'

# Configure Path settings using spicetify command (same as in config-xpui.ini but ensures CLI is happy)
su - "$ACTUAL_USER" -c 'export PATH="$PATH:$HOME/.spicetify" && \
spicetify config spotify_path "/var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify/" && \
spicetify config prefs_path "/home/$USER/.var/app/com.spotify.Client/config/spotify/prefs" && \
spicetify config custom_apps marketplace && \
spicetify config extensions marketplace.js'

# Apply the config
info "Applying Spicetify configuration..."
# Wait for Spicetify to be fully installed and available
sleep 2
su - "$ACTUAL_USER" -c 'export PATH="$PATH:$HOME/.spicetify" && spicetify backup apply'

success "Spicetify configuration completed!"