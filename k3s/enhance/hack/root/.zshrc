if [ -f /etc/profile.d/k3s-enhance.sh ]; then
  . /etc/profile.d/k3s-enhance.sh
fi

export HISTFILE=/root/.zsh_history
export HISTSIZE=5000
export SAVEHIST=10000
setopt append_history
setopt share_history
setopt hist_ignore_dups
autoload -Uz compinit
compinit

PROMPT='%n@%m:%~%# '

if command -v typo >/dev/null 2>&1; then
  eval "$(typo init zsh)"
fi
