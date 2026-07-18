#!/bin/bash --norc
set -euo pipefail

# bootstrap.sh -- provision a bare machine and delegate to the right setup/config.
#
# One-shot remote use (bare machine):
#   curl -fsSL https://raw.githubusercontent.com/chpatton013/dotfiles2/main/bootstrap.sh | bash
#
# Local use (from an existing clone), re-runnable/idempotent:
#   ./bootstrap.sh [--options] [-- <args passed to setup.sh/config.sh>]
#
# See docs/plans/bootstrap-script.md for the design rationale.

# --- configuration (override via environment) --------------------------------

DOTFILES_REPO="${DOTFILES_REPO:-chpatton013/dotfiles2}"
DOTFILES_HTTPS_REPO="${DOTFILES_HTTPS_REPO:-"https://github.com/$DOTFILES_REPO.git"}"
DOTFILES_SSH_REPO="${DOTFILES_SSH_REPO:-"git@github.com:$DOTFILES_REPO.git"}"
DOTFILES_REF="${DOTFILES_REF:-main}"
DOTFILES_DIR="${DOTFILES_DIR:-"$HOME/github/$DOTFILES_REPO"}"
# Depth 1 (shallow, single-branch) by default; set 0 for a full clone.
DOTFILES_CLONE_DEPTH="${DOTFILES_CLONE_DEPTH:-1}"

# Raw-file base for fetching this repo's dotslash manifests before the repo is
# cloned (remote mode).
DOTFILES_RAW_BASE="${DOTFILES_RAW_BASE:-"https://raw.githubusercontent.com/$DOTFILES_REPO/$DOTFILES_REF"}"

TOOL_BIN_DIR="${TOOL_BIN_DIR:-"${XDG_BIN_HOME:-"$HOME/.local/bin"}"}"

# SSH key generated/used by --ssh (override for a differently-named key).
SSH_KEY="${SSH_KEY:-"$HOME/.ssh/id_ed25519"}"

# dotslash runtime: we pin uv through a committed dotslash manifest
# (bootstrap/dotslash/uv). The dotslash runtime itself is the single bootstrap
# tool that cannot be a dotslash file (chicken/egg), so it is fetched directly.
DOTSLASH_VERSION="${DOTSLASH_VERSION:-v0.5.6}"
DOTSLASH_BIN_DIR="${DOTSLASH_BIN_DIR:-"$TOOL_BIN_DIR"}"
# Full override for the dotslash release tarball URL (asset names vary by
# release; override if the computed default 404s on your box).
DOTSLASH_URL="${DOTSLASH_URL:-}"

# uv installs tools into the XDG bin dir; make sure it is on PATH after install.
UV_BIN_DIR="${UV_BIN_DIR:-"$TOOL_BIN_DIR"}"

# --- flags -------------------------------------------------------------------

USE_SSH=0
DRY_RUN=0
DO_SETUP=1
DO_CONFIG=1
PASSTHROUGH=()

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [options] [-- <extra args for setup.sh and config.sh>]

Provisions a bare machine: acquires git + uv-backed ansible, clones this repo,
shims the Homebrew bin dir onto PATH (macOS), then runs the platform
setup-<os>/setup.sh followed by config/config.sh.

Options:
  --ssh           Clone over SSH; generate an ed25519 key if absent and print
                  the public key for manual add to GitHub (no API upload).
  --setup-only    Run only the platform setup phase.
  --config-only   Run only the config phase.
  --dry-run       Print what would run; make no changes and skip the applies.
  -h, --help      Show this help.

Anything after `--` is forwarded verbatim to setup-<os>/setup.sh and
config/config.sh (e.g. `-- --check --diff` or `-- --tags neovim`).

Environment overrides: DOTFILES_DIR, DOTFILES_REPO, DOTFILES_REF,
DOTFILES_CLONE_DEPTH (0 = full clone), TOOL_BIN_DIR, SSH_KEY,
DOTSLASH_VERSION, DOTSLASH_URL. See the top of this file.
EOF
}

# --- helpers -----------------------------------------------------------------

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Run a command, or just print it under --dry-run.
run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '  [dry-run] %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

have() { command -v "$1" >/dev/null 2>&1; }

# Download helpers: dispatch to curl or wget, whichever is present. curl/wget is
# the one true bootstrap dependency (everything else is fetched with these).
fetch_stdout() {
  local url="$1"
  if have curl; then curl -fsSL "$url"
  elif have wget; then wget -qO- "$url"
  else die "neither curl nor wget is available (one is required to bootstrap)"; fi
}
fetch_file() {
  local url="$1" out="$2"
  if have curl; then curl -fsSL "$url" -o "$out"
  elif have wget; then wget -q "$url" -O "$out"
  else die "neither curl nor wget is available (one is required to bootstrap)"; fi
}

# --- steps -------------------------------------------------------------------

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --ssh) USE_SSH=1 ;;
      --setup-only) DO_CONFIG=0 ;;
      --config-only) DO_SETUP=0 ;;
      --dry-run) DRY_RUN=1 ;;
      -h|--help) usage; exit 0 ;;
      --) shift; PASSTHROUGH=("$@"); break ;;
      *) die "unknown option: $1 (use -- to forward args to setup/config)" ;;
    esac
    shift
  done
}

# Sets OS and ARCH globals.
detect_os() {
  local uname_s uname_m
  uname_s="$(uname -s)"
  uname_m="$(uname -m)"

  case "$uname_s" in
    Darwin) OS=macos ;;
    Linux)
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-} ${ID_LIKE:-}" in
          *arch*)          OS=archlinux ;;
          *ubuntu*|*debian*) OS=ubuntu ;;
          *) die "unsupported Linux distro: ID=${ID:-?} ID_LIKE=${ID_LIKE:-?} (supported: ubuntu/debian, arch)" ;;
        esac
      else
        die "cannot read /etc/os-release; unable to detect Linux distro"
      fi
      ;;
    *) die "unsupported OS: $uname_s (supported: Darwin, Linux)" ;;
  esac

  case "$uname_m" in
    arm64|aarch64) ARCH=aarch64 ;;
    x86_64|amd64)  ARCH=x86_64 ;;
    *) die "unsupported architecture: $uname_m" ;;
  esac

  log "detected OS=$OS ARCH=$ARCH"
}

# Prepend $1 to PATH if not already present (and, when $2 is "if-dir", only if it
# exists on disk).
prepend_path() {
  local d="$1" guard="${2:-}"
  [ -n "$d" ] || return 0
  [ "$guard" = if-dir ] && [ ! -d "$d" ] && return 0
  case ":$PATH:" in
    *":$d:"*) ;;                 # already present
    *) PATH="$d:$PATH" ;;
  esac
}

# Put the dirs where our tools land onto PATH for this process. Fixes "brew
# cellar isn't on PATH at provision time" on macOS, and makes dotslash-/uv-
# installed binaries resolvable in the same session.
shim_path() {
  # Homebrew's cellar is macOS-specific; the brew dirs do not exist on Linux, so
  # gate them on the OS rather than relying on the on-disk guard.
  if [ "${OS:-}" = macos ]; then
    prepend_path /usr/local/bin if-dir      # Intel Homebrew
    prepend_path /opt/homebrew/sbin if-dir
    prepend_path /opt/homebrew/bin if-dir   # Apple Silicon Homebrew (highest priority)
  fi
  # Our own tool bin dirs (dotslash runtime, dotslash shims, uv-installed tools).
  # We create these ourselves, so add them unconditionally; deduped if equal.
  prepend_path "$DOTSLASH_BIN_DIR"
  prepend_path "$UV_BIN_DIR"
  prepend_path "$TOOL_BIN_DIR"
  export PATH
}

# Provision a tool from its committed dotslash manifest into TOOL_BIN_DIR.
# Returns 0 on success; 1 if dotslash or a *populated* manifest is unavailable
# (the manifests ship as scaffolds until real pins are filled in), so callers
# fall back. In remote mode the manifest is fetched from the repo over
# curl/wget, keeping curl/wget the only hard dependency.
dotslash_tool() {
  local name="$1" dest="$TOOL_BIN_DIR/$1" manifest cleanup=0
  have dotslash || return 1

  if [ -n "${REPO_DIR:-}" ] && [ -f "$REPO_DIR/bootstrap/dotslash/$name" ]; then
    manifest="$REPO_DIR/bootstrap/dotslash/$name"
  elif [ "$DRY_RUN" = 1 ]; then
    return 1                      # skip the remote manifest fetch under --dry-run
  else
    manifest="$(mktemp)"; cleanup=1
    if ! fetch_file "$DOTFILES_RAW_BASE/bootstrap/dotslash/$name" "$manifest"; then
      rm -f "$manifest"; return 1
    fi
  fi

  if ! manifest_populated "$manifest"; then
    [ "$cleanup" = 1 ] && rm -f "$manifest"
    return 1
  fi

  log "provisioning $name via dotslash manifest"
  run mkdir -p "$TOOL_BIN_DIR"
  run install -m 0755 "$manifest" "$dest"
  [ "$cleanup" = 1 ] && rm -f "$manifest"
  run dotslash -- fetch "$dest" >/dev/null   # warm the dotslash cache
  shim_path
  have "$name"
}

# Ensure git is available. Prefer dotslash (the goal is that curl/wget is the
# only hard dependency and everything else comes through dotslash); fall back to
# a system git, then to OS-native install. Once bootstrap/dotslash/git carries
# real pins, the dotslash path handles this on a bare box with no system git.
ensure_git() {
  if dotslash_tool git; then
    return 0
  fi
  if have git; then
    log "using system git ($(command -v git))"
    return 0
  fi
  log "git not found and no populated dotslash manifest; attempting native install"
  case "$OS" in
    macos)
      # Prefer Homebrew if it is already installed; otherwise fall back to the
      # Xcode Command Line Tools (interactive GUI prompt).
      if have brew; then
        run brew install git
      else
        run xcode-select --install || true
        die "git is unavailable. Install the Xcode Command Line Tools (a dialog \
should have opened) or Homebrew, then re-run bootstrap.sh."
      fi
      ;;
    ubuntu)
      run sudo apt-get update
      run sudo apt-get install -y git
      ;;
    archlinux)
      run sudo pacman --sync --refresh --noconfirm git
      ;;
  esac
  have git || die "git is still unavailable after install attempt"
}

# Install the dotslash runtime binary if absent.
install_dotslash() {
  if have dotslash; then
    log "dotslash already installed: $(command -v dotslash)"
    return 0
  fi

  local os_tag url tmp
  case "$OS" in
    macos)  os_tag="macos" ;;
    *)      os_tag="linux-musl" ;;
  esac

  if [ -n "$DOTSLASH_URL" ]; then
    url="$DOTSLASH_URL"
  else
    url="https://github.com/facebook/dotslash/releases/download/${DOTSLASH_VERSION}/dotslash-${os_tag}.${DOTSLASH_VERSION}.tar.gz"
  fi

  log "installing dotslash ${DOTSLASH_VERSION} from ${url}"
  run mkdir -p "$DOTSLASH_BIN_DIR"
  if [ "$DRY_RUN" = 1 ]; then
    printf '  [dry-run] curl -LsSf %s | tar -> %s/dotslash\n' "$url" "$DOTSLASH_BIN_DIR" >&2
    return 0
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  if ! fetch_file "$url" "$tmp/dotslash.tar.gz"; then
    warn "could not download dotslash from $url"
    warn "override the URL with DOTSLASH_URL=... (asset names vary per release)"
    return 1
  fi
  tar -xzf "$tmp/dotslash.tar.gz" -C "$tmp"
  install -m 0755 "$tmp/dotslash" "$DOTSLASH_BIN_DIR/dotslash"
  have dotslash || die "dotslash installed to $DOTSLASH_BIN_DIR but not on PATH"
}

# Ensure uv is available. Prefer the committed dotslash manifest (pinned +
# hash-verified); fall back to uv's official installer if the manifest is not
# populated or dotslash is unavailable.
ensure_uv() {
  if have uv; then
    log "uv already installed: $(command -v uv)"
    return 0
  fi

  if dotslash_tool uv; then
    return 0
  fi

  warn "no populated dotslash uv manifest; using uv's official installer"
  if [ "$DRY_RUN" = 1 ]; then
    printf '  [dry-run] fetch https://astral.sh/uv/install.sh | sh\n' >&2
  else
    fetch_stdout https://astral.sh/uv/install.sh | sh
  fi

  shim_path
  have uv || { [ "$DRY_RUN" = 1 ] && return 0; die "uv is still unavailable"; }
}

# A dotslash manifest is "populated" if the committed placeholder markers have
# been replaced with real pins (URL version + digest).
manifest_populated() {
  ! grep -q 'REPLACE_ME\|REPLACE_VERSION' "$1" 2>/dev/null
}

# Generate + print an ed25519 key for manual add to GitHub (no API upload).
maybe_ssh_key() {
  [ "$USE_SSH" = 1 ] || return 0
  # Key path is overridable via SSH_KEY (defaults to ~/.ssh/id_ed25519) for
  # setups that use specifically-named keys loaded via ssh config.
  local key="$SSH_KEY"
  if [ ! -f "$key" ]; then
    log "generating ed25519 SSH key at $key"
    run mkdir -p "$(dirname "$key")"
    run chmod 700 "$(dirname "$key")"
    # ssh-keygen ships with OpenSSH, part of the base system on every platform we
    # target, so it is not a dotslash candidate (OpenSSH is not distributed as a
    # single prebuilt binary the way uv/dotslash tools are).
    run ssh-keygen -t ed25519 -N '' -f "$key" -C "$(whoami)@$(hostname)"
  fi
  if [ "$DRY_RUN" != 1 ] && [ -f "$key.pub" ]; then
    log "add this public key to GitHub (https://github.com/settings/keys):"
    cat "$key.pub" >&2
    if [ -t 0 ]; then
      printf 'Press Enter once the key is added to continue...' >&2
      read -r _
    else
      warn "non-interactive: continuing; SSH clone will fail until the key is added"
    fi
  fi
}

# Clone the repo (idempotent). Sets REPO_DIR. Never auto-pulls an existing clone.
ensure_repo() {
  local repo_url="$DOTFILES_HTTPS_REPO"
  [ "$USE_SSH" = 1 ] && repo_url="$DOTFILES_SSH_REPO"

  if [ -d "$DOTFILES_DIR/.git" ]; then
    log "repo already present at $DOTFILES_DIR (not auto-pulling)"
  else
    # Shallow, single-branch by default (DOTFILES_CLONE_DEPTH); set depth 0 for a
    # full clone. Unshallow later with `git -C "$DOTFILES_DIR" fetch --unshallow`.
    local depth_args=()
    if [ "$DOTFILES_CLONE_DEPTH" -gt 0 ] 2>/dev/null; then
      depth_args=(--depth "$DOTFILES_CLONE_DEPTH" --single-branch)
    fi
    log "cloning $repo_url -> $DOTFILES_DIR (ref: $DOTFILES_REF, depth: $DOTFILES_CLONE_DEPTH)"
    run mkdir -p "$(dirname "$DOTFILES_DIR")"
    run git clone --branch "$DOTFILES_REF" ${depth_args[@]+"${depth_args[@]}"} "$repo_url" "$DOTFILES_DIR"
  fi
  REPO_DIR="$DOTFILES_DIR"
}

# Delegate to the existing entrypoints, forwarding passthrough args.
delegate() {
  local setup_sh="$REPO_DIR/setup-$OS/setup.sh"
  local config_sh="$REPO_DIR/config/config.sh"

  if [ "$DO_SETUP" = 1 ]; then
    [ -x "$setup_sh" ] || die "missing platform setup script: $setup_sh"
    log "running platform setup: $setup_sh"
    run "$setup_sh" ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}
  else
    warn "skipping platform setup (--config-only); run $setup_sh yourself if needed"
  fi
  if [ "$DO_CONFIG" = 1 ]; then
    [ -x "$config_sh" ] || die "missing config script: $config_sh"
    log "running config: $config_sh"
    run "$config_sh" ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}
  else
    warn "skipping config (--setup-only); run $config_sh yourself if needed"
  fi
}

# --- main --------------------------------------------------------------------

main() {
  parse_args "$@"
  detect_os
  shim_path

  # Where does this running script live? In remote (curl|bash) mode there is no
  # repo around us, so BASH_SOURCE points at the pipe; fall back to cwd.
  local src self_dir
  src="${BASH_SOURCE[0]:-$0}"
  if ! self_dir="$(builtin cd "$(dirname "$src")" 2>/dev/null && pwd)"; then
    self_dir="$PWD"
  fi

  # Local mode: we are already inside the repo -> use it directly.
  if [ -f "$self_dir/config/config.sh" ] && [ -d "$self_dir/setup-$OS" ]; then
    REPO_DIR="$self_dir"
    # dotslash first, so git (and everything else) can come through it.
    install_dotslash || warn "dotslash unavailable; tools will fall back to native installers"
    ensure_git
    # uv is enough: the setup/config entrypoints self-provision ansible via uvx.
    ensure_uv
    delegate
    log "bootstrap complete"
    return 0
  fi

  # Remote mode: install dotslash, acquire git, clone, then re-exec the on-disk
  # copy so the rest runs with the repo present (committed manifests available).
  log "remote mode: no repo alongside this script; bootstrapping into $DOTFILES_DIR"
  install_dotslash || warn "dotslash unavailable; tools will fall back to native installers"
  ensure_git
  maybe_ssh_key
  ensure_repo

  if [ "$DRY_RUN" = 1 ]; then
    log "dry-run: would re-exec $REPO_DIR/bootstrap.sh"
    return 0
  fi
  log "re-executing on-disk bootstrap.sh"
  exec "$REPO_DIR/bootstrap.sh" "$@"
}

main "$@"
