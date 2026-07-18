#!/bin/bash --norc
#
# Shared helper: run ansible through uv (uvx) instead of a system/brew ansible.
# Sourced by config/config.sh and setup-*/setup.sh; assumes the caller has
# already set `set -euo pipefail`. See docs/plans/bootstrap-script.md.

# Package uvx runs ansible from. Use ansible-core: it provides the ansible-*
# executables (ansible-playbook, ansible-galaxy, ...); the `ansible` community
# bundle does NOT expose those as uvx entrypoints (uvx warns and can't find
# ansible-galaxy). Collections (community.general, kewlfft.aur) are installed
# separately by the entrypoints' ansible-galaxy step.
ANSIBLE_UVX_FROM="${ANSIBLE_UVX_FROM:-ansible-core}"

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

# Interpreter uvx runs ansible under. Unset by default, so uvx uses its own
# standalone Python.
#
# Escape hatch for restrictive networks: uv's standalone Python bundles a strict
# OpenSSL that can reject a TLS-inspection proxy's re-signed certificate chain
# (e.g. an intermediate missing the Authority Key Identifier extension) with a
# CERTIFICATE_VERIFY_FAILED error, breaking ansible-galaxy's HTTPS even when
# system tools like curl succeed. This is X.509 chain strictness, not trust, so
# a CA bundle / SSL_CERT_FILE does not help. On such a network, set
# ANSIBLE_UVX_PYTHON to a more lenient interpreter already configured for that
# environment (commonly the OS system python) to run ansible under it.
ANSIBLE_UVX_PYTHON="${ANSIBLE_UVX_PYTHON:-}"

# Run an ansible-* command (ansible-playbook, ansible-galaxy, ...) via uvx.
ansible_uvx() {
  if [ -x "$ANSIBLE_UVX_PYTHON" ]; then
    uvx --python "$ANSIBLE_UVX_PYTHON" --from "$ANSIBLE_UVX_FROM" "$@"
  else
    uvx --from "$ANSIBLE_UVX_FROM" "$@"
  fi
}
