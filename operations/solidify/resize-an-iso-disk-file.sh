# add 1 Go to the file
dd if=/dev/zero bs=1M count=1024 >> file.iso

# create a device, eg /dev/loop0
losetup -f -P --show file.iso

# extend the partitions
#   print the partitions: p
#   remove the second partition: r => 2
#   create a new one, spanning all the free space: n => p => 2 => 100%
fdisk -c -u /dev/loop0

# extend the file system
e2fsck -f /dev/loop0p2