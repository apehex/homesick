#!/bin/bash

# the target folder must not contain leading / trailing characters
# ie target NOT ./target/
PARENT_PATH=${1:-"~/parent/repository"}
TARGET_DIR=${2:-"target"}
TARGET_SLUG=${3:-"git@github.com:user/new-repo.git"}
TEMP_BRANCH=${4:-"temp"}

# turn the history of the target subfolder into a new branch
cd "$PARENT_PATH"
git subtree split -P "$TARGET_DIR" -b "$TEMP_BRANCH"

# create the new repo
 mkdir ~/"$TARGET_DIR" && cd ~/"$TARGET_DIR"
 git init
 git pull "$PARENT_PATH" "$TEMP_BRANCH"

# link to github or any server
 git remote add origin "$TARGET_SLUG"
 git push -u origin master

# Cleanup inside the parent repo
# git rm -rf "$PARENT_PATH/$TARGET_DIR"
