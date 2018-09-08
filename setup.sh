#!/bin/bash

# Globals #
###########
DATE=`date +%Y-%m-%d`
PROFILE=${1:-"core"}
MODE=${2:-"setup"}
GCLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"

# Configure Linux #
###################
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Config Repo #
###############
if [[ "$MODE" = *"setup"* ]]; then
    rsync -avh --progress --inplace ./dotfiles/ ~/.dotfiles/
    if [ -d ~/.dotfiles/bin/bin/ ]; then
        for filename in ~/.dotfiles/bin/bin/* ; do
            chmod +x $filename
        done
    fi
elif [[ "$MODE" = *"backup"* ]]; then
    rsync -avh --progress --inplace ~/.dotfiles/ ./dotfiles/
fi

# Link Configuration to Repo #
##############################

# Sublime Text #
################
if [[ "$MODE" = *"setup"* ]]; then
    wget -q -O - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
    echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
fi

# Brave Browser #
#################
# if [[ "$MODE" = *"setup"* ]]; then
#     wget https://s3-us-west-2.amazonaws.com/brave-apt/keys.asc | sudo apt-key add -
#     echo "deb [arch=amd64] https://s3-us-west-2.amazonaws.com/brave-apt `lsb_release -sc` main" | sudo tee -a /etc/apt/sources.list.d/brave-browser.list
# fi

# Google Chrome #
#################
# if [[ "$MODE" = *"setup"* ]]; then
#     wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
#     echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
# fi

# Google Cloud #
################
if [[ "$MODE" = *"setup"* ]]; then
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb http://packages.cloud.google.com/apt $GCLOUD_SDK_REPO main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
fi

# Install apt packages #
########################
if [[ "$MODE" = *"setup"* ]]; then
    sudo apt update
    sudo apt-get install $(grep -vE "^\s*#" dists/profiles/core.packages  | tr "\n" " ")
    if [[ "$PROFILE" = *"tools"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/tools.packages  | tr "\n" " "); fi
    if [[ "$PROFILE" = *"dev"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/dev.packages  | tr "\n" " "); fi
    if [[ "$PROFILE" = *"media"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/media.packages  | tr "\n" " "); fi
fi

# Install pip packages #
########################

# Install snap packages #
#########################
if [[ "$MODE" = *"setup"* ]]; then
    if [[ "$PROFILE" = *"dev"* ]]; then sudo snap install heroku --classic; fi
fi

# Stow the dotfiles #
#####################
if [[ "$MODE" = *"setup"* ]]; then
    for filename in ~/.dotfiles/*/ ; do
        stow $filename
    done
fi

# Push the changes to github #
##############################
if [[ "$MODE" = *"backup"* ]]; then
    git commit -a -m "config file update ($DATE)"
fi
