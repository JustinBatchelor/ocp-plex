#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
oc apply -f "$repo_root/manifests/registry-storage.yaml"
oc wait -n openshift-image-registry pvc/image-registry-storage \
  --for=jsonpath='{.status.phase}'=Bound --timeout=2m
oc patch configs.imageregistry.operator.openshift.io cluster --type=merge \
  --patch-file="$repo_root/manifests/registry-config-patch.yaml"
oc wait -n openshift-image-registry deployment/image-registry --for=create --timeout=2m
oc rollout status -n openshift-image-registry deployment/image-registry --timeout=5m
oc apply -f "$repo_root/manifests/registry-publisher.yaml"
oc -n openshift-image-registry get pvc,route
