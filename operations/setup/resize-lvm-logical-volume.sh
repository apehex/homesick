# add 1 Go to an existing lv
lvextend -L+1G /dev/my-vg/some-lv

# span a lv on all the free space
lvextend -l +100%FREE /dev/my-vg/some-lv

# extend file system
e2fsck -f /dev/my-vg/some-lv
resize2fs /dev/my-vg/some-lv
