if [ -f /etc/profile.d/k3s-enhance.sh ]; then
  . /etc/profile.d/k3s-enhance.sh
fi

export HISTFILE=/root/.zsh_history
export HISTSIZE=5000
export SAVEHIST=10000
setopt append_history
setopt share_history
setopt hist_ignore_dups
autoload -Uz colors compinit
colors
compinit

# 使用轻量双行彩色提示符，避免引入完整的 Oh My Zsh。
PROMPT=$'\n%F{cyan}%n%f@%F{magenta}%m%f %F{blue}·%f %F{yellow}%~%f\n%F{red}%#%f '
RPROMPT='%F{blue}[%D{%H:%M:%S}]%f'

if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
  . /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if command -v typo >/dev/null 2>&1; then
  eval "$(typo init zsh)"
fi

# zsh-syntax-highlighting 需要最后加载，才能包装前面注册的 ZLE 控件。
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  . /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
