---
name: ocp-plex
description: Maintain or troubleshoot JustinBatchelor/ocp-plex, including its Plex Helm deployment, TrueNAS storage, local image registry, offline LAN access, and OpenShift scripts. Use for this repository rather than generic Plex setup.
---

# Plex on OpenShift

Paths are relative to the active `JustinBatchelor/ocp-plex` checkout. Read
`README.md`, the working-tree status, and relevant scripts before editing.
The repository contains deployment tooling, not the Plex application source.

## Find the change surface

- `helm/values.yaml` and `values-first-run.yaml`: pinned image, resources,
  storage mounts, and one-time claim environment.
- `scripts/common.sh`, `vendor/`, and `scripts/render.sh`: pinned upstream
  chart, checksum verification, and manifest rendering.
- `manifests/route.yaml` and `network-policy.yaml`: the ingress boundary.
- `manifests/media-storage.yaml`, `backup.yaml`, and `scripts/backup-config.sh`:
  media, configuration persistence, and quiesced backups.
- Registry manifests and `scripts/configure-registry.sh`, `mirror-plex-image.sh`:
  internal registry storage and image mirroring.
- `scripts/configure-plex-offline-lan.sh`, `check-plex-offline-lan.sh`, and
  `check-plex-in-pod.sh`: offline settings and authenticated/media checks.
- `config/` and `scripts/configure-macos-dns.sh`: scoped Mac/Podman DNS.

## Preserve the deployment boundaries

The release and namespace are `plex`. Media is mounted read-only from TrueNAS
at `/data`; `/config` uses the `truenas-nfs` PVC and `/transcode` uses ephemeral
storage. Do not replace this with hostpath on the SNO operating-system partition.
Only the Plex service account receives `anyuid`.

The checked-in offline mode trusts the router's observed source address inside
Plex. Its Route allowlist is therefore an authentication boundary: admitted LAN
clients have password-free access, including server settings. Keep that allowlist
in place while the exception is enabled. Changing allowed CIDRs, router placement,
source NAT, or stripped backend headers requires rechecking the access boundary.
Do not infer VPN CIDRs from a workstation address. Read the README's offline LAN
section before changing either Plex authentication or Route configuration.

A claimed server does not need another claim token for ordinary upgrades.
Keep claim tokens in the temporary Secret workflow, and remove the first-run
Secret/environment after claiming. Never commit tokens, Plex preferences,
registry authentication files, or recovery archives.

## Validation and releases

For shell edits, run `sh -n` on changed scripts. Render normal and first-run
variants with `sh scripts/render.sh` and `FIRST_RUN=true sh scripts/render.sh`.
Rendering uses client dry runs and requires `helm` and `oc`; it is separate
from `scripts/deploy.sh`. Check the vendored chart checksum before use.

For image changes, mirror Linux AMD64, retain the destination digest, and align
`image.tag`/`image.sha` with `manifests/registry-pull-test.yaml`. For chart upgrades,
update the pinned version, package, and `vendor/SHA256SUMS` together.

The backup script stops Plex temporarily to archive `/config`; it is a live
operation, not a passive validation command. Registry setup, DNS configuration,
offline-auth configuration, deployment, and backup execution require the user's
task to cover those changes. For authorized deployment, follow README preflight,
backup, rollout, Route, and media checks. HTTP byte-range checks establish media
delivery, not complete client playback or sustained transcoding.
