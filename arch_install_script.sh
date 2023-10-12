#!/bin/bash
clear
echo "Welcome to Osean's Arch Install Script"
# Check for network connectivity
if ! ping -q -c 1 google.com &>/dev/null; then
    echo "Error: No network connectivity. Please ensure you have an active internet connection."
    exit 1
fi
echo "Only run this script after creating at least 3 partitions in your desired drive with cfdisk and lsblk"
echo ""
echo "System Partitions:"
lsblk
echo ""
echo "Choose main drive/disk and 3 partitions to install arch files in:"
echo "Type the partition to install the EFI files in (should be 100MB - 300MB in size):"
read input_efi
echo "Type the partition to install the SWAP files in (4GB or 8GB):"
read input_swap
echo "Type the partition to install the Filesystem files in (rest of the drive space):"
read input_filesystem

echo "Type the parent drive of the partitions to use"
read input_parent

echo "Enter a name for the system"
read input_systemname

echo "Create a username (must be all lowercase and no special characters)"
read input_username
echo "Create a password for the username (same rules apply)"
read -s input_password

# Check if the user's choices are valid partitions
if [ ! -b "/dev/$input_efi" ] || [ ! -b "/dev/$input_swap" ] || [ ! -b "/dev/$input_filesystem" ]; then
    echo "Invalid partition(s) selected. Please choose valid partitions."
    exit 1
fi

# Display a summary of the user's choices
echo ""
echo "Summary of Choices:"
echo "EFI Partition: $input_efi"
echo "SWAP Partition: $input_swap"
echo "Filesystem Partition: $input_filesystem"

# Ask for deletion confirmation
echo "All data in the selected partitions will be DESTROYED. Proceed? (y or n)"
read confirmation
if [ "$confirmation" = "n" ]; then
    echo "Installation aborted."
    exit 1
elif [ "$confirmation" != "y" ]; then
    echo "Invalid input. Please enter 'y' to proceed or 'n' to quit."
    exit 1
fi

echo "Formating..."
mkfs.ext4 "/dev/$input_filesystem"
mkfs.fat -F 32 "/dev/$input_efi"
mkswap "/dev/$input_swap"

echo "Mounting drives..."
mount "/dev/$input_filesystem" /mnt
mkdir -p /mnt/boot/efi
mount "/dev/$input_efi" /mnt/boot/efi
swapon "/dev/$input_swap"

echo ""
echo "Final disk setup"
lsblk

echo ""
echo "Pac strapping.."

pacstrap /mnt base linux linux-firmware sof-firmware base-devel git grub efibootmgr nano networkmanager
genfstab /mnt > /mnt/etc/fstab

# Create the secondary script
cat <<EOF > /mnt/install_pt2.sh
#!/bin/bash
echo ""
echo "Creating locales, times and system name.."

ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
hwclock --systohc
nano /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$input_systemname" > /etc/hostname

echo ""
echo "Creating user and Visudoing.."

passwd -l root
useradd -m -G wheel -s /bin/bash "$input_username"
echo "$input_username:$input_password" | chpasswd
EDITOR=nano visudo

echo ""
echo "Installing grub.."

grub-install "/dev/$input_parent"
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo "Launching nano for you to enable multilib.."

nano /etc/pacman.conf

echo "done!!!"
EOF

# Make the secondary script executable
chmod +x /mnt/install_pt2.sh

# Enter the chroot environment
arch-chroot /mnt /bin/bash -c "/install_pt2.sh"

echo "DONEEE"
