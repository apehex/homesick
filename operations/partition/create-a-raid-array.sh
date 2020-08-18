# raid 0: data striping
mdadm --create --verbose --level=0 --metadata=1.2 --raid-devices=2 \
    /dev/md0 \
    /dev/sda1 /dev/sdb1
