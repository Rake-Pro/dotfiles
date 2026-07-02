#!/bin/sh
# Bootstrap dotfiles from your self-hosted server.  Usage:
#   curl -fsSL https://dotfiles.example/install | sh
# The server rewrites @@BASE@@ to its own URL before sending this script,
# so the installed config updates from wherever you fetched it.
set -eu

BASE="${DOTFILES_URL:-@@BASE@@}"

# --- dependency check (only the obvious ones) ---
missing=""
for dep in zsh curl tar; do
  command -v "$dep" >/dev/null 2>&1 || missing="$missing $dep"
done
if [ -n "$missing" ]; then
  echo "missing dependencies:$missing"
  if command -v apt-get >/dev/null 2>&1; then
    echo "installing via apt..."; sudo apt-get update -qq && sudo apt-get install -y $missing
  elif command -v dnf >/dev/null 2>&1; then
    echo "installing via dnf..."; sudo dnf install -y $missing
  elif command -v brew >/dev/null 2>&1; then
    echo "installing via brew..."; brew install $missing
  else
    echo "install$missing manually, then re-run."; exit 1
  fi
fi

# --- fetch + apply payload into $HOME ---
echo "fetching dotfiles from $BASE ..."
curl -fsSL "$BASE/dotfiles.tar.gz" | tar -xzf - -C "$HOME"

# --- activate vendored fonts (MesloLGS NF, needed by the agnoster theme) ---
if [ -d "$HOME/.local/share/fonts" ]; then
  case "$(uname -s)" in
    Darwin)
      mkdir -p "$HOME/Library/Fonts"
      cp "$HOME/.local/share/fonts/"*.ttf "$HOME/Library/Fonts/" 2>/dev/null || true
      echo "fonts installed to ~/Library/Fonts"
      ;;
    Linux)
      if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
        echo "font cache refreshed"
      fi
      ;;
  esac
  echo "set your terminal font to 'MesloLGS NF' for the agnoster theme to render."
fi

# --- record server URL + installed version for dotupdate ---
mkdir -p "$HOME/.config/zsh"
printf '%s' "$BASE" > "$HOME/.config/zsh/.dotfiles_url"
curl -fsSL "$BASE/version" > "$HOME/.config/zsh/.version"

# --- make zsh the login shell (best-effort) ---
zsh_path="$(command -v zsh)"
if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
  echo "setting zsh as your login shell..."
  chsh -s "$zsh_path" || echo "could not chsh; run: chsh -s $zsh_path"
fi

echo
echo "dotfiles installed (version $(cat "$HOME/.config/zsh/.version"))."
echo "start a new shell, or run: exec zsh"
echo "update anytime with: dotupdate"
