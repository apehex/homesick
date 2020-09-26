mdadm --detail --scan >> /etc/mdadm.conf

# (/target)/etc/default/grub
GRUB_PRELOAD_MODULES="part_gpt part_msdos ntfs mdraid09 mdraid1x lvm"

# (/target)/etc/mkinitcpio.conf ramfs hooks
MODULES=(dm-raid raid0 raid1 raid10 raid456 usbhid xhci_hcd)
FILES=(/crypto_keyfile.bin)
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block mdadm_udev lvm2 encrypt filesystems fsck)
