#!/usr/bin/env bash
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mirrorlist_params="country=US&protocol=https&use_mirror_status=on"
curl --silent "https://www.archlinux.org/mirrorlist/?$mirrorlist_params" |
  sed --expression 's/^#Server/Server/' >/etc/pacman.d/mirrorlist

if [ ! -f /usr/bin/python3 ]; then
  sudo pacman --sync --refresh --noconfirm python
fi

if [ ! -f /usr/bin/pip3 ]; then
  sudo pacman --sync --refresh --noconfirm python-pip
fi

echo Installing Python Packages... >&2
pip3 install --requirement "$script_dir/requirements.txt"

echo Installing Ansible Roles... >&2
ansible-galaxy role install --role-file "$script_dir/requirements.yml"

if [ "$(id --user)" = 0 ]; then
  ansible-playbook "$script_dir/setup.playbook.yml" "$@"
else
  ansible-playbook "$script_dir/setup.playbook.yml" --ask-become-pass "$@"
fi
