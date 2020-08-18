# /target/etc/apt/sources.list
deb http://deb.debian.org/debian/ stable main non-free contrib
deb-src http://deb.debian.org/debian/ stable main non-free contrib

# Install the base
debootstrap --arch=amd64 stable /target http://deb.debian.org/debian/
