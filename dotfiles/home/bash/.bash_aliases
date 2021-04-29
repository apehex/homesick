# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='LC_ALL=C ls -lisa --color=auto --group-directories-first'
    alias tree='LC_ALL=C tree -a -C -L 2 --dirsfirst'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias rgrep='grep --color=auto -rHo'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
else
    alias ls='LC_ALL=C ls -lisa --group-directories-first'
    alias tree='LC_ALL=C tree -a -L 2 --dirsfirst'
fi

# allow non ascii characters
alias subl='LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 subl'

# backup existing files when moving
alias mv='mv -bv'
alias cp='cp -bv'

# short and readable
alias du='du -h -d 1'

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

# neo4j
alias neo4j='NEO4J_HOME=/usr/share/java/neo4j neo4j'
