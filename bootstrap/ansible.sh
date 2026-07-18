#!/bin/bash --norc
#
# Shared helper: run ansible through uv (uvx) instead of a system/brew ansible.
# Sourced by config/config.sh and setup-*/setup.sh; assumes the caller has
# already set `set -euo pipefail`. See docs/plans/bootstrap-script.md.

# Package uvx runs ansible from. The `ansible` community bundle bundles
# community.general (used by the flatpak roles); override for a leaner env
# (e.g. ANSIBLE_UVX_FROM=ansible-core with a separate galaxy install).
ANSIBLE_UVX_FROM="${ANSIBLE_UVX_FROM:-ansible}"

# Where uv's standalone installer places `uv`/`uvx`.
_ansible_bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"

_ansible_have() { command -v "$1" >/dev/null 2>&1; }

# Ensure `uv`/`uvx` are available; install via the official installer if not.
# curl or wget is the only hard prerequisite (matches bootstrap.sh).
ensure_uv() {
  if _ansible_have uvx; then
    return 0
  fi

  echo "uv/uvx not found; installing uv via the official installer..." >&2
  if _ansible_have curl; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  elif _ansible_have wget; then
    wget -qO- https://astral.sh/uv/install.sh | sh
  else
    echo "error: need curl or wget to install uv." >&2
    echo "Install uv manually (https://docs.astral.sh/uv/) and re-run." >&2
    return 1
  fi

  case ":$PATH:" in
    *":$_ansible_bin_dir:"*) ;;
    *) PATH="$_ansible_bin_dir:$PATH"; export PATH ;;
  esac

  if ! _ansible_have uvx; then
    echo "error: uv installed but uvx is not on PATH ($_ansible_bin_dir)." >&2
    return 1
  fi
}

# Run an ansible-* command (ansible-playbook, ansible-galaxy, ...) via uvx.
ansible_uvx() {
  uvx --from "$ANSIBLE_UVX_FROM" "$@"
}
