# Disable git completion because SentinelOne is making it too slow
compdef -d git

# Enable and configure zsh completion
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

fpath=($fpath "/Users/goodmanship/.zfunctions")

# Set typewritten ZSH as a prompt
#autoload -U promptinit; promptinit
#prompt typewritten

# Starship
eval "$(starship init zsh)"
