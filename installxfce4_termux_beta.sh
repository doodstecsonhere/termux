#!/bin/bash

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# --- Configuration Variables ---
readonly DOTFILES_REPO_DEFAULT="termux-dotfiles"
readonly BACKUP_DIR_NAME="config_backup"
readonly TEMP_DIR="/data/data/com.termux/files/usr/tmp/xfce4_install_$$"
readonly LOG_FILE="$TEMP_DIR/install_log.txt"
readonly SCRIPT_VERSION="1.1.0"

# Arrays of configuration
readonly CONFIG_DIRS_TO_SYNC=(
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

readonly PACKAGES_REQUIRED=(
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
    # Added new useful packages
    "htop"
    "neofetch"
    "nano"
    "vim"
    "tmux"
    "zsh"
    "oh-my-zsh"
    "powerline-fonts"
)

readonly RSYNC_EXCLUDE_PATTERNS=(
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
    # Added new excludes
    "*.swp"
    "*.swo"
    "node_modules"
    "__pycache__"
    "*.pyc"
    ".git"
    ".svn"
    ".idea"
    ".vscode"
)

# --- Color definitions ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# --- Functions ---
setup_logging() {
    mkdir -p "$TEMP_DIR"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    chmod 600 "$LOG_FILE"
}

cleanup() {
    local exit_code=$?
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    if [ $exit_code -ne 0 ]; then
        log "Installation failed. Check the log file at $LOG_FILE for details."
    fi
}

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp]${NC} - $1"
}

error() {
    log "${RED}ERROR: $1${NC}" >&2
    return 1
}

warning() {
    log "${YELLOW}WARNING: $1${NC}" >&2
}

success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

is_package_installed() {
    pkg list-installed "$1" > /dev/null 2>&1
}

check_requirements() {
    log "Checking system requirements..."
    
    # Check if running in Termux
    if [ ! -d "/data/data/com.termux" ]; then
        error "This script must be run in Termux"
        exit 1
    }

    # Check available storage
    local available_space=$(df -P /data | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1000000 ]; then # 1GB minimum
        error "Insufficient storage space. At least 1GB required"
        exit 1
    }

    # Check internet connectivity
    if ! ping -c 1 github.com >/dev/null 2>&1; then
        error "No internet connection detected"
        exit 1
    }
}

verify_github_credentials() {
    local username="$1"
    local email="$2"
    
    # Validate email format
    if ! echo "$email" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
        error "Invalid email format"
        return 1
    }

    # Validate GitHub username format
    if ! echo "$username" | grep -qE '^[a-zA-Z0-9][-a-zA-Z0-9]*$'; then
        error "Invalid GitHub username format"
        return 1
    }
}

sync_configs() {
    local source="$1"
    local dest="$2"
    
    local exclude_opts=()
    for pattern in "${RSYNC_EXCLUDE_PATTERNS[@]}"; do
        exclude_opts+=(--exclude "$pattern")
    done

    if [ -d "$source" ]; then
        if [ -n "$(ls -A "$source" 2>/dev/null)" ]; then
            log "Syncing directory: $source to $dest"
            rsync -av --delete "${exclude_opts[@]}" "$source/" "$dest/" || {
                error "Failed to sync $source to $dest"
                return 1
            }
        else
            warning "Directory '$source' is empty. Skipping sync."
        fi
    elif [ -f "$source" ]; then
        log "Syncing file: $source to $dest"
        rsync -av "$source" "$dest" || {
            error "Failed to sync $source to $dest"
            return 1
        }
    else
        warning "Source path '$source' does not exist. Skipping sync."
    fi
}

install_packages() {
    local package="$1"
    local retries=3
    local wait_time=5

    for ((i=1; i<=retries; i++)); do
        if pkg install -y "$package" 2>/dev/null; then
            success "Package '$package' installed successfully"
            return 0
        else
            if [ $i -lt $retries ]; then
                warning "Failed to install '$package'. Attempt $i of $retries. Retrying in ${wait_time}s..."
                sleep $wait_time
                # Increase wait time for next attempt
                wait_time=$((wait_time * 2))
            else
                error "Failed to install '$package' after $retries attempts"
                return 1
            fi
        fi
    done
}

setup_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "Setting up Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

        # Install powerlevel10k theme
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

        # Set ZSH as default shell
        chsh -s zsh
    fi
}

create_desktop_shortcuts() {
    local desktop_dir="$HOME/Desktop"
    mkdir -p "$desktop_dir"

    # Create Terminal shortcut
    cat > "$desktop_dir/Terminal.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=Start Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;
EOF

    # Create File Manager shortcut
    cat > "$desktop_dir/FileManager.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=File Manager
Comment=Browse Files
Exec=thunar
Icon=system-file-manager
Terminal=false
Categories=System;FileTools;FileManager;
EOF

    chmod +x "$desktop_dir"/*.desktop
}

setup_git_config() {
    local username="$1"
    local email="$2"

    log "Configuring Git..."
    git config --global user.name "$username"
    git config --global user.email "$email"
    git config --global init.defaultBranch main
    git config --global core.editor nano
    git config --global pull.rebase false
    git config --global color.ui auto
}

# --- Main Script ---
main() {
    trap cleanup EXIT
    setup_logging

    # Show welcome banner
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║     XFCE4 Termux Installation Script       ║"
    echo "║              Version $SCRIPT_VERSION                ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Check requirements
    check_requirements

    # Get user input with validation
    while true; do
        read -p "Enter your GitHub username: " GITHUB_USERNAME
        read -p "Enter your GitHub email: " GITHUB_EMAIL
        if verify_github_credentials "$GITHUB_USERNAME" "$GITHUB_EMAIL"; then
            break
        fi
    done

    read -p "Enter your dotfiles repository name (default: $DOTFILES_REPO_DEFAULT): " DOTFILES_REPO_INPUT
    DOTFILES_REPO="${DOTFILES_REPO_INPUT:-$DOTFILES_REPO_DEFAULT}"

    # Request storage permission
    log "Requesting Termux storage permission..."
    termux-setup-storage || error "Failed to get storage permission"

    # Update package lists with progress
    log "Updating package lists..."
    pkg update -y && pkg upgrade -y

    # Install packages with progress bar
    local total_packages=${#PACKAGES_REQUIRED[@]}
    local current_package=0

    for package in "${PACKAGES_REQUIRED[@]}"; do
        ((current_package++))
        echo -ne "Installing packages: [${current_package}/${total_packages}] ${package}...\r"
        
        if ! is_package_installed "$package"; then
            if ! install_packages "$package"; then
                error "Failed to install required packages"
                exit 1
            fi
        fi
    done
    echo # New line after progress

    # Set up Git and SSH
    setup_git_config "$GITHUB_USERNAME" "$GITHUB_EMAIL"

    # Set up SSH key if needed
    if [ ! -f ~/.ssh/id_rsa ]; then
        log "Generating SSH key..."
        ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f ~/.ssh/id_rsa -N ""
        
        log "Here is your public SSH key:"
        cat ~/.ssh/id_rsa.pub
        
        if command -v termux-open &>/dev/null; then
            termux-open "https://github.com/settings/keys"
        fi
    fi

    # Set up dotfiles repository
    DOTFILES_DIR=~/"$DOTFILES_REPO"
    BACKUP_DIR="$DOTFILES_DIR/$BACKUP_DIR_NAME"

    if [ ! -d "$DOTFILES_DIR" ]; then
        log "Creating new dotfiles repository..."
        mkdir -p "$DOTFILES_DIR"
        cd "$DOTFILES_DIR"
        git init
        git remote add origin "git@github.com:$GITHUB_USERNAME/$DOTFILES_REPO.git"
        
        # Create initial structure
        mkdir -p "$BACKUP_DIR"
        echo "# Termux Dotfiles" > README.md
        echo "Created on $(date)" >> README.md
        git add .
        git commit -m "Initial dotfiles setup"
        git branch -M main
        git push -u origin main || warning "Initial push failed. Will retry later."
    fi

    # Sync configurations
    log "Syncing configurations..."
    for config_dir in "${CONFIG_DIRS_TO_SYNC[@]}"; do
        sync_configs ~/"$config_dir" "$BACKUP_DIR/$config_dir"
    done

    # Set up ZSH
    setup_zsh

    # Create desktop shortcuts
    create_desktop_shortcuts

    # Final setup
    log "Setting up XFCE startup script..."
    wget -q https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/startxfce4_termux.sh
    chmod +x startxfce4_termux.sh

    # Create successful installation marker
    touch "$HOME/.xfce4_installed"

    success "Installation completed successfully!"
    echo
    echo "To start XFCE4:"
    echo "1. Run: ./startxfce4_termux.sh"
    echo "2. If using Oh My Zsh, restart your terminal and run: p10k configure"
    echo
    echo "Installation log saved to: $LOG_FILE"
}

# Execute main function
main "$@"
