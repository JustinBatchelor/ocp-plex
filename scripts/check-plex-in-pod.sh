#!/bin/sh
# Run with: oc -n plex exec -i plex-0 -- sh -s < scripts/check-plex-in-pod.sh
# Tokens stay inside the container and are never printed.
set -eu
preferences='/config/Library/Application Support/Plex Media Server/Preferences.xml'
token=$(sed -n 's/.* PlexOnlineToken="\([^"]*\)".*/\1/p' "$preferences")
[ -n "$token" ] || { printf 'No saved Plex claim token found.\n' >&2; exit 1; }
base=https://plex.apps.sno.batchelor.live
plex_get() {
  curl -fsS --max-time 30 -H "X-Plex-Token: $token" "$@"
}
plex_get "$base/identity"
sections=$(plex_get "$base/library/sections")
printf '%s\n' "$sections" | tr '<' '\n' | sed -n 's/^Directory .*title="\([^"]*\)".*/Library: \1/p'
section=$(printf '%s\n' "$sections" | tr '<' '\n' | grep 'type="movie"' | sed -n 's/.* key="\([^"]*\)".*/\1/p' | head -n 1)
if [ -z "$section" ]; then
  printf 'No movie library available for the byte-range playback check.\n' >&2
  exit 1
fi
items=$(plex_get "$base/library/sections/$section/all?X-Plex-Container-Start=0&X-Plex-Container-Size=1")
part=$(printf '%s\n' "$items" | tr '<' '\n' | sed -n 's/^Part .* key="\([^"]*\)".*/\1/p' | head -n 1)
[ -n "$part" ] || { printf 'No media part found for playback check.\n' >&2; exit 1; }
for range in 0-1048575 10485760-11534335; do
  result=$(plex_get --range "$range" -o /dev/null -w '%{http_code} %{size_download}' "$base$part")
  printf 'HTTPS media range %s: %s\n' "$range" "$result"
  [ "$result" = '206 1048576' ] || { printf 'Unexpected byte-range response.\n' >&2; exit 1; }
done
printf 'Claim, library access, and HTTPS media byte-range checks passed.\n'
