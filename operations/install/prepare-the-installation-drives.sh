# make an installation drive
dd bs=4M status=progress oflag=sync if=debian.iso of=/dev/sdx

# copy required firmwares on another usb drive
mount /dev/sdy1 /mnt/usb
unzip ~/downloads/firmware.zip -d /mnt/usb/

# format a boot drive (optional)
fdisk -c -u /dev/sdz
