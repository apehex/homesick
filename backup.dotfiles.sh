#!/bin/bash

# Globals #
###########
DATE=`date +%Y-%m-%d`

# Copy user config #
####################
rsync -avh --progress --existing --update $HOME/.dotfiles/ ./dotfiles/home/

# Copy system config #
######################
sudo rsync -avh --progress --existing --update --chown=$SUDO_USER:$SUDO_USER /etc/ ./dotfiles/etc/

# Push the changes to github #
##############################
git add -v dotfiles/
#git commit -a -m "Update config file ($DATE)"
