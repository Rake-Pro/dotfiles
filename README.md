# dotfiles

Self-hosted dotfiles. One container you own serves an install script, a payload
tarball, and a version stamp. No chezmoi, and nothing in the client path reaches
GitHub or any third party: oh-my-zsh, the agnoster theme, and the MesloLGS NF font
are all vendored into the payload and served from your own box. Client
dependencies: `zsh`, `curl`, `tar`.

## Bootstrap a new host

```
curl -fsSL https://dotfiles.rake.pro/install | sh
```

The server rewrites the script's base URL to its own hostname, so the installed
config knows where to pull updates from. Missing `zsh`/`curl`/`tar` are installed
via apt/dnf/brew automatically.

## Clean a host first (optional)

If a host already has oh-my-zsh or another zsh framework, wipe the conflicts before
installing. `nuke.sh` backs up everything to `~/.dotfiles-nuke-backup-<timestamp>/`
first, then removes it.

```
curl -fsSL https://dotfiles.rake.pro/nuke | sh        # prompts, then cleans
curl -fsSL https://dotfiles.rake.pro/nuke | sh -s -- -n   # dry-run, changes nothing
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

Compares the local version stamp to `GET /version`; if newer, pulls the tarball
and reloads. A once-a-day non-blocking check prints a notice on shell start (never
auto-applies).

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
docker-compose.yml      run on homelb
Makefile                run / build / docker / release
```

## Server endpoints

| Route              | Purpose                                      |
|--------------------|----------------------------------------------|
| `/install`         | bootstrap script, base URL injected          |
| `/nuke`            | pre-install cleanup script                   |
| `/dotfiles.tar.gz` | payload as gzip tar, paths relative to `$HOME`|
| `/version`         | current version stamp                        |
| `/`                | health + install hint                        |

## Per-host differences

Plain shell in `.zshrc`, keyed on `uname`, `hostname -s`, and marker files:

- OS: `macos.zsh` / `linux.zsh` by `uname`.
- Host: drop a `hosts/<hostname>.zsh` fragment for machine-specific config.
- Role: `touch ~/.config/zsh/.is_k8s` on cluster nodes / homelb to load `k8s.zsh`.

## Deploy

Local (homelb): `docker compose up -d`, publish behind your proxy as
`dotfiles.rake.pro` (proxy sets `X-Forwarded-Proto: https` so `/install` emits the
https URL). Release a new version: bump `VERSION`, `make release` (builds + pushes
to GHCR); the cluster/GitOps flow can consume the same image later.

## Provenance

`k8s.zsh` carries the kubectl aliases from the abandoned 2021 `Rake-Pro/settingsync`
repo, with the debug image off EOL Ubuntu Focal, an alias typo fixed, and the
third-party `complete-alias` completion replaced by zsh-native `kubectl completion
zsh` + `compdef`.
