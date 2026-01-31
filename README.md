# Dotfiles

Shell configuration and scripts for macOS.

## Structure

| File | Purpose | Symlink Target |
|------|---------|----------------|
| `.zprofile` | Login shell setup (runs once per session) - homebrew, mise | `~/.zprofile` |
| `.zshrc` | Interactive shell config - completion, aliases, functions, prompt | `~/.zshrc` |
| `starship.toml` | Starship prompt configuration | `~/.config/starship.toml` |
| `.gitconfig` | Git configuration (not symlinked - may contain machine-specific settings) | — |
| `clean_room.sh` | Utility script | — |
| `prepare-commit-msg` | Git hook | — |

## Setup on a New Machine

```bash
# 1. Clone the repo
git clone <repo-url> ~/Dev/dotfiles
cd ~/Dev/dotfiles

# 2. Create symlinks (backup existing files first)
ln -s ~/Dev/dotfiles/.zprofile ~/.zprofile
ln -s ~/Dev/dotfiles/.zshrc ~/.zshrc
mkdir -p ~/.config
ln -s ~/Dev/dotfiles/starship.toml ~/.config/starship.toml

# 3. Restart your shell or source the config
source ~/.zprofile
source ~/.zshrc
```

## Dependencies

- [Homebrew](https://brew.sh) - package manager
- [Starship](https://starship.rs) - prompt (`brew install starship`)
- [Mise](https://mise.jdx.dev) - runtime version manager

## Aliases

- `clauded` - Run Claude with `--dangerously-skip-permissions`
- `g1`-`g6` - Open Ghostty windows with different color themes (Dracula, Novel, Rebecca, Grass, Ocean, Ubuntu)
- `title "name"` - Set the current tab/window title
