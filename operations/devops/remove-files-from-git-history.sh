PATH=~/some/file
BRANCH=master
REMOTE=origin

# select the relevant branch
git checkout "$BRANCH"

# remove from local index
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch $PATH" \
  --prune-empty --tag-name-filter cat -- --all

# using git repo cleaner
bfg --delete-files 'glob*' .

# ignore from future commits
echo "$PATH" >> .gitignore
git add .gitignore
git commit -m "Ignore user specific files"

# force push the new history
git push -u "$REMOTE" "$BRANCH" --force --all
git push -u "$REMOTE" "$BRANCH" --force --tags

