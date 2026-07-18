#!/bin/bash --norc
set -euo pipefail

script_dir="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${DOTFILES_PLATFORM:-}" ]; then
  echo Error: No platform specified >&2
  exit 1
fi
platform="$DOTFILES_PLATFORM"

spec_file="$script_dir/vagrant-env/$platform.yaml"
if [ ! -f "$spec_file" ]; then
  echo Error: No env file for platform $platform >&2
  exit 1
fi

# The Vagrantfile reads the spec itself; just make the platform visible to it.
export DOTFILES_PLATFORM
export VAGRANT_DOTFILE_PATH=.vagrant-$platform
vagrant "$@"
