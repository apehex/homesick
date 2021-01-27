# encrypt using the key associated with
OWNER=apehex@protonmail.com

# the parent folder, containing the data we want to backup
PARENT=$(realpath ~/documents/)

# final resting place for the files
BACKUP=$(realpath /mnt/backup/documents/)

# put the encrypted files in a temp dir
CACHE=$(mktemp -d)

# gpgtar doesn't work outside of the cwd
cd "$PARENT"

# encrypt and compress a folder
for D in ./*/ ; do
    gpgtar --verbose --encrypt \
        --recipient "$OWNER" \
        --output "$CACHE"/$(basename "$D").gpg \
        "$D"
done

# copy the archives
rsync -avh --progress --update "$CACHE"/ "$BACKUP"/

# clean up
rm -rf "$CACHE"/
