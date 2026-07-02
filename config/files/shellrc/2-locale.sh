export LANGUAGE=en_US
export CHARSET=UTF-8
export LANG="$LANGUAGE.$CHARSET"
export LC_COLLATE=C # Sort uppercase before lowercase

if [ ! -f /etc/localtime ]; then
  # Only set TZ if this machine does not have a valid timezone file.
  export TZ=America/Los_Angeles
  if [ -d /usr/share/zoneinfo ]; then
    # Explicitly set TZDIR if it exists. When running a process with a non-
    # default sysroot, if TZDIR is not set, libc will not be able to locate the
    # zoneinfo file specified by the TZ environment variable unless TZDIR is
    # explicitly set.
    export TZDIR=/usr/share/zoneinfo
  fi
fi
