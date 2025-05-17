#!/bin/bash

# For most (if not all) Linux distros, there is no official repository package available to install Android Studio
# and still get regular updates. This bash script automatically downloads and installs the latest version.

printf "\n========================================================"
printf "\n=== Android Development Environment Setup Script =======" 
printf "\n========================================================\n"

# Check for required dependencies
# Mapping Debian packages to Fedora equivalents with more accurate package names
required_pkgs="curl git unzip xz zip mesa-libGLU glibc glibc.i686 libstdc++ libstdc++.i686 bzip2-libs"
additional_pkgs="wget" # Packages that might have different names or could be already installed via alternative packages

printf "\nChecking dependencies...\n"
missing_pkgs=""

# Check for wget or wget2 (either is fine)
if ! rpm -q wget &>/dev/null && ! rpm -q wget2 &>/dev/null; then
    missing_pkgs="$missing_pkgs wget"
fi

# Check for 32-bit zlib support (package name varies)
if ! rpm -q zlib.i686 &>/dev/null && ! rpm -q glibc-minimal-langpack.i686 &>/dev/null; then
    # Try to find the correct package for 32-bit zlib
    if dnf list glibc-devel.i686 &>/dev/null; then
        missing_pkgs="$missing_pkgs glibc-devel.i686"
    elif dnf list zlib.i686 &>/dev/null; then
        missing_pkgs="$missing_pkgs zlib.i686"
    elif dnf list glibc-minimal-langpack.i686 &>/dev/null; then
        missing_pkgs="$missing_pkgs glibc-minimal-langpack.i686"
    fi
fi

# Check the main required packages
for pkg in $required_pkgs; do
    base_pkg=${pkg%%.i686}
    base_pkg=${base_pkg%%.x86_64}
    if ! rpm -q $base_pkg &>/dev/null; then
        missing_pkgs="$missing_pkgs $pkg"
    fi
done

if [ -n "$missing_pkgs" ]; then
    printf "Missing dependencies:$missing_pkgs\n"
    read -p "Do you want to install the missing dependencies? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "Cannot continue without required packages. Aborting.\n"
        exit 1
    fi
    printf "Installing missing dependencies...\n"
    dnf install -y --skip-unavailable $missing_pkgs
    
    # Check if all critical packages were installed
    critical_failure=0
    for pkg in curl git unzip; do
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

# Create a temporary directory for downloads
TEMP_DIR="$HOME/Downloads/android_dev_setup_temp"
mkdir -p "$TEMP_DIR"

# Define installation directories
ANDROID_STUDIO_DIR="$HOME/Programs/Android_Studio"
FLUTTER_DIR="$HOME/Programs/flutter"

printf "\n[1/4] Finding latest Android Studio version for Linux...\n"

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
    printf "Warning: Could not determine latest version, using fallback version $version\n"
else
    printf "Detected latest stable Android Studio version: $version\n"
fi

# Construct the download URL
ANDROID_STUDIO_URL="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/$version/android-studio-$version-linux.tar.gz"
ANDROID_STUDIO_FILE="$TEMP_DIR/android_studio.tar.gz"

# Verify URL exists
if curl --output /dev/null --silent --head --fail "$ANDROID_STUDIO_URL"; then
    printf "Found valid Android Studio download link: $ANDROID_STUDIO_URL\n"
else
    printf "Failed to find downloadable Android Studio link. Abort.\n"
    exit 1
fi

printf "\n[2/4] Finding latest Flutter SDK version for Linux...\n"

# Get Flutter SDK URL
FLUTTER_MANIFEST_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
FLUTTER_JSON="$TEMP_DIR/flutter_releases.json"
curl -s "$FLUTTER_MANIFEST_URL" -o "$FLUTTER_JSON"

FLUTTER_URL=$(grep -A 10 '"channel": "stable"' "$FLUTTER_JSON" | grep 'archive' | head -1 | sed -E 's/.*"archive": "([^"]+)".*/https:\/\/storage.googleapis.com\/flutter_infra_release\/releases\/\1/')
FLUTTER_FILE="$TEMP_DIR/flutter_sdk.tar.xz"

if [ -z "$FLUTTER_URL" ]; then
    printf "Failed to get the latest Flutter SDK download link. Abort.\n"
    exit 1
fi

printf "Found Flutter SDK download link: $FLUTTER_URL\n"

# Ask user for confirmation
printf "\nReady to download and install:"
printf "\n - Android Studio $version"
printf "\n - Flutter SDK (latest stable)\n"
read -p "Do you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "Aborted.\n"
    exit 0
fi

# Download phase
printf "\n[3/4] Downloading packages...\n"

printf "Downloading Android Studio ($version)...\n"
wget -O "$ANDROID_STUDIO_FILE" "$ANDROID_STUDIO_URL" -q --show-progress

printf "Downloading Flutter SDK...\n"
wget -O "$FLUTTER_FILE" "$FLUTTER_URL" -q --show-progress

# Installation phase
printf "\n[4/4] Installing packages...\n"

# Install Android Studio
printf "Installing Android Studio...\n"
mkdir -p "$ANDROID_STUDIO_DIR"
printf "Extracting Android Studio archive to $ANDROID_STUDIO_DIR...\n"
tar -xzf "$ANDROID_STUDIO_FILE" -C "$ANDROID_STUDIO_DIR" --strip-components=1
launcher="$ANDROID_STUDIO_DIR/bin/studio.sh"
chmod +x "$launcher"

printf "\nAndroid Studio has been installed.\n"
printf "You can start it with: $launcher\n\n"

# Install Flutter SDK
printf "Installing Flutter SDK...\n"
mkdir -p "$FLUTTER_DIR"
printf "Extracting Flutter SDK archive to $FLUTTER_DIR...\n"
tar -xf "$FLUTTER_FILE" -C "$FLUTTER_DIR" --strip-components=1

# Add flutter to PATH for current session
export PATH="$FLUTTER_DIR/bin:$PATH"
printf "\n[INFO] Flutter SDK installed at $FLUTTER_DIR\n"
printf "[INFO] Added Flutter to PATH for this session.\n"
printf "[INFO] To make it permanent, add this line to your ~/.bashrc or ~/.zshrc:\n"
printf 'export PATH="$FLUTTER_DIR/bin:$PATH"\n\n'

# Launch Android Studio first time setup if requested
read -p "Would you like to run Android Studio first-time setup now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    printf "Launching Android Studio. Please complete the setup wizard.\n"
    "$launcher" &
    
    # Wait for user to indicate they're done with Android Studio setup
    read -p "Press Enter after you have completed Android Studio setup and closed it..." -r
fi

# Run Flutter doctor if requested
read -p "Would you like to run Flutter doctor now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    printf "Running 'flutter doctor'...\n"
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
    printf "Cleaning up temporary files...\n"
    rm -f "$ANDROID_STUDIO_FILE"
    rm -f "$FLUTTER_FILE"
    rm -f "$main_html"
    rm -f "$FLUTTER_JSON"
fi

printf "\n========================================================"
printf "\nSetup complete! Android development environment is ready."
printf "\n========================================================\n\n"