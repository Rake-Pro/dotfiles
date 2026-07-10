# Changelog

All notable changes to this project. Format follows [Keep a Changelog]; versioning
is SemVer. The running version is served at `GET /version` and drives `dotupdate`.
Dates are YYYY-MM-DD.

## [0.2.2] - 2026-07-10
### Fixed
- `install.sh`: apt-get calls now wait up to 120s for the dpkg lock
  (`DPkg::Lock::Timeout`) instead of failing when first-boot
  unattended-upgrades holds it - fresh hosts lost this race every time.

## [0.2.1] - 2026-07-10
### Added
- `install.sh`: preflight `en_US.UTF-8` locale check (Linux only). Minimized
  Ubuntu images (e.g. 26.04 server) generate only `C`/`C.UTF-8`, which makes
  agnoster die with "character not in range" and leaves a bare unthemed prompt.
  With root/sudo the installer repairs it (`locales` package + `locale-gen` +
  `update-locale`); otherwise it prints the manual commands. Non-fatal in all
  paths.

### Fixed
- `install.sh`: `chsh` now reads from `/dev/tty` instead of the curl pipe, so
  PAM password auth works under `curl ... | bash`; skipped with a hint when no
  tty is available.
- `install.sh`: runs correctly as root on hosts without `sudo` installed; when
  neither root nor sudo, missing hard deps fail with a clear message instead of
  `sudo: command not found`.

## [0.2.0] - 2026-07-02
### Added
- Enabled vendored oh-my-zsh plugins in `.zshrc`: `kubectl`, `docker`,
  `docker-compose`, `sudo` (ESC ESC), `z`, `kubectx`, `colored-man-pages`,
  `command-not-found`, `history-substring-search`. All already in the payload -
  no new fetch.
- Vendored `zsh-autosuggestions` and `zsh-syntax-highlighting` into
  `payload/.oh-my-zsh/custom/plugins/` (offline; `.git` and test-data trimmed).
  Load order: autosuggestions -> syntax-highlighting -> history-substring-search
  (last, so its arrow-key bindings win). Tarball still ~6.4M gzip.

## [0.1.6] - 2026-07-02
### Changed
- Startup update check is now an interactive, oh-my-zsh-style prompt (`read -q`)
  that offers to apply an available update, instead of only printing a notice.
  Configurable via `DOTFILES_UPDATE_MODE` (prompt|auto|notify|disabled) and
  `DOTFILES_UPDATE_INTERVAL_DAYS` (default 1; 0 = every session). Interactive
  shells with a tty only.

## [0.1.5] - 2026-07-02
### Changed
- Bootstrap runs under `bash` instead of `/bin/sh` (shebangs, the `/` install
  hint, and README all use `| bash`). `bash` is present on every target host.
### Fixed
- Version-proofs against the dash 0.5.10 parser bug by no longer depending on the
  host's `/bin/sh`. Supersedes the 0.1.4 workaround.

## [0.1.4] - 2026-07-02
### Fixed
- `nuke.sh`: dropped nested quotes in `${path#"$HOME"/}` that Ubuntu 20.04's dash
  0.5.10 mis-parses at runtime ("done unexpected"). `dash -n` on newer dash did
  not catch it because the fault is a streamed-parse difference.

## [0.1.3] - 2026-07-02
### Fixed
- `nuke.sh` reads its confirm prompt from `/dev/tty`, so it works under
  `curl | ... ` instead of aborting on EOF when the script is the stdin.

## [0.1.2] - 2026-07-02
### Added
- `.zshrc` sources `~/.commonrc` if present (a host-local, unmanaged cross-shell
  PATH file), after the OS block so Homebrew's shellenv is already on PATH.

## [0.1.1] - 2026-07-02
### Removed
- Stripped oh-my-zsh dev cruft (`.github`, docs, images, editor configs; 395
  files). Payload 12M -> 6.6M. All plugin/theme `.zsh` and `LICENSE.txt` kept.
  Also removed the nested `.github` that was triggering dependency scans.

## [0.1.0] - 2026-07-02
### Added
- Initial self-hosted dotfiles. Go HTTP server (`main.go`) embeds `payload/` via
  `go:embed` and serves `/install`, `/nuke`, `/version`, `/dotfiles.tar.gz`, `/`.
  Base URL injected from the request host (honors `X-Forwarded-Proto`).
- Vendored oh-my-zsh + agnoster theme + MesloLGS NF fonts - fully offline; client
  deps are only `zsh`, `curl`, `tar`.
- `install.sh` (curl bootstrap + dep/font install), `nuke.sh` (backup-first
  cleanup of conflicting zsh frameworks), `dotupdate` self-update. Per-host/OS/k8s
  behavior via plain-shell fragments and marker files.
- Multi-arch (amd64/arm64) GHCR build via GitHub Actions; `docker-compose.yml`
  for homelb; distroless static image.

[Keep a Changelog]: https://keepachangelog.com/
