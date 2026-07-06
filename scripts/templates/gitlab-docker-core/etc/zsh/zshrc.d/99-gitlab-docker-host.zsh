# GitLab Docker host — system-wide zsh (all users)
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY INC_APPEND_HISTORY HIST_IGNORE_DUPS

autoload -Uz compinit
compinit -C

[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

if command -v docker >/dev/null 2>&1; then
  source <(docker completion zsh) 2>/dev/null
  source <(docker compose completion zsh) 2>/dev/null
fi
