#!/bin/bash

# Globals #
###########
DATE=`date +%Y-%m-%d`

# Config Repo #
###############
rsync -avh --progress --inplace ~/.dotfiles/ ./dotfiles/

# Push the changes to github #
##############################
git commit -a -m "config file update ($DATE)"
