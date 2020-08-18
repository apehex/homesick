# create the physical volume, from an encrypted mdarray (ex)
pvcreate /dev/mapper/md0_crypt

# create a volume group
vgcreate my-vg /dev/mapper/md0_crypt

# and finally the children volumes
lvcreate -L 8G -n swap my-vg
lvcreate -L 8G -n tmp my-vg
lvcreate -L 4G -n var my-vg
lvcreate -L 32G -n root my-vg
lvcreate -L 80G -n home my-vg
