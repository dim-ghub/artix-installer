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

confirm_password() {
	stty -echo
	until [ "$pass1" = "$pass2" ] && [ "$pass2" ]; do
		printf "%s: " "$1" >&2 && read -r pass1 && printf "\n" >&2
		printf "confirm %s: " "$1" >&2 && read -r pass2 && printf "\n" >&2
	done
	stty echo
	echo "$pass2"
}

# Load keymap
until grep -q "^#*$LANGCODE\.UTF-8 UTF-8  $" /etc/locale.gen; do
	printf "Language (en_US, de_DE, etc.): " && read -r LANGCODE
	[ ! "$LANGCODE" ] && LANGCODE="en_US"
done
case "$LANGCODE" in
"en_GB")
	MY_KEYMAP="uk"
	;;
"en_US")
	MY_KEYMAP="us"
	;;
*)
	MY_KEYMAP=$(echo "$LANGCODE" | cut -c1-2)
	;;
esac
sudo loadkeys "$MY_KEYMAP"

# Check boot mode
[ ! -d /sys/firmware/efi ] && printf "Not booted in UEFI mode. Aborting..." && exit 1

# Boot mode already set to openrc (removed dinit support)
MY_INIT="openrc"

# Choose disk
until [ -b "$MY_DISK" ]; do
	echo
	sudo fdisk -l
	printf "\nWarning: the selected disk will be rewritten.\n"
	printf "\nDisk to install to (e.g. /dev/sda): " && read -r MY_DISK
done

PART1="$MY_DISK"1
PART2="$MY_DISK"2
case "$MY_DISK" in
*"nvme"* | *"mmcblk"*)
	PART1="$MY_DISK"p1
	PART2="$MY_DISK"p2
	;;
esac

# Swap size
until (echo "$SWAP_SIZE" | grep -Eq "^[0-9]+$") && [ "$SWAP_SIZE" -gt 0 ] && [ "$SWAP_SIZE" -lt 97 ]; do
	printf "Size of swap partition in GiB (4): " && read -r SWAP_SIZE
	[ ! "$SWAP_SIZE" ] && SWAP_SIZE=4
done

# Choose filesystem
until [ "$MY_FS" = "btrfs" ] || [ "$MY_FS" = "ext4" ]; do
	printf "Filesystem (btrfs/ext4): " && read -r MY_FS
	[ ! "$MY_FS" ] && MY_FS="btrfs"
done

# Encrypt or not
until [ "$ENCRYPTED" ]; do
	printf "Encrypt? (y/N): " && read -r ENCRYPTED
	[ ! "$ENCRYPTED" ] && ENCRYPTED="n"
done

if [ "$ENCRYPTED" = "y" ]; then
	MY_ROOT="/dev/mapper/root"
	CRYPTPASS=$(confirm_password "encryption password")
else
	MY_ROOT=$PART2
	[ "$MY_FS" = "ext4" ] && MY_ROOT=$PART2
fi

# Timezone
until [ -f /usr/share/zoneinfo/"$REGION_CITY" ]; do
	printf "Region/City (e.g. 'America/Denver'): " && read -r REGION_CITY
	[ ! "$REGION_CITY" ] && REGION_CITY="America/Denver"
done

# Host
until [ "$MY_HOSTNAME" ]; do
	printf "Hostname: " && read -r MY_HOSTNAME
done

# Regular user
until [ "$MY_USER" ]; do
	printf "Username: " && read -r MY_USER
done

USER_PASSWORD=$(confirm_password "user password")

# Make user a sudoer?
until [ "$MAKE_SUDOER" ]; do
	printf "Make user a sudoer? (y/N): " && read -r MAKE_SUDOER
	[ ! "$MAKE_SUDOER" ] && MAKE_SUDOER="n"
done

# Use same password for root?
until [ "$SAME_ROOT_PASSWORD" ]; do
	printf "Use same password for root? (y/N): " && read -r SAME_ROOT_PASSWORD
	[ ! "$SAME_ROOT_PASSWORD" ] && SAME_ROOT_PASSWORD="n"
done

if [ "$SAME_ROOT_PASSWORD" != "y" ]; then
	ROOT_PASSWORD=$(confirm_password "root password")
fi

printf "\nDone with configuration. Installing...\n\n"

# Install
sudo MY_INIT="$MY_INIT" MY_DISK="$MY_DISK" PART1="$PART1" PART2="$PART2" \
	SWAP_SIZE="$SWAP_SIZE" MY_FS="$MY_FS" ENCRYPTED="$ENCRYPTED" MY_ROOT="$MY_ROOT" \
	CRYPTPASS="$CRYPTPASS" \
	./src/installer.sh

# Chroot
sudo cp src/iamchroot.sh /mnt/root/ &&
	sudo MY_INIT="$MY_INIT" PART2="$PART2" MY_FS="$MY_FS" ENCRYPTED="$ENCRYPTED" \
		REGION_CITY="$REGION_CITY" MY_HOSTNAME="$MY_HOSTNAME" CRYPTPASS="$CRYPTPASS" \
		ROOT_PASSWORD="$ROOT_PASSWORD" LANGCODE="$LANGCODE" MY_KEYMAP="$MY_KEYMAP" \
		MY_USER="$MY_USER" USER_PASSWORD="$USER_PASSWORD" MAKE_SUDOER="$MAKE_SUDOER" \
		artix-chroot /mnt sh -ec './root/iamchroot.sh; rm /root/iamchroot.sh; exit' &&
	printf '\nYou may now poweroff.\n'
