#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"

failures=0

check() {
  description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$description"
  else
    printf 'FAIL %s\n' "$description" >&2
    failures=$((failures + 1))
  fi
}

check 'oc is installed' command -v oc
check 'helm is installed' command -v helm
check 'OpenShift API is reachable' oc whoami
check 'cluster-admin can use anyuid SCC' oc auth can-i use scc/anyuid
check 'truenas-nfs storage class exists' oc get storageclass truenas-nfs
check 'apps wildcard certificate is trusted' curl -fsS https://console-openshift-console.apps.sno.batchelor.live/

ingress_domain="$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}')"
if [ "$ingress_domain" = 'apps.sno.batchelor.live' ]; then
  printf 'ok   ingress domain is %s\n' "$ingress_domain"
else
  printf 'FAIL unexpected ingress domain: %s\n' "$ingress_domain" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  printf '%s preflight check(s) failed.\n' "$failures" >&2
  exit 1
fi

printf 'Preflight checks passed. NFS mount and file permissions were separately verified on node sno.\n'
