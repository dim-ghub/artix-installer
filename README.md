# artix-installer

![](https://img.shields.io/badge/OS-Artix%20Linux-blue?logo=Artix+Linux)

A simple installer for Artix Linux with OpenRC support.

## Usage

1. Boot into the Artix live disk (the login and password are both `artix`).
2. Connect to the internet. Ethernet is setup automatically, and wifi is done with something like:
```
sudo rfkill unblock wifi
sudo ip link set wlan0 up
nmtui
```
In NetworkManager TUI, select Activate a Connection, select your network and follow instructions. Then, press escape and select Quit.

3. Acquire the install scripts and run:
```
sudo pacman -Sy --needed --noconfirm git && git clone --depth=1 https://github.com/dim-ghub/artix-installer.git && cd artix-installer && ./install.sh
```
4. When everything finishes, `poweroff`, remove the installation media, and boot into Artix. Post-installation networking is done with Connman.

### Preinstallation

* ISO downloads can be found at [artixlinux.org](https://artixlinux.org/download.php)
* ISO files can be burned to drives with `dd` or something like Etcher.
* `sudo dd bs=4M if=/path/to/artix.iso of=/dev/sd[drive letter] status=progress`
* A better method these days is to use [Ventoy](https://www.ventoy.net/en/index.html).

### Troubleshooting

#### Package 404 errors during installation

If you see `failed retrieving file ... The requested URL returned error: 404` for all mirrors, your ISO is outdated — the package versions it references no longer exist on the mirrors. Download the latest ISO from [artixlinux.org](https://artixlinux.org/download.php) and try again.
