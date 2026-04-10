#!/bin/sh
#
# Bootstrap script for artix-installer
# Clones the repo and runs the installer

set -e

REPO_URL="https://github.com/dim-ghub/artix-installer.git"
CLONE_DIR="artix-installer"

printf "Cloning artix-installer...\n"
sudo pacman -Sy --needed --noconfirm git
git clone --depth=1 "$REPO_URL" "$CLONE_DIR"
cd "$CLONE_DIR"
printf "Run ./install.sh"
