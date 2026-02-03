#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d_%H%M%S)"

echo "Dotfiles setup script"
echo "====================="
echo "Dotfiles dir: $DOTFILES_DIR"
echo ""

backup_and_link() {
  local src="$1"
  local dest="$2"

  if [ -L "$dest" ]; then
    echo "  Removing existing symlink: $dest"
    rm "$dest"
  elif [ -e "$dest" ]; then
    echo "  Backing up: $dest -> ${dest}${BACKUP_SUFFIX}"
    mv "$dest" "${dest}${BACKUP_SUFFIX}"
  fi

  echo "  Linking: $dest -> $src"
  ln -s "$src" "$dest"
}

# Home directory dotfiles
echo "Setting up home directory dotfiles..."
backup_and_link "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"
backup_and_link "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"
backup_and_link "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
backup_and_link "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml"
echo ""

# Ghostty config
echo "Setting up Ghostty config..."
mkdir -p "$HOME/.config/ghostty"
backup_and_link "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"
backup_and_link "$DOTFILES_DIR/ghostty/epl-teams.txt" "$HOME/.config/ghostty/epl-teams.txt"
backup_and_link "$DOTFILES_DIR/ghostty/random-epl-tab.sh" "$HOME/.config/ghostty/random-epl-tab.sh"
chmod +x "$HOME/.config/ghostty/random-epl-tab.sh"
echo ""

# Git templates
echo "Setting up git templates..."
mkdir -p "$HOME/.git-templates/hooks"
backup_and_link "$DOTFILES_DIR/prepare-commit-msg" "$HOME/.git-templates/hooks/prepare-commit-msg"
backup_and_link "$DOTFILES_DIR/clean_room.sh" "$HOME/.git-templates/clean_room.sh"
chmod +x "$HOME/.git-templates/hooks/prepare-commit-msg"
chmod +x "$HOME/.git-templates/clean_room.sh"
echo ""

# Create .zprofile.local for secrets if it doesn't exist
if [ ! -f "$HOME/.zprofile.local" ]; then
  echo "Creating ~/.zprofile.local for secrets..."
  cat > "$HOME/.zprofile.local" << 'EOF'
# Local secrets - NOT tracked in git
# Add your API tokens and secrets here

# export JIRA_API_TOKEN=your_token_here
# export GH_TOKEN=your_token_here

# React app env vars
# REACT_APP_NODE_ENV=local
# REACT_APP_MFA_DISABLED=true
EOF
  echo "  Created ~/.zprofile.local - add your secrets there"
else
  echo "~/.zprofile.local already exists, leaving it alone"
fi
echo ""

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Add your secrets to ~/.zprofile.local"
echo "  2. Restart your shell or run: source ~/.zprofile && source ~/.zshrc"
echo "  3. Test the EPL tab names: open a new Ghostty tab with Cmd+Shift+T"
