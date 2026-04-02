# Secrets (not committed to dotfiles repo)
[[ -f ~/.env.local ]] && source ~/.env.local

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"

# Config paths
export XDG_CONFIG_HOME="$HOME/.config"
export JIRA_CONFIG_FILE="$HOME/.config/.jira/.config.yml"

# GCP Artifact Registry auth for uv
export UV_KEYRING_PROVIDER=subprocess
export UV_INDEX_ANATOMY_PYTHON_USERNAME=oauth2accesstoken

# Mise (runtime version manager)
if [ -f ~/.local/bin/mise ]; then
  eval "$(~/.local/bin/mise activate zsh)"
fi

DEFAULT_USER=$USER

# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
  . "$HOME/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
  . "$HOME/google-cloud-sdk/completion.zsh.inc"
fi

# ----- Aliases -----

alias python='python3'

# Git
alias gprs='git pull --recurse-submodules'

# SSH tunnels (Anatomy)
alias sshprodold='ssh -i ~/.ssh/id_rsa -f -N -L 5433:anatomy-prod.ctk75s9hcvfr.us-east-1.rds.amazonaws.com:5432 rio@bastion.ext.anatomy.com -v'
alias sshprod='ssh -fNL 5433:anatomy-prod.ctk75s9hcvfr.us-east-1.rds.amazonaws.com:5432 rio@anatomy.com@bastion.ext.anatomy.com'
alias sshpk='pkill -f "5433:anatomy-prod"; ssh -fNL 5433:anatomy-prod.ctk75s9hcvfr.us-east-1.rds.amazonaws.com:5432 rio@anatomy.com@bastion.ext.anatomy.com -v'
alias sshpkanalytics='pkill -f "5434:database-1"; ssh -fNL 5434:database-1-instance-1.ctk75s9hcvfr.us-east-1.rds.amazonaws.com:5432 rio@anatomy.com@bastion.ext.anatomy.com -v'

# GCloud project shortcuts
alias gclouddev='gcloud config set project eob-ocr-and-extraction-dev'
alias gcloudprod='gcloud config set project rare-lattice-388916'

# Claude scripts (db access)
alias docdb='~/.claude/scripts/docdb'
alias payerdb='~/.claude/scripts/rdsdb payer'
alias userdb='~/.claude/scripts/rdsdb user'

# Environment
export DEPLOY_ENV=test
export DISABLE_REDIS=true

# ----- Local overrides (secrets, machine-specific) -----
if [ -f ~/.zprofile.local ]; then
  source ~/.zprofile.local
fi
