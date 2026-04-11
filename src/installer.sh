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

pkgs="base base-devel $MY_INIT elogind-$MY_INIT efibootmgr limine btrfs-progs wget dhcpcd wpa_supplicant connman-$MY_INIT hyprland kitty nano sddm sddm-openrc sudo"
[ "$ENCRYPTED" = "y" ] && pkgs="$pkgs cryptsetup cryptsetup-$MY_INIT"

# Clean up any previous mounts/swap from a failed run
swapoff /mnt/swap/swapfile 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
if [ "$ENCRYPTED" = "y" ]; then
	cryptsetup close root 2>/dev/null || true
fi

# Partition disk
printf "label: gpt\n,550M,U\n,,\n" | sfdisk --force "$MY_DISK"

# Format and mount partitions
if [ "$ENCRYPTED" = "y" ]; then
	yes "$CRYPTPASS" | cryptsetup -q luksFormat "$PART2"
	yes "$CRYPTPASS" | cryptsetup open "$PART2" root
fi

mkfs.fat -F 32 "$PART1"

# Btrfs setup
mkfs.btrfs -f "$MY_ROOT"

# Create subvolumes
mount "$MY_ROOT" /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/swap
umount -R /mnt

# Mount subvolumes
mount -t btrfs -o compress=zstd,subvol=root "$MY_ROOT" /mnt
mkdir /mnt/home
mkdir /mnt/swap
mount -t btrfs -o compress=zstd,subvol=home "$MY_ROOT" /mnt/home
mount -t btrfs -o noatime,nodatacow,subvol=swap "$MY_ROOT" /mnt/swap

# Create swapfile
btrfs filesystem mkswapfile -s "$SWAP_SIZE"G /mnt/swap/swapfile

swapon /mnt/swap/swapfile

mkdir /mnt/boot
mount "$PART1" /mnt/boot

case $(grep vendor /proc/cpuinfo) in
*"Intel"*)
	pkgs="$pkgs intel-ucode"
	;;
*"Amd"*)
	pkgs="$pkgs amd-ucode"
	;;
esac

unset --
IFS=" "
for pkg in $pkgs; do
	set -- "$@" "$pkg"
done

# Install base system and kernel
if ! basestrap /mnt "$@"; then
	printf '\nERROR: Package installation failed.\n' >&2
	printf 'Your ISO may be outdated. Download the latest ISO from https://artixlinux.org/download.php and try again.\n' >&2
	exit 1
fi
if ! basestrap /mnt linux linux-firmware linux-headers mkinitcpio; then
	printf '\nERROR: Kernel installation failed.\n' >&2
	printf 'Your ISO may be outdated. Download the latest ISO from https://artixlinux.org/download.php and try again.\n' >&2
	exit 1
fi
fstabgen -U /mnt >/mnt/etc/fstab
