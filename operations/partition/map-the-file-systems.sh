# create the folders
mkdir -p /target/tmp
mkdir -p /target/var
mkdir -p /target/boot/efi

# mount the devices
mount /dev/mapper/lvg-root /target/
mount /dev/mapper/lvg-tmp /target/tmp
mount /dev/mapper/lvg-var /target/var
mount /dev/sdd1 /target/boot/efi
swapon /dev/mapper/lvg-swap

# index the devices
genfstab -U /target >> /target/etc/fstab
