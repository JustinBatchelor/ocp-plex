#!/bin/sh
# Run on a LAN client. Deliberately sends no Plex credential or browser cookie.
set -eu
base=https://plex.apps.sno.batchelor.live
plex_get() {
  curl -fsS --max-time 30 -H "Origin: $base" -H "Referer: $base/web/index.html" "$@"
}
sections=$(plex_get "$base/library/sections")
printf '%s\n' "$sections" | tr '<' '\n' | sed -n 's/^Directory .*title="\([^"]*\)".*/Library without sign-in: \1/p'
section=$(printf '%s\n' "$sections" | tr '<' '\n' | grep 'type="movie"' | sed -n 's/.* key="\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$section" ] || { printf 'No movie library found.\n' >&2; exit 1; }
items=$(plex_get "$base/library/sections/$section/all?X-Plex-Container-Start=0&X-Plex-Container-Size=1")
part=$(printf '%s\n' "$items" | tr '<' '\n' | sed -n 's/^Part .* key="\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$part" ] || { printf 'No media part found.\n' >&2; exit 1; }
for range in 0-1048575 10485760-11534335; do
  result=$(plex_get --range "$range" -o /dev/null -w '%{http_code} %{size_download}' "$base$part")
  printf 'Media without sign-in, range %s: %s\n' "$range" "$result"
  [ "$result" = '206 1048576' ] || exit 1
done
plex_get -L -o /dev/null -w 'Web UI final URL: %{url_effective}\n' "$base/web/"
printf 'Offline LAN library and media checks passed without credentials.\n'
