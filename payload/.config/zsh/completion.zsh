# zsh builtin completion setup (replaces oh-my-zsh's completion handling)
mkdir -p "${ZSH_COMPDUMP:h}" 2>/dev/null
autoload -Uz compinit bashcompinit
compinit -d "${ZSH_COMPDUMP:-$HOME/.zcompdump}"
bashcompinit   # lets a few bash-style completions load if a tool ships them

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' list-colors ''
setopt auto_menu complete_in_word always_to_end
