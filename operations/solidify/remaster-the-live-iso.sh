# mount the original ISO
mkdir /mnt/archiso
mount -t iso9660 -o loop /path/to/archISO /mnt/archiso

# copy the contents to another directory, where they can be edited:
cp -a /mnt/archiso ~/workspace/customiso

# decompress the file system
cd ~/workspace/customiso/arch/x86_64
unsquashfs airootfs.sfs

# copy the kernel
cp ../boot/x86_64/vmlinuz squashfs-root/boot/vmlinuz-linux

# run the system to build it from the inside
arch-chroot squashfs-root /bin/bash

# initiate pacman
pacman-key --init
pacman-key --populate archlinux
pacman-key --populate blackarch

# install additional packages (inside the chroot)
mkdir -p ~/workspace
cd ~/workspace
git clone https://github.com/apehex/homesick.git
cd homesick/
make install-live
make install-dotfiles

# build the boot image
pacman -Syu --force archiso linux

# load the live modules
# HOOKS="base udev memdisk archiso_shutdown archiso archiso_loop_mnt archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_kms block filesystems keyboard"
vim /etc/mkinitcpio.conf

# build the boot image
mkinitcpio -p linux

# list all the packages
LANG=C pacman -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > /pkglist.txt
pacman -Scc
exit

# move the kernel over to the system
mv squashfs-root/boot/vmlinuz-linux ~/customiso/arch/boot/x86_64/vmlinuz
mv squashfs-root/boot/initramfs-linux.img ~/customiso/arch/boot/x86_64/archiso.img
rm squashfs-root/boot/initramfs-linux-fallback.img

# place the list of packages where it belongs
mv squashfs-root/pkglist.txt ~/workspace/customiso/arch/pkglist.x86_64.txt

# now recreate airootfs.sfs:
rm airootfs.sfs
mksquashfs squashfs-root airootfs.sfs

# cleanup
rm -r squashfs-root
sha512sum airootfs.sfs > airootfs.sha512
