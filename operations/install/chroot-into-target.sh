# create required folders
mkdir -p /target/proc
mkdir -p /target/dev/pts
mkdir -p /target/sys
mkdir -p /target/run

# mount the running system (devices, processes, etc) in the target
mount -o bind /proc /target/proc
mount -o bind /dev /target/dev
mount -o bind /dev/pts /target/dev/pts
mount -o bind /sys /target/sys
mount -o bind /run /target/run

# actually chroot
cd /target
LANG=C chroot /target /bin/bash
