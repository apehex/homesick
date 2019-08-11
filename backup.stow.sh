#!/bin/bash

# Globals #
###########
DATE=`date +%Y-%m-%d`

# Copy user config #
####################
rsync -avh --progress --existing --update $HOME/.dotfiles/ ./dotfiles/home/

# Copy system config #
######################
rsync -avh --progress --existing --update /etc/ ./dotfiles/etc/

# Push the changes to github #
##############################
git add -v dotfiles/
#git commit -a -m "Update config file ($DATE)"
