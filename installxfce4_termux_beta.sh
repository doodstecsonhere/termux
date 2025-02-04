#!/bin/bash

# Exit on error
set -e

# --- Configuration Variables ---
DOTFILES_REPO_DEFAULT="termux-dotfiles"
BACKUP_DIR_NAME="config_backup"
CONFIG_DIRS_TO_SYNC=(
    ".bashrc"
    ".zshrc"
    ".profile"
    ".config"
    ".config/xfce4"
    ".mozilla"
    ".config/chromium"
    ".themes"
    ".icons"
    ".fonts"
    ".local/share/fonts"
    ".gtkrc-2.0"
    ".gtkrc-2.0-mine"
    ".Xresources"
    ".xinitrc"
    ".xprofile"
    ".dunst"
    ".i3"
    ".rofi"
    ".tmux.conf"
    ".vimrc"
    ".gitconfig"
    ".ssh"
)
PACKAGES_REQUIRED=(
    "x11-repo"
    "tur-repo"
    "termux-x11-nightly"
    "pulseaudio"
    "git"
    "wget"
    "rsync"
    "xfce4"
    "xfce4-terminal"
    "xfce4-whiskermenu-plugin"
    "xfce4-panel"
    "xfce4-settings"
    "xfce4-session"
    "firefox"
    "chromium"
    "fluent-gtk-theme"
    "fluent-icon-theme"
)
RSYNC_EXCLUDE_PATTERNS=(
    "*/cache*"
    "*/Cache*"
    "*.cache"
    "*/.thumbnails"
    "*/Trash"
    "*/.mozilla/firefox/*/cache2"
    "*/.config/chromium/*/Cache"
    "*/tmp*"
    "*/temp*"
    "*.tmp"
    "*.temp"
    "*~"
    ".DS_Store"
    ".localized"
    ".Trash*"
)

# --- User Prompts ---
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Enter your GitHub email: " GITHUB_EMAIL
read -p "Enter your dotfiles repository name (default: $DOTFILES_REPO_DEFAULT): " DOTFILES_REPO_INPUT
DOTFILES_REPO="${DOTFILES_REPO_INPUT:-$DOTFILES_REPO_DEFAULT}"

# --- Functions ---
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

is_package_installed() {
    pkg list-installed "$1" > /dev/null 2>&1
    return $?
}

sync_configs() {
    local source="$1"
    local dest="$2"
    local exclude_options=""

    for pattern in "${RSYNC_EXCLUDE_PATTERNS[@]}"; do
        exclude_options+="--exclude '$pattern' "
    done

    if [ -d "$source" ]; then
        local ls_output="`ls -A \"$source\" 2>/dev/null`"
        if [ -n "$ls_output" ]; then
            log "Syncing directory: $source to $dest (excluding cache and temp files)"
            rsync -av --delete "$exclude_options" "$source/" "$dest/"
        else
            log "Directory '$source' is empty. Skipping sync."
        fi
    elif [ -f "$source" ]; then
        log "Syncing file: $source to $dest"
        rsync -av "$source" "$dest"
    else
        log "Warning: Source path '$source' does not exist. Skipping sync."
    fi
}

# --- Termux Setup ---
log "Requesting Termux storage permission..."
termux-setup-storage || { log "Failed to get storage permission"; exit 1; }

# --- Package Installation ---
log "Updating package lists..."
pkg update -y && pkg upgrade -y

log "Installing required repositories and packages..."

if ! is_package_installed "x11-repo"; then
    log "Installing package: x11-repo"
    pkg install -y x11-repo || exit 1
else
    log "Package 'x11-repo' is already installed. Skipping."
fi

if ! is_package_installed "tur-repo"; then
    log "Installing package: tur-repo"
    pkg install -y tur-repo || exit 1
else
    log "Package 'tur-repo' is already installed. Skipping."
fi

for package in "${PACKAGES_REQUIRED[@]}"; do
    if [[ "$package" != "x11-repo" && "$package" != "tur-repo" ]]; then
        if ! is_package_installed "$package"; then
            log "Installing package: $package"
            pkg install -y "$package" || exit 1
        else
            log "Package '$package' is already installed. Skipping."
        fi
    fi
done

# --- Git Configuration ---
log "Setting up Git global configuration..."
git config --global user.name "$GITHUB_USERNAME"
git config --global user.email "$GITHUB_EMAIL"

# --- SSH Key Setup ---
if [ ! -f ~/.ssh/id_rsa ]; then
    log "No SSH key found. Generating a new one..."
    ssh-keygen -t rsa -b 4096 -C "$GITHUB_EMAIL" -f ~/.ssh/id_rsa -N ""

    log "SSH key generated. Here is your public key:"
    cat ~/.ssh/id_rsa.pub
    echo
    log "Please add the above key to your GitHub account at https://github.com/settings/keys"

    if command -v termux-open &> /dev/null; then
        termux-open "https://github.com/settings/keys"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "https://github.com/settings/keys"
    else
        log "Visit https://github.com/settings/keys in your browser to add the key."
    fi

    read -n 1 -s -r -p "Press Enter to continue after copying the SSH key..."
    echo ""

    while true; do
        read -p "Have you added the SSH key to your GitHub account? (y/n): " response
        case "$response" in
            [Yy]* ) break;;
            [Nn]* ) log "Please add the key and then enter 'y'."; sleep 2;;
            * ) log "Please answer yes (y) or no (n).";;
        esac
    done
fi

# Start SSH agent and add the key
log "Starting SSH agent and adding SSH key..."
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

# Verify SSH connection to GitHub
log "Testing GitHub SSH access..."
if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    log "Error: SSH authentication failed. Ensure your key is added to GitHub and SSH agent is running."
    exit 1
fi

# --- Dotfiles Repository Setup ---
DOTFILES_DIR=~/"$DOTFILES_REPO"
BACKUP_DIR="$DOTFILES_DIR/$BACKUP_DIR_NAME"

if [ ! -d "$DOTFILES_DIR" ]; then
    log "Creating new dotfiles repository in '$DOTFILES_DIR'..."
    mkdir -p "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
    git init
    git remote add origin "git@github.com:$GITHUB_USERNAME/$DOTFILES_REPO.git"
    mkdir -p "$BACKUP_DIR"
    for config_dir in "${CONFIG_DIRS_TO_SYNC[@]}"; do
        mkdir -p "$BACKUP_DIR/$config_dir"
    done
    echo "# Termux Dotfiles" > README.md
    echo "Created on $(date)" >> README.md
    git add .
    git commit -m "Initial dotfiles setup"
    git branch -M main
    git push -u origin main || log "Warning: Initial push of dotfiles failed. Check network and GitHub credentials. Will try again later."
elif [ ! -d "$DOTFILES_DIR/.git" ]; then
    log "Warning: Dotfiles directory '$DOTFILES_DIR' exists but is not a Git repository. Skipping Git initialization. If you intended to use this directory as your dotfiles repository, please ensure it's initialized as a Git repository (e.g., by running 'git init' inside it) and then re-run this script."
else
    log "Dotfiles repository already exists in '$DOTFILES_DIR'. Updating from remote..."
    cd "$DOTFILES_DIR"
    git pull origin main || log "Warning: Pulling latest dotfiles failed. Check network and GitHub credentials."
fi

# --- Create Local Config Directories ---
log "Creating local configuration directories if they don't exist..."
for config_dir_base in "${CONFIG_DIRS_TO_SYNC[@]}"; do
    if [[ "$config_dir_base" == */* || "$config_dir_base" == .*/* || "$config_dir_base" == ".config" || "$config_dir_base" == ".mozilla" || "$config_dir_base" == ".themes" || "$config_dir_base" == ".icons" || "$config_dir_base" == ".fonts" || "$config_dir_base" == ".local/share/fonts" ]]; then
        mkdir -p ~/"$config_dir_base"
    fi
done
mkdir -p ~/.config/xfce4
mkdir -p ~/.mozilla/firefox
mkdir -p ~/.config/chromium
mkdir -p ~/.themes
mkdir -p ~/.icons
mkdir -p ~/.local/share/fonts

# --- Initial Config Backup (Before Sync) ---
log "Backing up existing configurations to dotfiles repository (before initial sync)..."
for config_dir_base in "${CONFIG_DIRS_TO_SYNC[@]}"; do
    local source_config_path=~/"$config_dir_base"
    local backup_config_path="$BACKUP_DIR/$config_dir_base"

    if [ -d "$source_config_path" ] || [ -f "$source_config_path" ]; then
        log "Backing up: $source_config_path to $backup_config_path"
        sync_configs "$source_config_path" "$backup_config_path"
    else
        log "No existing configuration found at '$source_config_path'. Skipping backup for $config_dir_base."
    fi
done

# --- Initial Config Sync from Backup (if available) ---
if [ -n "`ls -A \"$BACKUP_DIR\" 2>/dev/null`" ]; then # Use -n to check for non-empty output
    log "Syncing configurations from dotfiles backup..."
    for config_dir_base in "${CONFIG_DIRS_TO_SYNC[@]}"; do
        local backup_config_path="$BACKUP_DIR/$config_dir_base"
        local dest_config_path=~/"$config_dir_base"
        sync_configs "$backup_config_path" "$dest_config_path"
    done
else
    log "No existing configurations found in dotfiles backup. Skipping initial sync from backup."
fi

# --- Set up Auto Config Sync and Backup on Exit ---
if ! grep -q "sync_configs_and_backup" ~/.bashrc; then
    log "Adding auto config sync and backup function to ~/.bashrc..."
    cat << "EOF" >> ~/.bashrc

sync_configs_and_backup() {
    if [ -d ~/dotfiles ]; then
        log "Auto-syncing and backing up configurations to dotfiles (excluding cache and temp files)..."
        cd ~/dotfiles
        for config_dir_base in "\${CONFIG_DIRS_TO_SYNC[@]}"; do # Escape $ for array in heredoc
            local source_config_path=~/"\$config_dir_base" # Escape $ for variable in heredoc
            local backup_config_path="./\$BACKUP_DIR_NAME/\$config_dir_base" # Escape $ for variables in heredoc
            if [ -d "\$source_config_path" ] || [ -f "\$source_config_path" ]; then # Escape $ for variables in heredoc
                sync_configs "\$source_config_path" "\$backup_config_path" # Escape $ for variables in heredoc
            fi
        done
        git add .
        git commit -m "Auto-backup: \$(date +'%Y-%m-%d %H:%M:%S')" || true # Escape $ for command substitution in heredoc
        git push origin main || log "Warning (Auto-sync): Push failed. Will try again later."
    fi
}
trap sync_configs_and_backup EXIT
EOF
else
    log "Auto config sync and backup already configured in ~/.bashrc. Skipping."
fi

# --- XFCE Desktop Files Setup ---
log "Setting up XFCE desktop files..."
cd ~
if ! [ -f startxfce4_termux.sh ]; then
    wget https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/startxfce4_termux.sh
    chmod +x startxfce4_termux.sh
    log "Downloaded and set execute permissions for startxfce4_termux.sh"
else
    log "startxfce4_termux.sh already exists. Skipping download."
fi

mkdir -p ~/Desktop
if ! [ -f ~/Desktop/Shutdown.desktop ]; then
    wget -P ~/Desktop https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/Shutdown.desktop
    log "Downloaded Shutdown.desktop to ~/Desktop"
else
    log "Shutdown.desktop already exists in ~/Desktop. Skipping download."
fi

# --- Setup Complete ---
log "Setup complete! Starting XFCE..."
log "You can start XFCE desktop by running: ./startxfce4_termux.sh"
echo " "
echo "Setup complete! You can start XFCE desktop by running: ./startxfce4_termux.sh"
echo " "
echo "Important: This script attempts to sync 'everything except cache files' based on common patterns."
echo "         Please review the CONFIG_DIRS_TO_SYNC and RSYNC_EXCLUDE_PATTERNS arrays at the"
echo "         beginning of the script to customize synced directories and excluded patterns."
echo "         Especially review RSYNC_EXCLUDE_PATTERNS and add more patterns if necessary to avoid"
echo "         syncing large or unwanted data. Be cautious syncing SSH private keys across untrusted systems."
