#!/bin/sh
set -eu

PLEX_NAMESPACE=plex
PLEX_RELEASE=plex
PLEX_CHART=plex/plex-media-server
PLEX_CHART_VERSION=1.7.1
PLEX_HELM_REPOSITORY=https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

