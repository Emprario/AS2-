#!/bin/bash
function echo_red()
{
echo -e "\E[0;31m$1"
}

function echo_green()
{
echo -e "\E[0;32m$1"
}

function echo_yellow()
{
echo -e "\E[1;33m$1"
}

echo_green "Welcome to arch-setup script!"

##Internet
echo_green "First let's connect to the internet"
echo "[Your are using iwctl]"
iwctl
ping -c 4 google.com

##Install utils
echo_green "Installing some packages ..."
pacman -Syy util-linux archlinux-keyring --noconfirm

##Configuring disks
echo_green "Here the actual state of the Disks"
fdisk -l
echo_yellow "Which should be erase to install archlinux?"
echo "[Example:/dev/nvme0n1]"
read -e disk

echo_yellow "Size of your swap"
echo "[In Gigabytes][Exemple:8]"
read -e swapsize


echo_yellow "Please confirm:"
echo "[Write 'I WILL EREASE THIS DISK']"
read -e
if [[ "$REPLY" != "I WILL EREASE THIS DISK" ]]; then
	echo_red "User did not confirm. Exiting"
	exit 1
fi

## Format $disk
( echo 'g';echo 'w')|fdisk $disk #Make as GPT

( echo 'n';echo '';echo '';echo '+512M';echo 'w')|fdisk $disk #Create EFI Partition
( echo 'n';echo '';echo '';echo "-${swapsize}G";echo 'w')|fdisk $disk #Create Root Partition
( echo 'n';echo '';echo '';echo '';echo 'w')|fdisk $disk #Create Swap partition

( echo 't';echo '1';echo '1';echo 'w')|fdisk $disk #Make the type of EFI 
( echo 't';echo '3';echo '19';echo 'w')|fdisk $disk #Make the type of swap

mkfs.fat -F 32 "${disk}p1"
mkfs.ext4 "${disk}p2"
mkswap "${disk}p3"
swapon

echo_green "Disk formated!"

echo_green "Installing the base system ..."
mount "${disk}p2" /mnt
pacstrap /mnt base linux linux-firmware grub efibootmgr nano --noconfirm
genfstab -U /mnt >> /mnt/etc/fstab
echo_green "Installed"

## Set up Locales
echo_green "Let's set up your locales"
echo_yellow "What timezone do you want to set up?"
echo "[Region/City]"
read -e tz

if [[ "$REPLY" != "" ]]; then
    ln -sf /usr/share/zoneinfo/$tz /mnt/etc/localtime
else
    echo_red "Empty answer pass."
fi

echo_yellow "Please uncomment your local"
echo_yellow "Save using CTRL+S then exit with CTRL+X"
echo "[Press space to continue]"
read
nano /mnt/etc/locale.gen
echo_yellow "Insert your locale you choose to uncomment"
echo "[Just one; Example:fr_FR.UTF-8]"
read language
echo LANG=$language > /mnt/etc/locale.conf

echo_yellow "Select your keyboard layout"
echo "[Example:'fr-latin1']"
ls /usr/share/kbd/keymaps/**/*.map.gz
read keyboard
echo "KEYMAP=${keyboard}">/mnt/etc/vconsole.conf

echo_yellow "Choose your hostname"
echo "[No space; No special character except '-']"
read hn
if [[ "$hn" != "" ]]; then
    echo $hn > /mnt/etc/hostname
else
    echo_red "Set vas default with 'EZKINIL'"
    hn=EZKINIL
    echo $hn > /mnt/etc/hostname
fi
echo "
127.0.0.1	localhost
::1		    localhost
127.0.1.1	${hn}
">/mnt/etc/hosts


##Finish installation with arch-chroot
echo_green "Proceed end installation using arch-chroot"
echo "
locale-gen
export "$(cat /mnt/etc/locale.conf)"
export "$(cat /mnt/etc/vconsole.conf)"
passwd
"|arch-chroot /mnt

echo_green "Install GRUB ..."
echo "
mkdir /boot/efi
mount "${disk}p1" /boot/efi
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
"|arch-chroot /mnt

echo_yellow "Do you want to increase security using another account"
echo_red "[HIGHLY RECOMMENDED]"
REPLY=""
while [[ "$REPLY" != "N" && "$REPLY" != "n" && "$REPLY" != "Y" && "$REPLY" != "y"  ]]
do
	read -e "Enter 'y' or 'n'"
	if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
		echo_yellow "Set up it ..."
        echo_yellow "Name of your account:"
        read accname
        #Set up by script
        echo "
        pacman -S sudo --noconfirm
        useradd -m "${accname}"
        passwd "${accname}"
        usermod -aG wheel,audio,video,storage "${accname}"
        "|arch-chroot /mnt
        echo_red "You will prompt to change the file of the sudoers please just uncomment THIS LINE:"
        echo_red "%wheel ALL=(ALL:ALL) ALL"
        echo_red "Then, Save using CTRL+S then exit with CTRL+X"
        echo "
        EDITOR=nano visudo
        "|arch-chroot /mnt
	else
		echo_yellow "Pass it ..."
	fi
done
umount -l /mnt
echo_green "You installed ArchLinux :)"
echo_green "Your device will reboot after you hit enter"
echo_green "Then after the reboot, you can connect with your account!"
read
reboot