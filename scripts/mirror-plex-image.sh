#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"

version=${1:-1.43.3.10896-cb3ebc72d}
case "$version" in
  ''|*[!A-Za-z0-9_.-]*) printf 'Invalid image version\n' >&2; exit 1 ;;
esac
source_image="docker.io/plexinc/pms-docker:$version"
registry="$(oc -n openshift-image-registry get route default-route -o jsonpath='{.spec.host}')"
destination="$registry/plex/plex:$version"
mkdir -p "$repo_root/recovery"
auth_dir=$(mktemp -d)
cleanup() {
  podman logout --authfile "$auth_dir/auth.json" "$registry" >/dev/null 2>&1 || true
  rm -f "$auth_dir/auth.json"
  rmdir "$auth_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

oc apply -f "$repo_root/manifests/registry-publisher.yaml"
podman pull --platform linux/amd64 "$source_image"
architecture=$(podman image inspect --format '{{.Os}}/{{.Architecture}}' "$source_image")
[ "$architecture" = linux/amd64 ] || { printf 'Unexpected architecture: %s\n' "$architecture" >&2; exit 1; }
oc -n plex create token plex-image-publisher --duration=1h |
  podman login --authfile "$auth_dir/auth.json" --username plex-image-publisher --password-stdin "$registry"
podman push --authfile "$auth_dir/auth.json" \
  --digestfile "$repo_root/recovery/plex-$version.digest" "$source_image" "docker://$destination"
podman save --format oci-archive --output "$repo_root/recovery/plex-$version.oci.tar" "$source_image"
(cd "$repo_root/recovery" && shasum -a 256 "plex-$version.oci.tar" > "plex-$version.oci.tar.sha256")
printf 'Mirrored %s. Set image.sha to the digest below, render, and deploy:\n' "$destination"
cat "$repo_root/recovery/plex-$version.digest"
