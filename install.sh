#!/bin/bash

# Globals #
###########
DATE=`date +%Y-%m-%d`
PROFILE=${1:-"admin"}
GCLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"

# Configure Linux #
###################
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Update the local repo #
#########################
git pull

# Install the dotfiles #
########################
if [[ "$PROFILE" = *"dot"* ]]; then
    rsync -avh --progress --inplace ./dotfiles/ ~/.dotfiles/
    if [ -d ~/.dotfiles/bin/bin/ ]; then
        for filename in ~/.dotfiles/bin/.local/bin/* ; do
            chmod a+x $filename
        done
    fi
fi

# Stow the dotfiles #
#####################
if [[ "$PROFILE" = *"dot"* ]]; then
    for filename in $HOME/.dotfiles/* ; do
	    stow --dir=$HOME/.dotfiles --target=$HOME --restow "$(basename $filename)"
    done
fi

# Sublime Text #
################
if [[ "$PROFILE" = *"dev"* ]]; then
    wget -q -O - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
    echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
fi

# Docker #
##########
# if [[ "$PROFILE" = *"dev"* ]]; then
#     curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
#     sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
# fi

# QGIS #
########
if [[ "$PROFILE" = *"gis"* ]]; then
    wget -q -O - https://qgis.org/downloads/qgis-2017.gpg.key | sudo apt-key add -
    echo "deb https://qgis.org/debian stretch main" | sudo tee /etc/apt/sources.list.d/qgis.list
fi

# TOR #
#######
if [[ "$PROFILE" = *"network"* ]]; then
    echo "deb http://deb.debian.org/debian stretch-backports main contrib" | sudo tee /etc/apt/sources.list.d/stretch-backports.list
fi

# Brave Browser #
#################
# if [[ "$PROFILE" = *"desktop"* ]]; then
#     wget -q -O - https://brave-browser-apt-release.s3.brave.com/brave-core.asc | sudo apt-key add -
#     echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ `lsb_release -sc` main" | sudo tee -a /etc/apt/sources.list.d/brave-browser.list
# fi

# Google Chrome #
#################
# if [[ "$PROFILE" = *"desktop"* ]]; then
#     wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
#     echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
# fi

# Google Cloud #
################
if [[ "$PROFILE" = *"admin"* ]]; then
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb http://packages.cloud.google.com/apt $GCLOUD_SDK_REPO main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
fi

# Install apt packages #
########################
sudo apt update
if [[ "$PROFILE" = *"admin"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/apt.admin  | tr "\n" " "); fi
if [[ "$PROFILE" = *"desktop"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/apt.desktop  | tr "\n" " "); fi
if [[ "$PROFILE" = *"dev"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/apt.dev  | tr "\n" " "); fi
if [[ "$PROFILE" = *"gis"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/apt.gis  | tr "\n" " "); fi
if [[ "$PROFILE" = *"media"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/apt.media  | tr "\n" " "); fi
if [[ "$PROFILE" = *"network"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/apt.network  | tr "\n" " "); fi
if [[ "$PROFILE" = *"radio"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/apt.radio  | tr "\n" " "); fi
if [[ "$PROFILE" = *"security"* ]]; then sudo apt-get install $(grep -vE "^\s*#" dists/profiles/apt.security  | tr "\n" " "); fi

# Install pip packages #
########################
if [[ "$PROFILE" = *"dev"* ]]; then
    pip3 install --user --upgrade pipenv
fi

# Install snap packages #
#########################
#if [[ "$PROFILE" = *"dev"* ]]; then sudo snap install heroku --classic; fi
