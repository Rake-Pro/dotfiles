# Self-update against your dotfiles server (oh-my-zsh-style, but pointed at your box).
# The install script writes the server URL to ~/.config/zsh/.dotfiles_url.
_dotfiles_base() {
  if [ -f "$HOME/.config/zsh/.dotfiles_url" ]; then
    cat "$HOME/.config/zsh/.dotfiles_url"
  else
    echo "${DOTFILES_URL:-}"
  fi
}

dotupdate() {
  local base remote local_v
  base="$(_dotfiles_base)"
  [ -n "$base" ] || { echo "dotupdate: no server URL (set DOTFILES_URL or reinstall)"; return 1; }

  remote="$(curl -fsSL "$base/version")" || { echo "dotupdate: cannot reach $base"; return 1; }
  local_v="$(cat "$HOME/.config/zsh/.version" 2>/dev/null || echo none)"

  if [ "$remote" = "$local_v" ]; then
    echo "dotfiles up to date ($local_v)"
    return 0
  fi

  echo "dotfiles: $local_v -> $remote"
  curl -fsSL "$base/dotfiles.tar.gz" | tar -xzf - -C "$HOME" || { echo "dotupdate: extract failed"; return 1; }
  printf '%s' "$remote" > "$HOME/.config/zsh/.version"
  echo "updated. reloading shell..."
  exec zsh
}

# Startup update check (oh-my-zsh style): on an interactive shell, if the server
# has a newer version, prompt to apply it. Config (export before this is sourced,
# e.g. in ~/.commonrc):
#   DOTFILES_UPDATE_MODE=prompt|auto|notify|disabled   (default: prompt)
#   DOTFILES_UPDATE_INTERVAL_DAYS=<n>                   (default: 1; 0 = every session)
_dotfiles_autocheck() {
  # interactive terminals only -- never block scripts or non-tty shells
  [[ -o interactive ]] || return
  [ -t 0 ] || return

  local mode="${DOTFILES_UPDATE_MODE:-prompt}"
  [ "$mode" = disabled ] && return

  local base; base="$(_dotfiles_base)"; [ -n "$base" ] || return

  # throttle: skip the network entirely if we checked within the interval
  local stamp="$HOME/.cache/zsh/.dotfiles_lastcheck"
  local days="${DOTFILES_UPDATE_INTERVAL_DAYS:-1}"
  local now last; now="$(date +%s)"; last="$(cat "$stamp" 2>/dev/null || echo 0)"
  if [ "$days" -gt 0 ] && [ $(( now - last )) -lt $(( days * 86400 )) ]; then
    return
  fi

  local remote local_v
  remote="$(curl -fsSL --max-time 3 "$base/version" 2>/dev/null)" || return  # unreachable: stay quiet, don't stamp
  mkdir -p "${stamp:h}"; printf '%s' "$now" > "$stamp"
  local_v="$(cat "$HOME/.config/zsh/.version" 2>/dev/null || echo none)"
  [ "$remote" = "$local_v" ] && return

  case "$mode" in
    notify)
      echo "dotfiles: update available ($local_v -> $remote). run: dotupdate" ;;
    auto)
      echo "dotfiles: updating $local_v -> $remote ..."; dotupdate ;;
    prompt|*)
      if read -q "REPLY?dotfiles: update available ($local_v -> $remote). Apply now? [y/N] "; then
        echo; dotupdate
      else
        echo; echo "dotfiles: skipped. run 'dotupdate' when ready (asked again in ${days}d)."
      fi ;;
  esac
}
_dotfiles_autocheck
