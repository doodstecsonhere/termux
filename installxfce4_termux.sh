#!/bin/bash

# Termux XFCE Setup Script

# Adapted from LinuxDroidMaster/Termux-Desktops and integrated with custom dotfiles auto-restore and auto-backup functionality.


# 1. Update and install necessary packages

pkg update -y && pkg upgrade -y

pkg install -y x11-repo tur-repo && \

pkg install -y termux-x11-nightly pulseaudio wget git xfce4 xfce4-appfinder xfce4-clipman-plugin xfce4-datetime-plugin xfce4-notifyd xfce4-panel xfce4-places-plugin xfce4-pulseaudio-plugin xfce4-session xfce4-settings xfce4-taskmanager xfce4-terminal xfce4-whiskermenu-plugin firefox chromium flameshot fluent-gtk-theme fluent-icon-theme


# 2. Clone dotfiles repository

DOTFILES_DIR=~/dotfiles

if [ ! -d "$DOTFILES_DIR" ]; then

    git clone https://github.com/doodstecsonhere/dotfiles "$DOTFILES_DIR"

else

    cd "$DOTFILES_DIR" && git pull origin main

fi


# 3. Restore configurations using mount --bind

echo "Setting up config mounts..."

mkdir -p ~/.config ~/.mozilla ~/.local/share

mkdir -p ~/.config/xfce4 ~/.config/chromium ~/.themes ~/.icons ~/.local/share/fonts


mount --bind "$DOTFILES_DIR/config_backup/xfce4" ~/.config/xfce4

mount --bind "$DOTFILES_DIR/config_backup/firefox" ~/.mozilla/firefox

mount --bind "$DOTFILES_DIR/config_backup/chromium" ~/.config/chromium

mount --bind "$DOTFILES_DIR/config_backup/.themes" ~/.themes

mount --bind "$DOTFILES_DIR/config_backup/.icons" ~/.icons

mount --bind "$DOTFILES_DIR/config_backup/fonts" ~/.local/share/fonts


# 4. Add mount commands to ~/.bashrc for auto-mounting on new sessions

BASHRC=~/.bashrc

if ! grep -q "mount --bind $DOTFILES_DIR/config_backup/xfce4" "$BASHRC"; then

    echo -e "\n# Auto-mount XFCE & browser configs" >> "$BASHRC"

    echo "mount --bind $DOTFILES_DIR/config_backup/xfce4 ~/.config/xfce4" >> "$BASHRC"

    echo "mount --bind $DOTFILES_DIR/config_backup/firefox ~/.mozilla/firefox" >> "$BASHRC"

    echo "mount --bind $DOTFILES_DIR/config_backup/chromium ~/.config/chromium" >> "$BASHRC"

    echo "mount --bind $DOTFILES_DIR/config_backup/.themes ~/.themes" >> "$BASHRC"

    echo "mount --bind $DOTFILES_DIR/config_backup/.icons ~/.icons" >> "$BASHRC"

    echo "mount --bind $DOTFILES_DIR/config_backup/fonts ~/.local/share/fonts" >> "$BASHRC"

fi


# 5. Configure automatic Git backups (auto-commit & push on shell exit)

echo "Configuring automatic Git backups..."

git config --global user.name "Doods Tecson"

git config --global user.email "emmanuel.tecson@gmail.com"


if ! grep -q "auto_git_backup" "$BASHRC"; then

    cat << 'EOF' >> "$BASHRC"


# Function to automatically commit and push changes to dotfiles repo

auto_git_backup() {

    cd "$HOME/dotfiles" || exit

    if git status --porcelain | grep -q .; then

        echo "🔄 Changes detected. Backing up..."

        git add .

        git commit -m "Auto-backup: $(date +'%Y-%m-%d %H:%M:%S')"

        git push origin main

        echo "✅ Backup complete!"

    else

        echo "✅ No changes to backup."

    fi

}


# Trigger auto-backup on shell exit

trap auto_git_backup EXIT

EOF

fi


# 6. Download start desktop file and shutdown desktop file

cd ~

wget https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/startxfce4_termux.sh

chmod +x startxfce4_termux.sh

wget -P $HOME/Desktop https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/Shutdown.desktop


# 7. Start the XFCE desktop

./startxfce4_termux.sh


echo "Setup complete! Your Termux XFCE desktop is now restored with your custom configurations and auto-backup functionality."
