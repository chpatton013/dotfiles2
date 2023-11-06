#!/bin/bash --norc
set -euo pipefail

if [ "$(id --user)" != 0 ]; then
  echo Must be run as root! >&2
  exit 1
fi

key_dir=/root/machine-owner-key

if [ -f "$key_dir/MOK.der" ] || [ -f "$key_dir/MOK.priv" ]; then
  echo Public or private MOK keys already exist. Exiting! >&2
  exit 1
fi

mkdir --parents "$key_dir"
openssl req \
  -outform DER -out "$key_dir/MOK.der" \
  -new -newkey rsa:2048 -keyout "$key_dir/MOK.priv" \
  -nodes -subj "/CN=CHRIS_PATTON/" -x509 -days 36500
chmod 0600 "$key_dir/MOK.priv"

cat <<EOF
Choose a password for the signing key.
You will need to provide this password again after rebooting.
EOF
mokutil --import "$key_dir/MOK.der"

echo Signing key $key_dir/MOK.der:
openssl x509 -inform DER -in "$key_dir/MOK.der" -noout -sha256 -fingerprint
openssl x509 -inform DER -in "$key_dir/MOK.der" -noout -md5 -fingerprint

cat <<EOF
Reboot now. When prompted by the MOK manager EFI utility, provide the key
password, choose "Enroll MOK", and complete the enrollment steps. Then continue
with the boot as normal.
EOF
