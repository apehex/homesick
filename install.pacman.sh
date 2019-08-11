#!/bin/bash

# Globals #
###########
PROFILE=${1:-"admin"}
GCLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"

# Sublime Text #
################
if [[ "$PROFILE" = *"dev"* ]]; then
    wget -q -O - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
    # add pacman aur mirror
fi

# Docker #
##########
# if [[ "$PROFILE" = *"dev"* ]]; then
#     curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
#     # add pacman aur mirror
# fi

# QGIS #
########
if [[ "$PROFILE" = *"gis"* ]]; then
    wget -q -O - https://qgis.org/downloads/qgis-2017.gpg.key | sudo apt-key add -
    # add pacman aur mirror
fi

# TOR #
#######
if [[ "$PROFILE" = *"network"* ]]; then
   # add pacman aur mirror
fi

# Brave Browser #
#################
# if [[ "$PROFILE" = *"desktop"* ]]; then
#     wget -q -O - https://brave-browser-apt-release.s3.brave.com/brave-core.asc | sudo apt-key add -
#     # add pacman aur mirror
# fi

# Google Chrome #
#################
# if [[ "$PROFILE" = *"desktop"* ]]; then
#     wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
#     # add pacman aur mirror
# fi

# Google Cloud #
################
if [[ "$PROFILE" = *"admin"* ]]; then
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    # add pacman aur mirror
fi

# Install apt packages #
########################
if [[ "$PROFILE" = *"admin"* ]]; then ; fi
if [[ "$PROFILE" = *"desktop"* ]]; then ; fi
if [[ "$PROFILE" = *"dev"* ]]; then ; fi
if [[ "$PROFILE" = *"gis"* ]]; then ; fi
if [[ "$PROFILE" = *"media"* ]]; then ; fi
if [[ "$PROFILE" = *"network"* ]]; then ; fi
if [[ "$PROFILE" = *"radio"* ]]; then ; fi
if [[ "$PROFILE" = *"security"* ]]; then ; fi

# Install pip packages #
########################
if [[ "$PROFILE" = *"dev"* ]]; then pip3 install --user --upgrade pipenv; fi

# Install snap packages #
#########################
#if [[ "$PROFILE" = *"dev"* ]]; then sudo snap install heroku --classic; fi
