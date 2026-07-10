#!/usr/bin/env bash
# Bootstrap dotfiles from your self-hosted server.  Usage:
#   curl -fsSL https://dotfiles.example/install | bash
# Pipe through bash (not sh): Ubuntu 20.04's dash 0.5.10 mis-parses some
# constructs, and bash is present on every target host.
# The server rewrites @@BASE@@ to its own URL before sending this script,
# so the installed config updates from wherever you fetched it.
set -eu

BASE="${DOTFILES_URL:-@@BASE@@}"

# whether we can install packages: already root, or sudo is available
can_install=1
sudo_cmd=""
if [ "$(id -u)" != "0" ]; then
  if command -v sudo >/dev/null 2>&1; then
    sudo_cmd="sudo"
  else
    can_install=""
  fi
fi

# --- dependency check (only the obvious ones) ---
missing=""
for dep in zsh curl tar; do
  command -v "$dep" >/dev/null 2>&1 || missing="$missing $dep"
done
if [ -n "$missing" ]; then
  echo "missing dependencies:$missing"
  if [ -z "$can_install" ]; then
    echo "no sudo available; install$missing manually as root, then re-run."
    exit 1
  elif command -v apt-get >/dev/null 2>&1; then
    echo "installing via apt..."; $sudo_cmd apt-get update -qq && $sudo_cmd apt-get install -y $missing
  elif command -v dnf >/dev/null 2>&1; then
    echo "installing via dnf..."; $sudo_cmd dnf install -y $missing
  elif command -v brew >/dev/null 2>&1; then
    echo "installing via brew..."; brew install $missing
  else
    echo "install$missing manually, then re-run."; exit 1
  fi
fi

# --- locale check (agnoster's LC_CTYPE=en_US.UTF-8 + $'...' UTF-8 escapes need it) ---
# Minimized Ubuntu images (e.g. 26.04 server) often only generate C/C.UTF-8, so the
# theme's anonymous function dies with "character not in range" and the prompt is
# never defined -- you land on a bare shell instead of a themed one. macOS ships
# UTF-8 locales out of the box and has no locale-gen, so skip there.
if [ "$(uname -s)" = "Linux" ] && ! locale -a 2>/dev/null | grep -qiE '^en_US\.utf-?8$'; then
  echo "en_US.UTF-8 locale not found (needed by the agnoster prompt theme)"
  fix_locale="apt-get install -y locales && locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8"
  if [ -z "$can_install" ]; then
    echo "no sudo available; ask an admin to run: $fix_locale"
  elif ! command -v locale-gen >/dev/null 2>&1 && ! command -v apt-get >/dev/null 2>&1; then
    echo "no apt-get/locale-gen found; install a UTF-8 locale manually for your distro."
  else
    if ! command -v locale-gen >/dev/null 2>&1; then
      echo "installing locales package..."
      $sudo_cmd apt-get update -qq && $sudo_cmd apt-get install -y locales || echo "locales install failed; run manually: sudo $fix_locale"
    fi
    if command -v locale-gen >/dev/null 2>&1; then
      echo "generating en_US.UTF-8 locale..."
      $sudo_cmd locale-gen en_US.UTF-8 && $sudo_cmd update-locale LANG=en_US.UTF-8 \
        && echo "done -- start a new shell for it to take effect" \
        || echo "locale-gen failed; run manually: sudo $fix_locale"
    fi
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
  # When this script is piped (curl ... | bash), fd 0 is the pipe, not the
  # terminal.  chsh authenticates via PAM and reads the password from stdin,
  # so it would consume leftover pipe bytes and fail with a PAM auth error.
  # Reconnect its stdin to the controlling terminal; skip if there is none.
  if [ -e /dev/tty ]; then
    chsh -s "$zsh_path" < /dev/tty || echo "could not chsh; run: chsh -s $zsh_path"
  else
    echo "no tty; set it later with: chsh -s $zsh_path"
  fi
fi

echo
echo "dotfiles installed (version $(cat "$HOME/.config/zsh/.version"))."
echo "start a new shell, or run: exec zsh"
echo "update anytime with: dotupdate"
