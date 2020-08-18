# install required modules
anna-install crypto-dm-modules cryptsetup

# activate the modules
depod -a
modprobe dm-crypt
modprobe cryptsetup

# open the container
cryptsetup open /dev/md/root md_crypt

# find and activate the logical volumes
vgscan
vgchange -a y lvg
