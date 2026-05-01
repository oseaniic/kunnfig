#!/bin/bash

sudo pacman -Sy --needed --noconfirm ark linux-headers polkit-kde-agent dunst pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse gst-plugin-pipewire wireplumber network-manager-applet bluez bluez-utils blueman brightnessctl qt5-wayland qt6-wayland cpupower celluloid ttf-roboto exa wget ttf-meslo-nerd ttf-font-awesome ttf-hack kitty kwrite firefox powertop sddm dolphin hyprlauncher git hyprland ntfs-3g os-prober unrar unzip zip waybar


git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm

yay -Sy --noconfirm webcord

sudo systemctl enable --now sddm
