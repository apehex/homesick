# use git log to find the latest commit to keep in history
git tag new-root 8bd0f0f102bc5e295b4f3d41a960cf87a2db5db8

# create a new branch with all previous history bundled in a single commit
git checkout --orphan temp new-root
git commit -m "Truncate the history"

# rebase the history between new-root and HEAD on the orphan node
# branch names are actually commit pointers:
#   so "new-root master" is actually
#   8bd0f0f102bc5e295b4f3d41a960cf87a2db5db8..HEAD
git rebase --onto temp new-root master
