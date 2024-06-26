# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# no lib preload
export LD_PRELOAD=""

# change the local
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

# password manager
export EDITOR="vim"
export PASSWORD_STORE_DIR="~/.mickey/"

# preferred terminal on I3
export TERMINAL=urxvt

# install Ruby Gems to ~/.gem
export GEM_HOME="$HOME/.local/share/gem"
export PATH="$HOME/.local/share/gem/bin:$PATH"

# install pyenv in .local/lib
export PYENV_ROOT="$HOME/.local/lib/pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

# go lang modules & stuff
export GOPATH="$HOME/.local/share/go"
export PATH="$GOPATH/bin:$PATH"

# rust crates
export PATH="$HOME/.cargo/bin:$PATH"

# foundry
export PATH="$PATH:/home/gully/.local/share//foundry/bin"

# heimdall-rs
export PATH="$PATH:/home/gully/.local/share/bifrost/bin"

# setup nvm
export NVM_DIR="$HOME/.local/share/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Init pyenv
eval "$(pyenv init -)"

# Disable broken mouse buttons
xmodmap $HOME/.Xmodmap

# Display a background
# . $HOME/.local/share/feh/.fehbg
