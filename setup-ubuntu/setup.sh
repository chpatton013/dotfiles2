#!/usr/bin/env bash
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f /usr/bin/ansible-playbook ]; then
  sudo apt-get update
  sudo apt-get install --assume-yes ansible
fi

if [ "$(id --user)" = 0 ]; then
  ansible-playbook "$script_dir/setup.playbook.yml" "$@"
else
  ansible-playbook "$script_dir/setup.playbook.yml" --ask-become-pass "$@"
fi
