# create a container
cryptsetup luksFormat /dev/sda

# fill with zeros (fast)
cryptsetup open /dev/sda sda_crypt
dd bs=1M status=progress if=/dev/zero of=/dev/mapper/sda_crypt
cryptsetup close sda_crypt

# randomize the header
#   the rest of the partition is already random,
#   thanks to the luks encryption!
dd bs=512 count=2056 if=/dev/urandom of=/dev/sda
