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

# Optional: check once per day on shell start, notify only (never auto-applies).
_dotfiles_autocheck() {
  local base stamp now last
  base="$(_dotfiles_base)"; [ -n "$base" ] || return
  stamp="$HOME/.cache/zsh/.dotfiles_lastcheck"
  now="$(date +%s)"
  last="$(cat "$stamp" 2>/dev/null || echo 0)"
  [ $(( now - last )) -lt 86400 ] && return
  mkdir -p "${stamp:h}"; printf '%s' "$now" > "$stamp"
  local remote local_v
  remote="$(curl -fsSL --max-time 3 "$base/version" 2>/dev/null)" || return
  local_v="$(cat "$HOME/.config/zsh/.version" 2>/dev/null || echo none)"
  [ "$remote" != "$local_v" ] && echo "dotfiles update available ($local_v -> $remote). run: dotupdate"
}
_dotfiles_autocheck
