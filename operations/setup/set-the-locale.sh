# on first boot / without a network manager
dhcpcd eth0

# update the system clock
timedatectl set-ntp true

# uncomment relevant lines in /etc/locale.gen
locale-gen

# set the locale system wide
localectl set-locale en_US.UTF-8

# ...everywhere
# LANG=en_US.UTF-8
vim /etc/locale.conf

# KEYMAP=fr
# FONT=lat9w-16
vim /etc/vconsole.conf
