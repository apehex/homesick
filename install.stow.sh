#!/bin/bash

# Globals #
###########
DATE=`date +%Y-%m-%d`

# Copy the dotfiles #
#####################
rsync -avh --progress --inplace ./dotfiles/ ~/.dotfiles/
if [ -d ~/.dotfiles/bin/bin/ ]; then
    for filename in ~/.dotfiles/bin/.local/bin/* ; do
        chmod a+x $filename
    done
fi

# Link the dotfiles #
#####################
for filename in $HOME/.dotfiles/* ; do
    stow --dir=$HOME/.dotfiles --target=$HOME --restow "$(basename $filename)"
done
