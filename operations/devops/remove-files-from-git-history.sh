PATH=~/some/file
BRANCH=master
REPO=origin

# remove from local index
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch $PATH" \
  --prune-empty --tag-name-filter cat -- --all

# ignore from future commits
echo "$PATH" >> .gitignore
git add .gitignore
git commit -m "Ignore user specific files"

# force push the new history
git push "$REPO" --force --all
git push "$REPO" --force --tags
