# Backlog

Deferred ideas, not yet started.

## Hybrid Tab accept for autosuggestions
Bind Tab so it accepts the autosuggestion when one is showing, else completes as
normal. Preferred variant: **word-wise** (Tab pulls in one word of the ghost at a
time), gated behind an env var `DOTFILES_TAB_ACCEPT=word|full|off` (default a host
can flip instantly; fully reversible via `dotupdate`).

Known downsides to weigh before building:
- Suggestions are present most of the time once history is warm, so Tab becomes
  "accept" the majority of the time and real completion gets demoted. (Main risk.)
- Breaks Tab-cycling-through-the-completion-menu rhythm.
- Shadows path/partial completion while a suggestion is showing.
- Would conflict with fzf-tab if fzf is ever added.

Status: parked at user's request (not exploring yet).

## Other parked items
- Delete the gitignored, superseded chezmoi scaffold files from disk.
- Decide zerolog vs stdlib slog for the server (cosmetic; no functional impact).
- Optional adds discussed but not chosen: kube-ps1 in prompt, fzf fuzzy finder,
  managed .gitconfig / .gitignore_global / .vimrc / .tmux.conf.
