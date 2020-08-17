# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls -lAh --color=auto --group-directories-first'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias rgrep='grep --color=auto -rHo'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
else
    alias ls='ls -lAh --group-directories-first'
fi

# allow non ascii characters
alias subl='LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 subl'

# list files
alias tree='tree -a --dirsfirst'

# backup existing files when moving
alias mv='mv -bv'
alias cp='cp -bv'

# overwrite files to prevent recovery
alias shred='shred -zf'

# hide user-agent
alias wget='wget -U "noleak"'
alias curl='curl --user-agent "noleak"'

# custom config folder
alias mickey='PASSWORD_STORE_DIR=~/.mickey/ pass'

# binary file editing in vim
#alias hexvim='vim -p -b -c "set binary" --servername HEXVIM'

# repeat most recent command with 'sudo' this time...
alias ahhh='sudo $(history -p \!\!)'

# keep aliases in sudo
alias sudo='sudo '

# mirror a website
alias mirror='wget -rNl inf -p -E -k -np -w 1 -e robots=off --no-cookies --random-wait'
