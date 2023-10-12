#!/bin/bash

sudo pacman -Sy ark linux-headers polkit-kde-agent dunst pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse gst-plugin-pipewire wireplumber network-manager-applet bluez bluez-utils blueman brightnessctl qt5-wayland qt6-wayland cpupower celluloid evince libreoffice-fresh ttf-roboto zsh exa wget ttf-meslo-nerd ttf-font-awesome ttf-hack kitty kate firefox powertop sddm dolphin


git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm

yay -Sy --noconfirm hyprland-git xdg-desktop-portal-hyprland-git waybar-hyprland-git rofi-lbonn-wayland-git visual-studio-code-bin whatsapp-for-linux 

wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
sudo chmod +x install.sh
sh install.sh

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k ; \
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ; \
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ; \
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search

source ~/.zshrc

sudo systemctl enable --now sddm
