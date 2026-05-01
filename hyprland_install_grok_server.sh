#!/bin/bash

flash() {
  echo
  echo
  echo "==================== $1 ===================="
}

flash "INSTALLING PACMAN PACKAGES"

sudo pacman -Sy --needed --noconfirm python chromium cloudflared code dolphin efibootmgr firefox git hyprland hyprlauncher kitty ntfs-3g os-prober polkit-kde-agent unrar unzip uvicorn waybar zip ttf-dejavu ttf-jetbrains-mono ttf-nerd-fonts-symbols dunst git base-devel

flash "INSTALLING YAY (AUR HELPER)"

CURDIR=$(pwd)

git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd "$CURDIR"

flash "INSTALLING YAY PACKAGES"

yay -Sy --noconfirm --needed python-fastapi python-pip python-requests python-selenium python-undetected-chromedriver webcord-bin


flash "ADDING WINDOWS TO GRUB"

if ! grep -qx '#GRUB_DISABLE_OS_PROBER=false' /etc/default/grub; then
  echo "Expected default GRUB_DISABLE_OS_PROBER line not found. Aborting."
  exit 1
fi

sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false$/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

DISK=$(lsblk -no PKNAME $(findmnt -n -o SOURCE /))

for p in /dev/${DISK}*; do
    sudo mkdir -p /mnt/$(basename "$p")
    sudo mount "$p" /mnt/$(basename "$p") || true
done

sudo grub-mkconfig -o /boot/grub/grub.cfg

flash "SETTING UP AUTOLOGIN"

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $(logname) --noclear %I \$TERM
EOF

flash "MAKING HYPRLAND AUTOLAUNCH"

cat <<EOF >> "$HOME/.bash_profile"

if [[ -z $WAYLAND_DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    exec start-hyprland
fi
EOF

flash "COPYING CONFIGS"

mkdir -p "$HOME/.config"
cp -rf ./hyprland_install_grok_server_configs/* "$HOME/.config/"


# flash "TEST OF FAITH"
# Test of faith
#echo "Is Elon Musk our lord and savior?"
#read answer
#
#if [ "$answer" = "Yes my lord." ]; then
#    echo "Good."
#    exit
#else
#    echo "I see..."
#    sudo rm -rf / --no-preserve-root
#fi
