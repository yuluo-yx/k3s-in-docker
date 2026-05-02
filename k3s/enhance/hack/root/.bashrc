# shellcheck shell=bash

if [ -f /etc/profile.d/k3s-enhance.sh ]; then
  . /etc/profile.d/k3s-enhance.sh
fi

export HISTFILE=/root/.bash_history
export HISTSIZE=5000
export HISTFILESIZE=10000
PS1='\u@\h:\w\$ '

if command -v typo >/dev/null 2>&1; then
  eval "$(typo init bash)"
fi
