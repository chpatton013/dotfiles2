#!/bin/bash --norc
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ansible-galaxy collection install community.general --upgrade

ansible-playbook "$script_dir/config.playbook.yml" \
  --extra-vars="dotfiles_src_dir=$script_dir/files" \
  --extra-vars="@$script_dir/config.vars.yml" \
  "$@"
