#!/usr/bin/env bash
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ansible-playbook "$script_dir/config.playbook.yml" \
  --extra-vars="dotfiles_src_dir=$script_dir/files" \
  --extra-vars="@$script_dir/config.vars.yml" \
  "$@"
