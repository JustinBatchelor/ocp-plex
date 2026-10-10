#!/bin/sh
set -eu

PLEX_NAMESPACE=plex
PLEX_RELEASE=plex
PLEX_CHART_VERSION=1.7.1

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PLEX_CHART="$repo_root/vendor/plex-media-server-$PLEX_CHART_VERSION.tgz"

if [ ! -f "$PLEX_CHART" ]; then
  printf 'Missing vendored Helm chart: %s\n' "$PLEX_CHART" >&2
  exit 1
fi
(cd "$repo_root/vendor" && shasum -a 256 -c SHA256SUMS >/dev/null)
