# update the boot image
update-initramfs -u

# generate boot loader configuration
grub-mkconfig -o /boot/grub/grub.cfg
