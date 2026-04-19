#!/bin/sh -e
#
# A simple installer for Artix Linux
#
# Copyright (c) 2022 Maxwell Anderson
#
# This file is part of artix-installer.
#
# artix-installer is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# artix-installer is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with artix-installer. If not, see <https://www.gnu.org/licenses/>.

# Boring stuff you should probably do
ln -sf /usr/share/zoneinfo/"$REGION_CITY" /etc/localtime
hwclock --systohc

# Localization
printf "%s.UTF-8 UTF-8\n" "$LANGCODE" >>/etc/locale.gen
locale-gen
printf "LANG=%s.UTF-8\n" "$LANGCODE" >/etc/locale.conf
printf "KEYMAP=%s\n" "$MY_KEYMAP" >/etc/vconsole.conf

# Host stuff
printf '%s\n' "$MY_HOSTNAME" >/etc/hostname
[ "$MY_INIT" = "openrc" ] && printf 'hostname="%s"\n' "$MY_HOSTNAME" >/etc/conf.d/hostname
printf "\n127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t%s.localdomain\t%s\n" "$MY_HOSTNAME" "$MY_HOSTNAME" >/etc/hosts

# Install boot loader (Limine)
root_uuid=$(blkid "$PART2" -o value -s UUID)

if [ "$ENCRYPTED" = "y" ]; then
	my_params="cryptdevice=UUID=$root_uuid:root root=\/dev\/mapper\/root rw rootflags=subvol=root"
else
	my_params="root=UUID=$root_uuid rw rootflags=subvol=root"
fi

# Create limine configuration
mkdir -p /boot/limine
printf 'timeout: 5

/Artix
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    cmdline: %s
    module_path: boot():/initramfs-linux.img
' "$my_params" >/boot/limine/limine.conf

# Copy Limine EFI files
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI

# Add boot entry
part_num=$(echo "$PART1" | grep -o '[0-9]*$')
efibootmgr --create --disk "$MY_DISK" --part "$part_num" --label "Artix (Limine)" --loader '\EFI\BOOT\BOOTX64.EFI'

# Root user
if [ -n "$ROOT_PASSWORD" ]; then
	yes "$ROOT_PASSWORD" | passwd
fi

# Create regular user
if [ "$MAKE_SUDOER" = "y" ]; then
	useradd -m -s /bin/bash "$MY_USER"
	mkdir -p /etc/sudoers.d
	printf '%s ALL=(ALL) ALL\n' "$MY_USER" >/etc/sudoers.d/00_"$MY_USER"
else
	useradd -m -s /bin/bash "$MY_USER"
fi
yes "$USER_PASSWORD" | passwd "$MY_USER"

# Set up SDDM
rc-update add sddm default

# Other stuff you should do
if [ "$MY_INIT" = "openrc" ]; then
	sed -i '/rc_need="localmount"/s/^#//g' /etc/conf.d/swap
	rc-update add NetworkManager default
fi

# Enable [lib32] repository for 32-bit compatibility (Artix)
sed -i '/^#\[lib32\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

# Configure mkinitcpio
sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/g' /etc/mkinitcpio.conf
if [ "$ENCRYPTED" = "y" ]; then
	sed -i 's/^HOOKS.*$/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)/g' /etc/mkinitcpio.conf
else
	sed -i 's/^HOOKS.*$/HOOKS=(base udev autodetect keyboard keymap modconf block filesystems fsck)/g' /etc/mkinitcpio.conf
fi

mkinitcpio -P
