# termux

# adapted from https://github.com/LinuxDroidMaster/Termux-Desktops

pkg update -y &&
pkg upgrade -y &&
pkg install -y 
x11-repo 
termux-x11-nightly
tur-repo
pulseaudio
wget
git
xfce4
xfce4-appfinder
xfce4-clipman-plugin
xfce4-datetime-plugin
xfce4-notifyd
xfce4-panel
xfce4-places-plugin
xfce4-pulseaudio-plugin
xfce4-session
xfce4-settings
xfce4-taskmanager
xfce4-terminal
xfce4-whiskermenu-plugin
firefox
chromium
flameshot
fluent-gtk-theme
fluent-icon-theme
&&

# get start desktop file

cd ~
wget https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/startxfce4_termux.sh

# change permissions for start desktop file

chmod +x startxfce4_termux.sh

# get shutdown desktop file

wget -P $HOME/Desktop https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/termux_native/Shutdown.desktop

# start desktop

./startxfce4_termux.sh
