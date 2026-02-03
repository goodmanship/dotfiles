# Completion
autoload -Uz compinit && compinit

# Disable git completion because SentinelOne is making it too slow
compdef -d git
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# History search with prefix (up/down arrow)
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

# Custom functions path
fpath=($fpath "/Users/goodmanship/.zfunctions")

# Starship prompt
eval "$(starship init zsh)"

# ----- Aliases -----

# Claude
alias clauded='claude --dangerously-skip-permissions'

# Ghostty windows with different themes
alias gwin='~/.claude/scripts/ghostty-windows'
alias g1='open -na Ghostty --args --theme="Cyberpunk" --working-directory="$HOME/Dev/anatomy"'
alias g2='open -na Ghostty --args --theme="Rebecca" --working-directory="$HOME/Dev/anatomy"'
alias g3='open -na Ghostty --args --theme="Novel" --working-directory="$HOME/Dev/anatomy"'
alias g4='open -na Ghostty --args --theme="Ocean" --working-directory="$HOME/Dev/anatomy"'
alias g5='open -na Ghostty --args --theme="Grass" --working-directory="$HOME/Dev/anatomy"'
alias g6='open -na Ghostty --args --theme="Neon" --working-directory="$HOME/Dev/anatomy"'
alias g7='open -a Ghostty --args --theme="Ubuntu" --working-directory="$HOME/Dev/anatomy"'

# ----- Functions -----

# Set tab/window title
title() {
  printf '\e]2;%s\e\\' "$1"
}

# Pick random line from file (macOS compatible)
_randline() {
  awk 'BEGIN{srand()} {lines[NR]=$0} END{print lines[int(rand()*NR)+1]}' "$1"
}

# Set random EPL team as tab title
rtitle() {
  local name=$(_randline ~/.config/ghostty/epl-teams.txt)
  title "$name"
  echo "Title: $name"
}

# Auto-set random EPL team title on new tabs
title "$(_randline ~/.config/ghostty/epl-teams.txt)"
