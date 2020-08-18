# press c on the grub console

# list devices
ls -l
set root=(hd0,2)

# find the kernel version
uname -r

# select the image
linux /vmlinuz-4.19.0-10-amd64
initrd /initramfs-4.19.0-10-amd64

boot
