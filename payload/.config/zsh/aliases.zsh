# shared aliases -- every host
alias reload="exec zsh"
alias zshedit="\$EDITOR ~/.zshrc"

# ls / navigation
alias ll="ls -lah"
alias la="ls -A"
alias ..="cd .."
alias ...="cd ../.."

# git shorthand
alias gs="git status -sb"
alias gd="git diff"
alias gl="git log --oneline --graph --decorate -20"
alias gp="git pull --ff-only"
