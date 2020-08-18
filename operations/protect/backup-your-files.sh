# encrypt and compress a folder
gpgtar --verbose --encrypt \
    --recipient apehex@protonmail.com \
    --output /tmp/backup/documents.gpg \
    ~/documents

# copy the archives
rsync -avh --progress --update \
    /tmp/backup/ \
    /mnt/usb/backup/
