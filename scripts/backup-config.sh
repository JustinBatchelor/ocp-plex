#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"

statefulset=plex
job="plex-config-backup-$(date -u +%Y%m%d%H%M%S)"

oc apply -f "$repo_root/manifests/backup.yaml"
oc -n "$PLEX_NAMESPACE" scale "statefulset/$statefulset" --replicas=0
restore_replicas=true
trap 'if [ "$restore_replicas" = true ]; then oc -n "$PLEX_NAMESPACE" scale "statefulset/$statefulset" --replicas=1; fi' EXIT HUP INT TERM

oc -n "$PLEX_NAMESPACE" wait --for=delete pod/plex-0 --timeout=5m 2>/dev/null || true
oc -n "$PLEX_NAMESPACE" create job "$job" --from=cronjob/plex-config-backup-template
oc -n "$PLEX_NAMESPACE" wait --for=condition=complete "job/$job" --timeout=30m
oc -n "$PLEX_NAMESPACE" logs "job/$job"

oc -n "$PLEX_NAMESPACE" scale "statefulset/$statefulset" --replicas=1
restore_replicas=false
oc -n "$PLEX_NAMESPACE" rollout status "statefulset/$statefulset" --timeout=10m

printf 'Backup job %s completed.\n' "$job"
