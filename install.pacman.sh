#!/bin/bash

#Globals #
###########
PROFILE=${1:-"admin"}

# Sublime Text #
################
if [[ "$PROFILE" = *"dev"* ]]; then
    wget -q -O - https://download.sublimetext.com/sublimehq-pub.gpg | sudo pacman-key --add - && sudo pacman-key --lsign-key 8A8F901A
    echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | sudo tee -a /etc/pacman.conf
fi

# Poetry #
##########
if [[ "$PROFILE" = *"dev"* ]]; then
    curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python
    poetry completions bash | sudo tee /etc/bash_completion.d/poetry.bash-completion
fi

#Docker #
##########
# if [[ "$PROFILE" = *"dev"* ]]; then
#     curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
#     # add pacman aur mirror
# fi

# QGIS #
########
if [[ "$PROFILE" = *"gis"* ]]; then
    wget -q -O - https://qgis.org/downloads/qgis-2017.gpg.key | sudo apt-key add -
    add pacman aur mirror
fi

# TOR #
#######
#if [[ "$PROFILE" = *"network"* ]]; then
#    add pacman aur mirror
#fi

#Brave Browser #
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

# Install pacman packages #
###########################
if [[ "$PROFILE" = *"admin"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.admin | tr "\n" " "); fi
if [[ "$PROFILE" = *"dev"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.dev | tr "\n" " "); fi
if [[ "$PROFILE" = *"gis"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.gis | tr "\n" " "); fi
if [[ "$PROFILE" = *"live"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.live | tr "\n" " "); fi
if [[ "$PROFILE" = *"media"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.media | tr "\n" " "); fi
if [[ "$PROFILE" = *"network"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.network  | tr "\n" " "); fi
if [[ "$PROFILE" = *"office"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.office | tr "\n" " "); fi
if [[ "$PROFILE" = *"radio"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.radio | tr "\n" " "); fi
if [[ "$PROFILE" = *"security"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.security | tr "\n" " "); fi
if [[ "$PROFILE" = *"terminal"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.terminal | tr "\n" " "); fi
if [[ "$PROFILE" = *"ui"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.ui | tr "\n" " "); fi
if [[ "$PROFILE" = *"virtual"* ]]; then sudo pacman -S $(grep -vE "^\s*#" dists/archlinux/pacman.virtual | tr "\n" " "); fi

# Install pip packages #
########################
#if [[ "$PROFILE" = *"dev"* ]]; then pip3 install --user --upgrade pipenv; fi

# Install snap packages #
#########################
#if [[ "$PROFILE" = *"dev"* ]]; then sudo snap install heroku --classic; fi
