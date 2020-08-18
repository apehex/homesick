# boot partition (usb drive)
mkfs.fat -F 32 /dev/sdd1

# logical volumes
mkfs.ext4 /dev/my-vg/root
mkfs.ext4 /dev/my-vg/home
mkfs.ext4 /dev/my-vg/tmp
mkfs.ext4 /dev/my-vg/var

# swap
mkswap /dev/my-vg/swap

# data, spanning a whole luks container
mkfs.ext4 /dev/mapper/sdc1_crypt
