#!/usr/bin/env bash
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f /usr/bin/ansible-playbook ]; then
  sudo apt-get update
  sudo apt-get install --assume-yes ansible
fi

ansible-playbook "$script_dir/config.playbook.yml" \
  --extra-vars="dotfiles_src_dir=$script_dir/files" \
  --extra-vars="@$script_dir/config.vars.yml" \
  "$@"
