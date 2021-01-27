# encrypt using the key associated with
OWNER=apehex@protonmail.com

# the file / folder to backup
TARGET=$(realpath ~/documents/)
PARENT=$(dirname "$TARGET")
NAME=$(basename "$TARGET")

# final resting place for the data
BACKUP=$(realpath /mnt/backup/)

# put the encrypted files in a temp dir
CACHE=$(mktemp -d)

# gpgtar doesn't work outside of the cwd
cd "$PARENT"

# encrypt and compress a folder
gpgtar --verbose --encrypt \
    --recipient "$OWNER" \
    --output "$CACHE"/"$NAME".gpg \
    "$NAME"

# copy the archives
sudo rsync -avh --progress --update "$CACHE"/ "$BACKUP"/

# clean up
rm -rf "$CACHE"/
