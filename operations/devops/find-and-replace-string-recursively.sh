# ignore the .git directory entirely
find ./ \
\( -type d -name .git -prune \) -o \
-type f -print0 |
xargs -0 sed -i 's/before/after/g'
