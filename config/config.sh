#!/bin/bash --norc
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # sourced lib resolved at runtime via $script_dir
source "$script_dir/../bootstrap/ansible.sh"

ensure_uv

ansible_uvx ansible-galaxy collection install community.general --upgrade

ansible_uvx ansible-playbook "$script_dir/config.playbook.yml" \
  --extra-vars="dotfiles_src_dir=$script_dir/files" \
  --extra-vars="@$script_dir/config.vars.yml" \
  "$@"
