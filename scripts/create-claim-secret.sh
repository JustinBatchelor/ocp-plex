#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"

printf 'Paste the short-lived Plex claim token: ' >&2
stty -echo
IFS= read -r claim_token
stty echo
printf '\n' >&2

case "$claim_token" in
  claim-*) ;;
  *)
    printf 'The token must start with claim-.\n' >&2
    exit 1
    ;;
esac

oc create namespace "$PLEX_NAMESPACE" --dry-run=client -o yaml | oc apply -f -
oc -n "$PLEX_NAMESPACE" create secret generic plex-claim \
  --from-literal=claim-token="$claim_token" \
  --dry-run=client -o yaml | oc apply -f -
unset claim_token

printf 'Created secret %s/plex-claim. Deploy before the token expires.\n' "$PLEX_NAMESPACE"

