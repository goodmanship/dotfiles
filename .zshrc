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

# ----- Boba Fetch -----
source ~/.secrets/credentials
export BOBA_SLACK_BOT_TOKEN BOBA_SLACK_SIGNING_SECRET NOTION_API_KEY

# ----- Aliases -----

# Claude
alias clauded='claude --dangerously-skip-permissions --model "opus[1m]" --effort max'

# GCloud
alias gc='gcloud auth login && gcloud auth application-default login'

# Ghostty
alias gwin='~/.claude/scripts/ghostty-windows'

# Open new Ghostty window: gw [shortcut|theme]
gw() {
  local -A themes=(l 'Catppuccin Latte' m 'Catppuccin Mocha' n 'Neon')
  local theme="${themes[$1]:-$1}"
  [[ -z "$theme" ]] && { open -na Ghostty --args "--working-directory=$HOME/Dev/anatomy"; return; }
  open -na Ghostty --args "--theme=$theme" "--working-directory=$HOME/Dev/anatomy"
}

# Tab background color: gt <color>
gt() {
  local -A colors=(p '#2d1b69' b '#0a2f5c' g '#1a3d1a' r '#5c1a1a' a '#5c4a0a' t '#0a4a4a' w '#c0c0c0' s '#c4a882' 0 '#1e1e2e')
  local hex="${colors[$1]}"
  [[ -z "$hex" ]] && { echo "Colors: p(urple) b(lue) g(reen) r(ed) a(mber) t(eal) w(hite) s(epia) 0(reset)"; return 1; }
  printf '\e]11;%s\e\\' "$hex"
}

# ----- Functions -----

