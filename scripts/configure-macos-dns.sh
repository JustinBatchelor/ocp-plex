#!/bin/sh
set -eu
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
target=/etc/resolver/batchelor.live
if [ -e "$target" ] && ! cmp -s "$repo_root/config/macos/batchelor.live" "$target"; then
  printf 'An existing resolver configuration differs: %s. Review it before replacing it.\n' "$target" >&2
  exit 1
fi
sudo install -d -m 755 /etc/resolver
sudo install -m 644 "$repo_root/config/macos/batchelor.live" "$target"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
dscacheutil -q host -a name api.sno.batchelor.live
