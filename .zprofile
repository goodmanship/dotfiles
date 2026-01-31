# Disable Ghostty's auto-title so we can set it manually
export GHOSTTY_SHELL_INTEGRATION_NO_TITLE=1

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# Mise (runtime version manager)
eval "$(~/.local/bin/mise activate zsh)"
