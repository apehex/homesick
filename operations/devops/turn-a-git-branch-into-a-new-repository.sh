# create a new repo in github

# the old repo
cd /path/to/old/repo

# tear a branch away and plant it in the new-repo:
# - old-branch becomes master in the new repo
# - the history is kept
git push https://github.com/apehex/new-repo.git +old-branch:master
