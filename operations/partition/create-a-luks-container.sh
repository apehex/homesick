# create a luks container
cryptsetup -y -v --type luks luksFormat /dev/md0

# open it
cryptsetup open /dev/md0 md_crypt
