BRANCH=some-outdated-stuff
REMOTE=origin

# local: -D to force deletion of unmerged branch
git branch -d $BRANCH
git branch -D $BRANCH

# remote
git push -d $REMOTE $BRANCH
