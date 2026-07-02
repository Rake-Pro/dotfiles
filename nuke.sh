#!/usr/bin/env bash
# nuke.sh -- clean a host of oh-my-zsh and other zsh frameworks/configs that would
# NOTE: pipe through bash, not sh:  curl -fsSL <base>/nuke | bash
# (Ubuntu 20.04's dash 0.5.10 mis-parses some constructs; bash is on every host.)
# conflict with our dotfiles, BEFORE running install. Everything it removes is first
# copied to a timestamped backup dir, so nothing is destroyed outright.
#
# Usage:
#   sh nuke.sh                 # show what would be removed, then confirm
#   sh nuke.sh -y              # no prompt (for automation)
#   sh nuke.sh -n              # dry-run: print, touch nothing
#   sh nuke.sh --purge-history # also remove ~/.zsh_history (kept by default)
#   sh nuke.sh --purge-fonts   # also remove vendored MesloLGS NF fonts
#
# Served by the dotfiles container at /nuke, so on a host you can:
#   curl -fsSL https://dotfiles.example.com/nuke | sh
set -eu

ASSUME_YES=0
DRY_RUN=0
PURGE_HISTORY=0
PURGE_FONTS=0

for arg in "$@"; do
  case "$arg" in
    -y|--yes)        ASSUME_YES=1 ;;
    -n|--dry-run)    DRY_RUN=1 ;;
    --purge-history) PURGE_HISTORY=1 ;;
    --purge-fonts)   PURGE_FONTS=1 ;;
    -h|--help)       sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# safety: never operate on an empty or root HOME
[ -n "${HOME:-}" ] || { echo "HOME is unset; refusing to run." >&2; exit 1; }
[ "$HOME" != "/" ] || { echo "HOME is /; refusing to run." >&2; exit 1; }

TS="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP="$HOME/.dotfiles-nuke-backup-$TS"

# Targets: zsh frameworks, plugin managers, prompts, and our own prior install.
# Directories and files alike; globs are expanded below.
TARGETS="
$HOME/.oh-my-zsh
$HOME/.zshrc
$HOME/.zshenv
$HOME/.zprofile
$HOME/.zlogin
$HOME/.zlogout
$HOME/.zshrc.pre-oh-my-zsh
$HOME/.config/zsh
$HOME/.p10k.zsh
$HOME/.zprezto
$HOME/.zpreztorc
$HOME/.zim
$HOME/.zimrc
$HOME/.zinit
$HOME/.local/share/zinit
$HOME/.antigen
$HOME/.antigenrc
$HOME/.zplug
$HOME/.zgen
$HOME/.zgenom
$HOME/.znap
$HOME/.config/starship.toml
"

# caches / compdumps (glob-expanded)
CACHE_GLOBS="
$HOME/.zcompdump*
$HOME/.cache/zsh
$HOME/.cache/p10k-*
$HOME/.cache/gitstatus
$HOME/.cache/prezto
"

# expand globs, keep only existing paths
expand() {
  for pat in $1; do
    for p in $pat; do
      [ -e "$p" ] && printf '%s\n' "$p"
    done
  done
}

REMOVE_LIST="$(
  { printf '%s\n' $TARGETS; expand "$CACHE_GLOBS"; } | while IFS= read -r p; do
    [ -n "$p" ] && [ -e "$p" ] && printf '%s\n' "$p"
  done
)"

# optional extras
[ "$PURGE_HISTORY" -eq 1 ] && [ -e "$HOME/.zsh_history" ] && \
  REMOVE_LIST="$REMOVE_LIST
$HOME/.zsh_history"
if [ "$PURGE_FONTS" -eq 1 ] && [ -d "$HOME/.local/share/fonts" ]; then
  for f in "$HOME/.local/share/fonts/"MesloLGS*; do
    [ -e "$f" ] && REMOVE_LIST="$REMOVE_LIST
$f"
  done
fi

if [ -z "$REMOVE_LIST" ]; then
  echo "Nothing to remove -- host is already clean."
  exit 0
fi

echo "The following will be backed up to:"
echo "  $BACKUP"
echo "and then removed:"
printf '%s\n' "$REMOVE_LIST" | sed 's/^/  - /'
echo
[ "$PURGE_HISTORY" -eq 1 ] || echo "(~/.zsh_history preserved; use --purge-history to remove)"
[ "$PURGE_FONTS" -eq 1 ]   || echo "(vendored fonts preserved; use --purge-fonts to remove)"

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "dry-run: nothing was changed."
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  # read from the terminal, not stdin -- so the prompt works under `curl | sh`
  if [ -r /dev/tty ]; then
    printf 'Proceed? [y/N] '
    read -r reply </dev/tty
  else
    echo "Non-interactive (piped) with no terminal. Re-run with -y to proceed," >&2
    echo "or: sh nuke.sh   (after downloading it)." >&2
    exit 1
  fi
  case "$reply" in
    y|Y) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

# revert login shell if oh-my-zsh recorded the previous one
if [ -f "$HOME/.shell.pre-oh-my-zsh" ] && command -v chsh >/dev/null 2>&1; then
  old_shell="$(cat "$HOME/.shell.pre-oh-my-zsh")"
  if [ -n "$old_shell" ] && [ -x "$old_shell" ]; then
    echo "Reverting login shell to $old_shell"
    chsh -s "$old_shell" 2>/dev/null && rm -f "$HOME/.shell.pre-oh-my-zsh" \
      || echo "  (could not chsh; do it manually)"
  fi
fi

mkdir -p "$BACKUP"
printf '%s\n' "$REMOVE_LIST" | while IFS= read -r path; do
  [ -e "$path" ] || continue
  rel="${path#$HOME/}"
  dir=$(dirname "$rel")
  dest_dir="$BACKUP/$dir"
  mkdir -p "$dest_dir"
  cp -a "$path" "$dest_dir/" 2>/dev/null || cp -R "$path" "$dest_dir/"
  rm -rf "$path"
  echo "removed $path"
done

echo
echo "Done. Backup saved at: $BACKUP"
echo "Now install with:  curl -fsSL <your-dotfiles-url>/install | sh"
