# k3s 增强镜像的交互式运维环境配置。
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-vim}"
export PAGER="${PAGER:-less}"

alias k='kubectl'
alias kg='kubectl get'
alias kgp='kubectl get pods -A -o wide'
alias kgn='kubectl get nodes -o wide'
alias kdp='kubectl describe pod'
alias klogs='kubectl logs'
alias mk='make'
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
