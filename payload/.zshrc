# ~/.zshrc  -- self-hosted dotfiles. Update anytime with:  dotupdate
# oh-my-zsh is vendored under ~/.oh-my-zsh (shipped in the payload); nothing here
# reaches the internet.

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git)

# vendored copy -- never let OMZ phone home or self-update
DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT="true"

source "$ZSH/oh-my-zsh.sh"

# --- our fragments (loaded after OMZ so they win on conflicts) ---
ZSH_CONFIG="$HOME/.config/zsh"
source "$ZSH_CONFIG/aliases.zsh"
source "$ZSH_CONFIG/functions.zsh"
source "$ZSH_CONFIG/update.zsh"

# OS-specific
case "$(uname -s)" in
  Darwin) [ -f "$ZSH_CONFIG/macos.zsh" ] && source "$ZSH_CONFIG/macos.zsh" ;;
  Linux)  [ -f "$ZSH_CONFIG/linux.zsh" ] && source "$ZSH_CONFIG/linux.zsh" ;;
esac

# host-specific fragment, if present for this machine
_host="$(hostname -s 2>/dev/null || hostname)"
[ -f "$ZSH_CONFIG/hosts/$_host.zsh" ] && source "$ZSH_CONFIG/hosts/$_host.zsh"
unset _host

# role: k8s aliases only when this host is marked  (touch ~/.config/zsh/.is_k8s)
[ -f "$ZSH_CONFIG/.is_k8s" ] && source "$ZSH_CONFIG/k8s.zsh"
