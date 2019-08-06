#!/bin/bash

# Globals #
###########
DATE=`date +%Y-%m-%d`

# Config Repo #
###############
rsync -avh --progress --inplace ~/.dotfiles/ ./dotfiles/

# Push the changes to github #
##############################
git add -v dotfiles/
#git commit -a -m "Update config file ($DATE)"
