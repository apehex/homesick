# raid 0: data striping
mdadm --assemble /dev/md0 -v /dev/sda1 /dev/sdb1
