#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"

helm upgrade "$PLEX_RELEASE" "$PLEX_CHART" \
  --namespace "$PLEX_NAMESPACE" \
  --version "$PLEX_CHART_VERSION" \
  --values "$repo_root/helm/values.yaml" \
  --wait --timeout 10m

oc -n "$PLEX_NAMESPACE" delete secret plex-claim --ignore-not-found
