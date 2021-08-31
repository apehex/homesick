# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# colors
darkgrey="$(tput bold ; tput setaf 0)"
red="$(tput bold ; tput setaf 1)"
green="$(tput bold ; tput setaf 2)"
yellow="$(tput bold ; tput setaf 3)"
blue="$(tput bold; tput setaf 4)"
magenta="$(tput bold ; tput setaf 5)"
cyan="$(tput bold; tput setaf 6)"
white="$(tput bold ; tput setaf 7)"
nc="$(tput sgr0)"

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${chroot_dir:-}" ] && [ -r /etc/chroot_dir ]; then
    chroot_dir=$(cat /etc/chroot_dir)
fi

if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    PS1_UPPER_ARROW="\[$cyan\]\342\224\214\342\224\200["
    PS1_USER_HOST="\[$magenta\]\u\[$cyan\]@\[$darkgrey\]\H"
    PS1_LINK="\[$cyan\]]\342\224\200["
    PS1_WD="\[$magenta\]\w"
    PS1_LOWER_ARROW="\[$cyan\]]\n\[$cyan\]\342\224\224\342\224\200\342\224\200\342\225\274 ["
    PS1_BOX="\[$darkgrey\]??"
    PS1_END="\[$cyan\]]\$ \[$nc\]"
    export PS1="${PS1_UPPER_ARROW}${PS1_USER_HOST}${PS1_LINK}${PS1_WD}${PS1_LOWER_ARROW}${PS1_BOX}${PS1_END}"
else
    PS1='┌──[\u@\h]─[\w]\n└──╼ \$ '
fi

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    export PS1="\[\e]0;${chroot_dir:+($chroot_dir)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# load pyenv into the shell
eval "$(pyenv init -)"
