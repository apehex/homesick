# enable swap in a running system
swapon /dev/my-swap

# /etc/initramfs/conf.d/resume
RESUME=UUID=11fdb53b-d45c-4b46-b946-b67de3b448f5

# /etc/default/grub
GRUB_CMDLINE_LINUX="resume=UUID=106e8c63-91b2-4c8a-aeff-5c14ea1dfea2"
