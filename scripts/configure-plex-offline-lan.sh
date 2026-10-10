#!/bin/sh
# Plex sees the HostNetwork router's OVN management address, not the LAN client.
# Restrict and verify the Route before running this script.
set -eu
mode=${1:-enable}
case "$mode" in
  enable|disable) ;;
  *) printf 'Usage: %s [enable|disable]\n' "$0" >&2; exit 1 ;;
esac
if [ "$mode" = enable ]; then
  allowed=$(oc -n plex get route plex -o go-template='{{index .metadata.annotations "haproxy.router.openshift.io/ip_allowlist"}}')
  [ "$allowed" = '10.45.45.0/24' ] || {
    printf 'Refusing to enable offline access: Route must allow only 10.45.45.0/24.\n' >&2
    exit 1
  }
fi
oc -n plex exec -i plex-0 -- sh -s -- "$mode" <<'POD_SCRIPT'
set -eu
preferences='/config/Library/Application Support/Plex Media Server/Preferences.xml'
token=$(sed -n 's/.* PlexOnlineToken="\([^"]*\)".*/\1/p' "$preferences")
[ -n "$token" ] || { printf 'Saved Plex credential missing.\n' >&2; exit 1; }
current=$(sed -n 's/.* allowedNetworks="\([^"]*\)".*/\1/p' "$preferences")
case "$current" in
  ''|'10.128.0.2/255.255.255.255') ;;
  *) printf 'Existing allowedNetworks differs; review before changing it.\n' >&2; exit 1 ;;
esac
allowed=''
if [ "$1" = enable ]; then
  allowed=10.128.0.2/255.255.255.255
fi
curl -fsS --max-time 15 -X PUT -G \
  -H "X-Plex-Token: $token" \
  --data-urlencode "allowedNetworks=$allowed" \
  http://127.0.0.1:32400/:/prefs -o /dev/null
printf 'Plex allowedNetworks set to: %s\n' "${allowed:-<empty; authentication required>}"
POD_SCRIPT
