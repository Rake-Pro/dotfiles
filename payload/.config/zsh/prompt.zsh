# Hand-rolled prompt using zsh's builtin vcs_info -- no oh-my-zsh, no Powerline fonts.
autoload -Uz vcs_info add-zsh-hook
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr ' %F{yellow}*%f'
zstyle ':vcs_info:git:*' stagedstr ' %F{green}+%f'
zstyle ':vcs_info:git:*' formats       ' %F{magenta}%b%f%u%c'
zstyle ':vcs_info:git:*' actionformats ' %F{magenta}%b%f (%a)%u%c'

_prompt_vcs() { vcs_info }
add-zsh-hook precmd _prompt_vcs
setopt prompt_subst

# user@host  cwd  gitbranch(+dirty)   %#  (red on nonzero exit)
PROMPT='%F{green}%n@%m%f %F{blue}%~%f${vcs_info_msg_0_} %(?.%F{white}.%F{red})%#%f '
