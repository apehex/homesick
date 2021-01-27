# archive paths
A=$(realpath ${1:-"~/a.gpg"})
B=$(realpath ${2:-"~/b.gpg"})

# output archive
OUTPUT=$(realpath ${3:-"~/c.gpg"})

# owner
OWNER=apehex@protonmail.com

# CACHE
CACHE=$(realpath $(mktemp -d))

# extract the archives
cd "$CACHE"
mkdir A B
gpgtar -d -C ./A "$A"
gpgtar -d -C ./B "$B"

# sync the directories
rsync -avh --progress --update ./A ./B

# archive the merged directory
cd ./B
gpgtar -e -r "$OWNER" -v -o "$OUTPUT" ./

# clean
rm -rf "$CACHE"
