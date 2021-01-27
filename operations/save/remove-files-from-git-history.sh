# remove the file the existing history
git filter-branch --force --index-filter \
    "git rm --cached --ignore-unmatch some/sensitive/file" \
    --prune-empty --tag-name-filter cat -- --all

# prevent it from ever being pushed
echo "some/sensitive/file >> .gitignore"

# double check
# rewrite the history
git push origin --force --all
git push origin --force --tags
