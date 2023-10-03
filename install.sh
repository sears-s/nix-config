#!/usr/bin/env bash

# Get arguments
while getopts "d:es:" flag; do
  case "${flag}" in
    d) disk=${OPTARG};;
    e) encrypt=true;;
    s) swap_sz_gb=${OPTARG};;
  esac
done

# Check arguments
if [ ! -f $disk ] || [ ! -v $swap_sz_gb ]; then
  echo "Usage: $0 -d <disk> [-e] -s <swap_sz_gb>" 1>&2
  exit 1
fi

# Constants
mnt_opt=x-mount.mkdir,noatime,compress-force=zstd:2
declare -A subvols=(
  [nix]=nix
  [log]=var/log
  [persist]=persist
  [data]=data
  [swap]=swap
)

echo "Partitioning the disk..."
wifefs -af $disk
parted -s $disk \
  mklabel gpt \
  mkpart boot fat32 1MiB 512MiB \
  set 1 boot on \
  mkpart system 512MiB 100%

system=/dev/disk/by-partlabel/system
if $encrypt; then
  echo "Setting up LUKS..."
  cryptsetup luksFormat -y --type luks2 \
    -c aes-xts-plain64 -s 512 -h sha512 \
    --pbkdf argon2id -i 3000 \
    $system
  cryptsetup open $system luks
  system=/dev/mapper/luks
fi

echo "Creating BTRFS partition..."
mkfs.btrfs --csum xxhash $system
mount -t btrfs $system /mnt
for subvol in "${!subvols[@}]}"; do
  btrfs subvolume create /mnt/$subvol
btrfs filesystem mkswapfile -s "${swap_sz_gb}g" -U clear /mnt/swap/swapfile
umount /mnt

echo "Mounting BTRFS partition..."
for subvol in "${!subvols[@}]}"; do
  path="${subvols[$subvols]}"
  mount -o "subvol=${subvol},$mnt_opt" $system /mnt/$path
swapon /mnt/swap/swapfile

echo "Creating and mounting boot partition..."
mkfs.fat -F 32 /dev/disk/by-partlabel/boot
mount -o x-mount.mkdir /dev/disk/by-partlabel/boot /mnt/boot

echo "Mounting tmpfs root partition..."
mount -t tmpfs none /mnt

echo "Installing NixOS..."
nixos-generate-config --root /mnt
nixos-install --no-root-passwd
