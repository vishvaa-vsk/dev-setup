# Fedora Dev + Hyprland Setup

This repository provides an automated script to set up a development environment and Hyprland desktop on Fedora (tested on Fedora 42+).

## Features

- Installs core developer tools (git, curl, gcc, Python, Node.js, etc.)
- Sets up VS Code and Brave browser
- Installs Docker (with Fedora 42/dnf5 compatibility)
- Enables system optimizations (preload, fstrim, ZRAM)
- Optionally installs Hyprland with JaKooLit dotfiles

## Usage

**⚠️ Run as root or with sudo. The script will prompt for confirmation before making changes.**

### One-liner install

```bash
sh <(curl -L https://raw.githubusercontent.com/vishvaa-vsk/dev-setup/main/setup.sh)
```

Or, if you want to review the script first:

```bash
curl -O https://raw.githubusercontent.com/vishvaa-vsk/dev-setup/main/setup.sh
chmod +x setup.sh
sudo bash setup.sh
```

## What the script does

- Updates your system
- Installs essential developer tools
- Sets up VS Code and Brave browser repositories
- Installs Node.js LTS via NVM
- Installs Python 3 and OpenJDK 21 (optional)
- Installs Docker and adds your user to the docker group (optional)
- Enables system performance tweaks
- Sets up ZRAM swap
- Optionally installs Hyprland with JaKooLit dotfiles

## Notes

- **Reboot is recommended after running the script.**
- For Docker, you may need to log out and log back in for group changes to take effect.
- The script is intended for Fedora 42+ and assumes a fresh or clean system.

---

Feel free to fork or modify for your own setup!
