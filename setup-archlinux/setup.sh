#!/bin/bash --norc
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # sourced lib resolved at runtime via $script_dir
source "$script_dir/../bootstrap/ansible.sh"

mirrorlist_params="country=US&protocol=https&use_mirror_status=on"
curl --silent "https://www.archlinux.org/mirrorlist/?$mirrorlist_params" |
  sed --expression 's/^#Server/Server/' >/etc/pacman.d/mirrorlist

# System python3 for ansible module execution on localhost (uv provides the
# controller/ansible itself via uvx; ansible is no longer pip-installed).
if [ ! -f /usr/bin/python3 ]; then
  sudo pacman --sync --refresh --noconfirm python
fi

ensure_uv

echo Installing Ansible Roles... >&2
ansible_uvx ansible-galaxy role install --role-file "$script_dir/requirements.yml"

if [ "$(id --user)" = 0 ]; then
  ansible_uvx ansible-playbook "$script_dir/setup.playbook.yml" "$@"
else
  ansible_uvx ansible-playbook "$script_dir/setup.playbook.yml" --ask-become-pass "$@"
fi
