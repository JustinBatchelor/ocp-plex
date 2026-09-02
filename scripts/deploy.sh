#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"

"$repo_root/scripts/preflight.sh"

helm repo add plex "$PLEX_HELM_REPOSITORY" --force-update >/dev/null
helm repo update plex >/dev/null

oc apply -f "$repo_root/manifests/namespace.yaml"
oc apply -f "$repo_root/manifests/media-storage.yaml"
oc apply -f "$repo_root/manifests/scc-rolebinding.yaml"

# A RoleBinding may safely reference the stable service account before Helm
# creates it. This ensures the first Plex pod is admitted with the right SCC.
if helm status "$PLEX_RELEASE" --namespace "$PLEX_NAMESPACE" >/dev/null 2>&1; then
  helm upgrade "$PLEX_RELEASE" "$PLEX_CHART" \
    --namespace "$PLEX_NAMESPACE" \
    --version "$PLEX_CHART_VERSION" \
    --values "$repo_root/helm/values.yaml" \
    --wait --timeout 15m
else
  if ! oc -n "$PLEX_NAMESPACE" get secret plex-claim >/dev/null 2>&1; then
    printf 'Missing %s/plex-claim. Run scripts/create-claim-secret.sh first.\n' "$PLEX_NAMESPACE" >&2
    exit 1
  fi
  helm upgrade --install "$PLEX_RELEASE" "$PLEX_CHART" \
    --namespace "$PLEX_NAMESPACE" \
    --version "$PLEX_CHART_VERSION" \
    --values "$repo_root/helm/values.yaml" \
    --values "$repo_root/helm/values-first-run.yaml" \
    --wait --timeout 15m
fi

oc apply -f "$repo_root/manifests/route.yaml"
oc apply -f "$repo_root/manifests/network-policy.yaml"

oc -n "$PLEX_NAMESPACE" rollout status statefulset/plex --timeout=10m
oc -n "$PLEX_NAMESPACE" get pod,pvc,service,route

printf 'Plex is available at https://plex.apps.sno.batchelor.live/web\n'
