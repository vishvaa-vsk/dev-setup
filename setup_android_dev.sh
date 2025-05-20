#!/bin/bash

# For most (if not all) Linux distros, there is no official repository package available to install Android Studio
# and still get regular updates. This bash script automatically downloads and installs the latest version.

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

printf "\n========================================================"
printf "\n=== Android Development Environment Setup Script =======" 
printf "\n========================================================\n"

# Install all required dependencies at once
info "Installing required dependencies for Android development..."

# Try to install all potentially needed packages
dnf install -y --skip-unavailable clang cmake ninja-build gtk3-devel egl-utils curl git wget unzip xz zip mesa-demos mesa-libGLU glibc glibc.i686 \
    libstdc++ libstdc++.i686 bzip2-libs zlib.i686 glibc-devel.i686 glibc-minimal-langpack.i686 2>/dev/null || true

success "Dependencies installation completed."

# Create a temporary directory for downloads
TEMP_DIR="$HOME/Downloads/android_dev_setup_temp"
mkdir -p "$TEMP_DIR"

# Define installation directories
ANDROID_STUDIO_DIR="$HOME/Programs/Android_Studio"
FLUTTER_DIR="$HOME/Programs/flutter"

info "Finding latest Android Studio version for Linux..."

# Download the Android Studio download page which has the latest version number in the table
website="https://developer.android.com/studio#downloads"
main_html="$TEMP_DIR/android_studio_main.html"
curl -sL "$website" -o "$main_html"

# Try multiple extraction methods to get the version number
# Method 1: Extract from the Linux download link in the table
version=$(grep -o 'android-studio-[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+-linux.tar.gz' "$main_html" | head -1 | sed 's/android-studio-\(.*\)-linux.tar.gz/\1/')

# Method 2: Extract from any download link if Method 1 fails
if [ -z "$version" ]; then
    version=$(grep -o 'android-studio-[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' "$main_html" | head -1 | sed 's/android-studio-//')
fi

# Method 3: Extract from package name in the table
if [ -z "$version" ]; then
    version=$(grep -o 'android-studio-[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' "$main_html" | head -1 | sed 's/android-studio-//')
fi

if [ -z "$version" ]; then
    # Fallback to a known stable version if extraction fails
    version="2024.3.2.14"
    warn "Could not determine latest version, using fallback version $version"
else
    success "Detected latest stable Android Studio version: $version"
fi

# Construct the download URL
ANDROID_STUDIO_URL="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/$version/android-studio-$version-linux.tar.gz"
ANDROID_STUDIO_FILE="$TEMP_DIR/android_studio.tar.gz"

# Verify URL exists
if curl --output /dev/null --silent --head --fail "$ANDROID_STUDIO_URL"; then
    success "Found valid Android Studio download link: $ANDROID_STUDIO_URL"
else
    error "Failed to find downloadable Android Studio link."
fi

info "Finding latest Flutter SDK version for Linux..."

# Get Flutter SDK URL
FLUTTER_MANIFEST_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
FLUTTER_JSON="$TEMP_DIR/flutter_releases.json"
curl -s "$FLUTTER_MANIFEST_URL" -o "$FLUTTER_JSON"

FLUTTER_URL=$(grep -A 10 '"channel": "stable"' "$FLUTTER_JSON" | grep 'archive' | head -1 | sed -E 's/.*"archive": "([^"]+)".*/https:\/\/storage.googleapis.com\/flutter_infra_release\/releases\/\1/')
FLUTTER_FILE="$TEMP_DIR/flutter_sdk.tar.xz"

if [ -z "$FLUTTER_URL" ]; then
    error "Failed to get the latest Flutter SDK download link."
fi

success "Found Flutter SDK download link: $FLUTTER_URL"

# Ask user for confirmation
printf "\nReady to download and install:"
printf "\n - Android Studio $version"
printf "\n - Flutter SDK (latest stable)\n"
read -p "Do you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Aborted."
    exit 0
fi

# Download phase
info "Downloading packages..."

# Android Studio
if [ -f "$ANDROID_STUDIO_FILE" ] && [ -s "$ANDROID_STUDIO_FILE" ]; then
    info "Android Studio archive already exists at $ANDROID_STUDIO_FILE, skipping download."
else
    info "Downloading Android Studio ($version)..."
    wget -O "$ANDROID_STUDIO_FILE" "$ANDROID_STUDIO_URL" -q --show-progress
fi

# Flutter SDK
if [ -f "$FLUTTER_FILE" ] && [ -s "$FLUTTER_FILE" ]; then
    info "Flutter SDK archive already exists at $FLUTTER_FILE, skipping download."
else
    info "Downloading Flutter SDK..."
    wget -O "$FLUTTER_FILE" "$FLUTTER_URL" -q --show-progress
fi

# Installation phase
info "Installing packages..."

# Install Android Studio
info "Installing Android Studio..."
mkdir -p "$ANDROID_STUDIO_DIR"
info "Extracting Android Studio archive to $ANDROID_STUDIO_DIR..."
tar -xzf "$ANDROID_STUDIO_FILE" -C "$ANDROID_STUDIO_DIR" --strip-components=1
launcher="$ANDROID_STUDIO_DIR/bin/studio"
chmod +x "$launcher"

# Create Android Studio desktop entry for GNOME
DESKTOP_FILE="$HOME/.local/share/applications/android-studio.desktop"
ICON_PATH="$ANDROID_STUDIO_DIR/bin/studio.png"
if [ ! -f "$ICON_PATH" ]; then
    # Fallback to a generic icon if studio.png does not exist
    ICON_PATH="idea"
fi
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Icon=$ICON_PATH
Exec=$ANDROID_STUDIO_DIR/bin/studio %f
Comment=Android Studio IDE
Categories=Development;IDE;
Terminal=false
StartupNotify=true
EOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
info "Android Studio desktop entry created. You may need to log out and log in again to see the icon in your applications menu."

success "Android Studio has been installed."
info "You can start it with: $launcher"

# Install Flutter SDK
info "Installing Flutter SDK..."
mkdir -p "$FLUTTER_DIR"
info "Extracting Flutter SDK archive to $FLUTTER_DIR..."
tar -xf "$FLUTTER_FILE" -C "$FLUTTER_DIR" --strip-components=1

# Add flutter to PATH for current session
export PATH="$FLUTTER_DIR/bin:$PATH"
success "Flutter SDK installed at $FLUTTER_DIR"
info "Added Flutter to PATH for this session."

# Add Flutter to PATH in shell config files
info "Adding Flutter to PATH permanently..."
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "FLUTTER_DIR" "$HOME/.bashrc"; then
        echo -e "\n# Flutter SDK" >> "$HOME/.bashrc"
        echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$HOME/.bashrc"
        info "Added Flutter to PATH in .bashrc"
    fi
fi

if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "FLUTTER_DIR" "$HOME/.zshrc"; then
        echo -e "\n# Flutter SDK" >> "$HOME/.zshrc"
        echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$HOME/.zshrc"
        info "Added Flutter to PATH in .zshrc"
    fi
fi

info "To make it permanent, add this line to your ~/.bashrc or ~/.zshrc:"
printf 'export PATH="$FLUTTER_DIR/bin:$PATH"\n\n'

# Launch Android Studio first time setup if requested
read -p "Would you like to run Android Studio first-time setup now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -z "$DISPLAY" ]; then
        warn "No graphical environment detected. Please run Android Studio from a terminal inside your desktop session."
    else
        info "Launching Android Studio. Please complete the setup wizard."
        "$launcher" &
        # Wait for user to indicate they're done with Android Studio setup
        read -p "Press Enter after you have completed Android Studio setup and closed it..." -r
    fi
fi

# Add ANDROID_HOME and update PATH for Android SDK
ANDROID_SDK_DIR="$HOME/Android"
if [ -d "$ANDROID_SDK_DIR" ]; then
    # Add to .bashrc
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "ANDROID_HOME" "$HOME/.bashrc"; then
            echo -e "\n# Android SDK" >> "$HOME/.bashrc"
            echo "export ANDROID_HOME=\"$ANDROID_SDK_DIR\"" >> "$HOME/.bashrc"
            echo "export PATH=\"\$ANDROID_HOME/emulator:\$ANDROID_HOME/tools:\$ANDROID_HOME/tools/bin:\$ANDROID_HOME/platform-tools:\$PATH\"" >> "$HOME/.bashrc"
            info "Added ANDROID_HOME and Android SDK tools to PATH in .bashrc"
        fi
    fi
    # Add to .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "ANDROID_HOME" "$HOME/.zshrc"; then
            echo -e "\n# Android SDK" >> "$HOME/.zshrc"
            echo "export ANDROID_HOME=\"$ANDROID_SDK_DIR\"" >> "$HOME/.zshrc"
            echo "export PATH=\"\$ANDROID_HOME/emulator:\$ANDROID_HOME/tools:\$ANDROID_HOME/tools/bin:\$ANDROID_HOME/platform-tools:\$PATH\"" >> "$HOME/.zshrc"
            info "Added ANDROID_HOME and Android SDK tools to PATH in .zshrc"
        fi
    fi
fi

# Run Flutter doctor if requested
read -p "Would you like to run Flutter doctor now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Running 'flutter doctor'..."
    "$FLUTTER_DIR/bin/flutter" doctor
    
    # Accept Android licenses if requested
    read -p "Run 'flutter doctor --android-licenses' now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$FLUTTER_DIR/bin/flutter" doctor --android-licenses
    fi
fi

# Clean up
read -p "Remove downloaded files? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    info "Cleaning up temporary files..."
    rm -f "$ANDROID_STUDIO_FILE"
    rm -f "$FLUTTER_FILE"
    rm -f "$main_html"
    rm -f "$FLUTTER_JSON"
fi

printf "\n========================================================"
printf "\nSetup complete! Android development environment is ready."
printf "\n========================================================\n\n"