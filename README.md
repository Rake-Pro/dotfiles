# dotfiles

Self-hosted dotfiles. One container you own serves an install script, a payload
tarball, and a version stamp. No chezmoi, and nothing in the client path reaches
GitHub or any third party: oh-my-zsh, the agnoster theme, and the MesloLGS NF font
are all vendored into the payload and served from your own box. Client
dependencies: `zsh`, `curl`, `tar`.

## Bootstrap a new host

```
curl -fsSL https://dotfiles.example.com/install | bash
```

The server rewrites the script's base URL to its own hostname, so the installed
config knows where to pull updates from. Missing `zsh`/`curl`/`tar` are installed
via apt/dnf/brew automatically. A missing `en_US.UTF-8` locale (common on
minimized Ubuntu images, and required by the agnoster theme) is detected and
repaired the same way.

## Clean a host first (optional)

If a host already has oh-my-zsh or another zsh framework, wipe the conflicts before
installing. `nuke.sh` backs up everything to `~/.dotfiles-nuke-backup-<timestamp>/`
first, then removes it.

```
curl -fsSL https://dotfiles.example.com/nuke | bash      # prompts, then cleans
curl -fsSL https://dotfiles.example.com/nuke | bash -s -- -n   # dry-run, changes nothing
```

Flags: `-y` (no prompt), `-n` (dry-run), `--purge-history` (also remove
`~/.zsh_history`, kept by default), `--purge-fonts`. It targets oh-my-zsh, prezto,
zinit, antigen, zplug, zim, zgenom, znap, powerlevel10k, starship, zsh rc/env
files, compdumps, and our own prior install. It reverts the login shell if
oh-my-zsh recorded the previous one.

## Update

```
dotupdate
```

Pulls the tarball if the server's `/version` is newer than the local stamp, then
reloads (`exec zsh`). On an interactive shell start, a throttled check offers to
apply an available update, oh-my-zsh style - behavior is configurable below.

## Configuration

Environment variables (export before `.zshrc` loads them, e.g. in `~/.commonrc`):

| Variable | Default | Effect |
|----------|---------|--------|
| `DOTFILES_URL` | set at install | Server base URL. The installer writes it to `~/.config/zsh/.dotfiles_url`. |
| `DOTFILES_UPDATE_MODE` | `prompt` | `prompt` (ask on shell start), `auto` (apply silently), `notify` (print only), `disabled`. |
| `DOTFILES_UPDATE_INTERVAL_DAYS` | `1` | Days between startup update checks. `0` = every session. |

Per-host markers (files, not env):

- `touch ~/.config/zsh/.is_k8s` - load `k8s.zsh` (kubectl aliases) on this host.
- `~/.config/zsh/hosts/<hostname>.zsh` - a fragment sourced only on that host.

See `CHANGELOG.md` for version history and `BACKLOG.md` for parked ideas.

## Layout

```
main.go                 Go HTTP server (embeds payload + install.sh + VERSION)
VERSION                 release stamp; bump before `make release`
install.sh              bootstrap script (served at /install, @@BASE@@ injected)
nuke.sh                 pre-install cleanup, backs up then removes (served at /nuke)
payload/                everything that lands in $HOME
  .zshrc                loads vendored oh-my-zsh + agnoster, then the fragments
  .zshenv
  .oh-my-zsh/           VENDORED oh-my-zsh (auto-update disabled; no .git)
  .local/share/fonts/   VENDORED MesloLGS NF (agnoster's font)
  .config/zsh/
    aliases.zsh         shared
    functions.zsh       shared (mkcd, extract)
    update.zsh          dotupdate + daily check
    macos.zsh           darwin only
    linux.zsh           linux only (docker aliases)
    k8s.zsh             loaded only if ~/.config/zsh/.is_k8s exists
    hosts/<host>.zsh    optional per-host fragment
    prompt.zsh          UNUSED fallback: hand-rolled prompt for a no-OMZ host
    completion.zsh      UNUSED fallback: zsh builtin compinit
Dockerfile              distroless static image
docker-compose.yml      run on docker-host
Makefile                run / build / docker / release
CHANGELOG.md            version history (Keep a Changelog)
BACKLOG.md              deferred ideas, not yet started
```

Deployed on docker-host via GitOps: `Rake-Pro/ops-repo` -> `docker-host/dotfiles/`.

## Server endpoints

| Route              | Purpose                                      |
|--------------------|----------------------------------------------|
| `/install`         | bootstrap script, base URL injected          |
| `/nuke`            | pre-install cleanup script                   |
| `/dotfiles.tar.gz` | payload as gzip tar, paths relative to `$HOME`|
| `/version`         | current version stamp                        |
| `/`                | health + install hint                        |

## Plugins

All vendored, loaded via `plugins=()` in `.zshrc` (offline, no runtime fetch):
core oh-my-zsh - `git kubectl docker docker-compose sudo z kubectx
colored-man-pages command-not-found history-substring-search`; plus externally
vendored under `custom/plugins/` - `zsh-autosuggestions` (fish-style ghost
completion) and `zsh-syntax-highlighting` (must load second-to-last;
history-substring-search loads last so its arrow-key bindings win).

## Per-host differences

Plain shell in `.zshrc`, keyed on `uname`, `hostname -s`, and marker files:

- OS: `macos.zsh` / `linux.zsh` by `uname`.
- Host: drop a `hosts/<hostname>.zsh` fragment for machine-specific config.
- Role: `touch ~/.config/zsh/.is_k8s` on cluster nodes / docker-host to load `k8s.zsh`.

## Deploy

Local (docker-host): `docker compose up -d`, publish behind your proxy as
`dotfiles.example.com` (proxy sets `X-Forwarded-Proto: https` so `/install` emits the
https URL). Release a new version: bump `VERSION`, `make release` (builds + pushes
to GHCR); the cluster/GitOps flow can consume the same image later.

## Provenance

`k8s.zsh` carries the kubectl aliases from the abandoned 2021 `Rake-Pro/old-dotfiles-repo`
repo, with the debug image off EOL Ubuntu Focal, an alias typo fixed, and the
third-party `complete-alias` completion replaced by zsh-native `kubectl completion
zsh` + `compdef`.
