#!/bin/bash --norc
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f /opt/homebrew/bin/brew ]; then
  bash -c "$(curl -fsSL \
    https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

if [ ! -f /opt/homebrew/bin/ansible-playbook ]; then
  brew install ansible
fi

if [ "$(id -u)" = 0 ]; then
  ansible-playbook "$script_dir/setup.playbook.yml" "$@"
else
  ansible-playbook "$script_dir/setup.playbook.yml" --ask-become-pass "$@"
fi
