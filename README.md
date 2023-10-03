# Nix Config

## Installation

Mount the minimal ISO. Escalate privileges:

```bash
sudo -i
```

Connect to WiFi if needed:

```bash
systemctl start wpa_supplicant
wpa_cli
add_network
set_network 0 ssid "{ssid}"
set_network 0 psk "{password}"
set_network 0 key_mgmt WPA-PSK
enable_network 0
quit
```

Set `root` password with `passwd` to continue installation over SSH. Install Git:

```bash
nix-env -f '<nixpkgs>' -iA git
```

Find the disk to format:

```bash
lsblk -l
```

Run the installer:

```bash
./install.sh -d /dev/sda -e -s 8
# -d for disk
# -e to enable LUKS encryption
# -s to set swap size in GB
```
