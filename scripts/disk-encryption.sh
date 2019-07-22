echo "CRYPTSETUP=y" >> /etc/cryptsetup-initramfs/conf-hook
update-initramfs -u
update-grub
