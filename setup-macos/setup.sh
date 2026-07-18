#!/bin/bash --norc
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # sourced lib resolved at runtime via $script_dir
source "$script_dir/../bootstrap/ansible.sh"

# Homebrew is the macOS package manager the setup playbook drives; still needed.
if [ ! -f /opt/homebrew/bin/brew ]; then
  bash -c "$(curl -fsSL \
    https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# A fresh brew install is not yet on the login PATH; put it on PATH for this
# session so the playbook's homebrew tasks resolve `brew`.
for d in /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin; do
  [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
done
export PATH

ensure_uv

ansible_uvx ansible-galaxy collection install community.general --upgrade

if [ "$(id -u)" = 0 ]; then
  ansible_uvx ansible-playbook "$script_dir/setup.playbook.yml" "$@"
else
  ansible_uvx ansible-playbook "$script_dir/setup.playbook.yml" --ask-become-pass "$@"
fi
