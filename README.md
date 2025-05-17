# Fedora Dev + Hyprland Setup

This repository provides an automated script to set up a development environment and Hyprland desktop on Fedora Workstation (tested on Fedora 42+). Works well on a minimal install too (Fedora everything).

## Features

- Installs core developer tools (git, curl, gcc, Python, Node.js, etc.)
- Sets up VS Code and Brave browser
- Installs Docker (with Fedora 42/dnf5 compatibility)
- Enables system optimizations (preload, fstrim, ZRAM)
- Optionally installs Hyprland with custom dotfiles
- Modular setup for Android, Node.js, and Python development environments

## Usage

**⚠️ This script must be run with sudo privileges.**

### One-liner install (complete setup)

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/vishvaa-vsk/dev-setup/main/bootstrap-simple.sh)"
```

This one-liner downloads all necessary scripts (main script + modules) and runs the complete setup.

Alternatively, if you encounter any issues with the above command, you can try:

```bash
curl -fsSL https://raw.githubusercontent.com/vishvaa-vsk/dev-setup/main/bootstrap-simple.sh -o ~/bootstrap-simple.sh && chmod +x ~/bootstrap-simple.sh && sudo ~/bootstrap-simple.sh
```

### Manual install

If you want to review the scripts first:

```bash
# Clone the repository
git clone https://github.com/vishvaa-vsk/dev-setup.git
cd dev-setup

# Make scripts executable
chmod +x setup.sh setup_android_dev.sh setup_node_dev.sh setup_python_dev.sh

# Run the setup
sudo bash setup.sh
```

## What the script does

- Updates your system
- Installs essential developer tools
- Sets up VS Code and Brave browser repositories
- Modular development environment setup:
  - Node.js: Installs NVM with npm and yarn (via `setup_node_dev.sh`)
  - Python: Sets up system Python with pyenv for version management (via `setup_python_dev.sh`)
  - Android: Downloads and installs Android Studio & Flutter SDK (via `setup_android_dev.sh`, optional)
- Installs OpenJDK 21 (optional)
- Sets up Docker with legacy `docker-compose` command support
- Enables system performance tweaks
- Sets up ZRAM swap
- Optionally installs Hyprland with custom dotfiles

## Notes

- **Reboot is recommended after running the script.**
- For Docker, you may need to log out and log back in for group changes to take effect.
- The script is intended for Fedora 42+ and assumes a fresh or clean system.

---

Feel free to fork or modify for your own setup!
