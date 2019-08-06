#!/bin/bash

# Globals #
###########
DATE=`date +%Y-%m-%d`

# Copy user config #
####################
rsync -avh --progress $HOME/.dotfiles/ ./dotfiles/home/

# Copy system config #
######################
sudo rsync -avh --progress --existing --update /etc/ ./dotfiles/etc/

# Push the changes to github #
##############################
git add -v dotfiles/
#git commit -a -m "Update config file ($DATE)"
