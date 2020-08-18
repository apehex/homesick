# enlarge web of trust
gpg import some.key
gpg --edit-key some.key
#gpg> trust
#gpg> save

# verify file origin
gpg --verify file.sig file

# verify file content
sha256sum file
md5sum file
