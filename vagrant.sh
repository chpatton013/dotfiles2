#!/usr/bin/env bash
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${DOTFILES_PLATFORM:-}" ]; then
  echo Error: No platform specified >&2
  exit 1
fi
platform="$DOTFILES_PLATFORM"

env_file="$script_dir/vagrant-env/$platform"
if [ ! -f "$env_file" ]; then
  echo Error: No env file for platform $platform >&2
  exit 1
fi

export VAGRANT_DOTFILE_PATH=.vagrant-$platform
source "$env_file"
vagrant "$@"
