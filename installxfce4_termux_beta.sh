#!/bin/bash

# Exit on error
set -e

# GitHub configuration
GITHUB_TOKEN="YOUR_GITHUB_TOKEN_HERE"  # <-- Replace this with your new token
GITHUB_USERNAME="doodstecsonhere"
GITHUB_EMAIL="emmanuel.tecson@gmail.com"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Verify GitHub token
log "Verifying GitHub token..."
curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user > /dev/null || {
    log "Error: Invalid GitHub token. Please check the token value."
    exit 1
}

# Configure git with token
git config --global user.name "$GITHUB_USERNAME"
git config --global user.email "$GITHUB_EMAIL"
git config --global credential.helper store
echo "https://$GITHUB_TOKEN:x-oauth-basic@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials

# Request storage permission
log "Requesting Termux storage permission..."
termux-setup-storage || { log "Failed to get storage permission"; exit 1; }

# Update package lists and install required packages
log "Installing required packages..."
pkg update -y && pkg upgrade -y
pkg install -y x11-repo tur-repo || exit 1
pkg install -y \
    termux-x11-nightly \
    pulseaudio \
    git \
    wget \
    rsync \
    xfce4 \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    xfce4-panel \
    xfce4-settings \
    xfce4-session \
    firefox \
    chromium \
    fluent-gtk-theme \
    fluent-icon-theme || exit 1

# Set up dotfiles repository
DOTFILES_DIR=~/dotfiles
BACKUP_DIR="$DOTFILES_DIR/config_backup"

# Initialize or update dotfiles repository
if [ ! -d "$DOTFILES_DIR" ]; then
    log "Creating new dotfiles repository..."
    mkdir -p "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
    git init
    git remote add origin "https://github.com/$GITHUB_USERNAME/dotfiles.git"
    mkdir -p config_backup/{xfce4,firefox,chromium,.themes,.icons,fonts}
    echo "# Termux Dotfiles" > README.md
    echo "Created on $(date)" >> README.md
    git add .
    git commit -m "Initial dotfiles setup"
    git branch -M main
    git push -u origin main || log "Warning: Initial push failed. Will try later."
fi

# Create local config directories
mkdir -p ~/.config/xfce4 \
    ~/.mozilla/firefox \
    ~/.config/chromium \
    ~/.themes \
    ~/.icons \
    ~/.local/share/fonts

# Function to sync configs between dotfiles and home
sync_configs() {
    local source=$1
    local dest=$2
    
    if [ -d "$source" ] && [ "$(ls -A $source)" ]; then
        rsync -av --delete "$source/" "$dest/"
    fi
}

# Initial config sync
if [ "$(ls -A $BACKUP_DIR/xfce4 2>/dev/null)" ]; then
    log "Syncing existing configs from dotfiles..."
    sync_configs "$BACKUP_DIR/xfce4" ~/.config/xfce4
    sync_configs "$BACKUP_DIR/firefox" ~/.mozilla/firefox
    sync_configs "$BACKUP_DIR/chromium" ~/.config/chromium
    sync_configs "$BACKUP_DIR/.themes" ~/.themes
    sync_configs "$BACKUP_DIR/.icons" ~/.icons
    sync_configs "$BACKUP_DIR/fonts" ~/.local/share/fonts
else
    log "No existing configs found. Will sync current configs if they exist."
fi

# Add sync on exit to .bashrc
if ! grep -q "sync_configs_and_backup" ~/.bashrc; then
    cat << 'EOF' >> ~/.bashrc

# Sync configs and backup on exit
sync_configs_and_backup() {
    if [ -d ~/dotfiles ]; then
        cd ~/dotfiles
        rsync -av --delete ~/.config/xfce4/ config_backup/xfce4/
        git add .
        git commit -m "Auto-backup: $(date +'%Y-%m-%d %H:%M:%S')" || true
        git push origin main || true
    fi
}
trap sync_configs_and_backup EXIT
EOF
fi

# Set up XFCE desktop files
log "Setting up XFCE desktop files..."
cd ~
wget https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/startxfce4_termux.sh
chmod +x startxfce4_termux.sh

mkdir -p ~/Desktop
wget -P ~/Desktop https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/Shutdown.desktop

log "Setup complete! Starting XFCE..."
./startxfce4_termux.sh
