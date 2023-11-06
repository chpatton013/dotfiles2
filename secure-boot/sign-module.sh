#!/bin/bash --norc
set -euo pipefail

if [ "$(id --user)" != 0 ]; then
  echo Must be run as root! >&2
  exit 1
fi

key_dir=/root/machine-owner-key

if [ ! -f "$key_dir/MOK.der" ] || [ ! -f "$key_dir/MOK.priv" ]; then
  echo Public or private MOK keys do not exist. Exiting! >&2
  exit 1
fi

kernel_release="$(uname --release)"

for module_name in "$@"; do
  for module_file in "$(dirname "$(modinfo --filename "$module_name")")"/*.ko; do
    echo Signing $module_file
    "/usr/src/linux-headers-$kernel_release/scripts/sign-file" \
      sha256 \
      "$key_dir/MOK.priv" \
      "$key_dir/MOK.der" \
      "$module_file"
  done
done
