#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"

mkdir -p "$repo_root/rendered"

if [ "${FIRST_RUN:-false}" = true ]; then
  helm template "$PLEX_RELEASE" "$PLEX_CHART" \
    --namespace "$PLEX_NAMESPACE" \
    --version "$PLEX_CHART_VERSION" \
    --values "$repo_root/helm/values.yaml" \
    --values "$repo_root/helm/values-first-run.yaml" \
    > "$repo_root/rendered/plex-chart.yaml"
else
  helm template "$PLEX_RELEASE" "$PLEX_CHART" \
    --namespace "$PLEX_NAMESPACE" \
    --version "$PLEX_CHART_VERSION" \
    --values "$repo_root/helm/values.yaml" \
    > "$repo_root/rendered/plex-chart.yaml"
fi

oc apply --dry-run=client -f "$repo_root/manifests/namespace.yaml"
oc apply --dry-run=client -f "$repo_root/manifests/media-storage.yaml"
oc apply --dry-run=client -f "$repo_root/manifests/scc-rolebinding.yaml"
oc apply --dry-run=client -f "$repo_root/manifests/route.yaml"
oc apply --dry-run=client -f "$repo_root/manifests/network-policy.yaml"
oc apply --dry-run=client -f "$repo_root/manifests/backup.yaml"
oc apply --dry-run=client -f "$repo_root/rendered/plex-chart.yaml"

printf 'Rendered chart %s to rendered/plex-chart.yaml\n' "$PLEX_CHART_VERSION"
