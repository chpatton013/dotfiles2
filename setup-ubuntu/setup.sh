#!/bin/bash --norc
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # sourced lib resolved at runtime via $script_dir
source "$script_dir/../bootstrap/ansible.sh"

ensure_uv

ansible_uvx ansible-galaxy collection install community.general --upgrade

if [ "$(id --user)" = 0 ]; then
  ansible_uvx ansible-playbook "$script_dir/setup.playbook.yml" "$@"
else
  ansible_uvx ansible-playbook "$script_dir/setup.playbook.yml" --ask-become-pass "$@"
fi
