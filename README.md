# Plex on OpenShift

This repository deploys a single Plex Media Server instance to the `plex`
namespace on the `sno.batchelor.live` OpenShift cluster.

## Current deployment

Plex is deployed and claimed. Helm release `plex` is healthy, the pod is
running with the `anyuid` SCC, both PVCs are bound, and the TLS Route is
admitted. The one-time `plex-claim` Secret and `PLEX_CLAIM` environment
variable have been removed.

## Architecture

- Public URL: `https://plex.apps.sno.batchelor.live`
- TLS: edge termination with the cluster wildcard certificate
- Plex service: internal `ClusterIP` on TCP 32400
- Media: `truenas.batchelor.live:/mnt/main/plex`, mounted read-only at `/data`
- Plex state: 50 GiB PVC from `truenas-nfs`, mounted at `/config`
- Transcoding: node ephemeral storage at `/transcode`
- Security: a Plex-only service account receives the `anyuid` SCC
- Networking: only the OpenShift ingress namespace can reach the Plex pod

The cluster currently has no block storage class. Consequently `/config` uses
the existing NFSv4.1 CSI class. NFSv4 server-side locking and media access were
verified from the SNO node before deployment.
Do not configure hostpath storage on this SNO node: its available capacity is
on the operating-system partition.

## Prerequisites

- `oc` logged in as a cluster administrator
- Helm 3
- DNS and VPN access to the cluster apps endpoint
- A short-lived claim token from <https://plex.tv/claim>

## Deploy

Run the checks first:

```sh
./scripts/preflight.sh
```

Create the claim Secret without writing the token to disk or shell history:

```sh
./scripts/create-claim-secret.sh
```

The first installation automatically adds `helm/values-first-run.yaml`. Normal
upgrades use only `helm/values.yaml`, so the one-time credential is not added
back after it has been removed.

Deploy the companion resources and pinned official Plex chart:

```sh
./scripts/deploy.sh
```

Open <https://plex.apps.sno.batchelor.live/web>, complete the initial setup,
and add these libraries:

- Movies: `/data/Movies`
- TV: `/data/TV Shows`

After the server is claimed, remove the one-time Secret:

```sh
./scripts/remove-claim-secret.sh
```

In Plex **Settings > Server > Network**:

- Set Custom server access URLs to `https://plex.apps.sno.batchelor.live`
- Leave Secure connections at `Preferred` until every client has been tested
- Disable Remote Access, Relay, and GDM discovery
- Disable video preview thumbnail generation initially

## VPN allowlist

The Route is reachable wherever the cluster ingress endpoint is reachable.
After confirming the source addresses seen by the ingress router, add the LAN
and VPN CIDRs to `haproxy.router.openshift.io/ip_allowlist` in
`manifests/route.yaml`. It is intentionally not guessed by this repository;
an incorrect VPN CIDR would lock out remote clients.

The detected LAN CIDR is `10.45.45.0/24`. If VPN traffic is SNATed into that
range, that single CIDR is sufficient. Otherwise add the VPN client CIDR as a
space-separated value.

## Optional backups and upgrades

CSI snapshots are not required for this deployment. The included optional
backup command takes a quiesced, application-aware archive before upgrades:

```sh
./scripts/backup-config.sh
```

The script scales Plex down, archives `/config` into the
`plex-config-backup` PVC, and then restores the replica count. This is not a
substitute for backing up TrueNAS itself. The backup PVC and suspended job
template are created only when this command is first run.

To validate changes without applying them:

```sh
./scripts/render.sh
```

To render the first-install variant that references the claim Secret:

```sh
FIRST_RUN=true ./scripts/render.sh
```

The chart is pinned to `1.7.1`. Upgrade it only by changing
`PLEX_CHART_VERSION` in `scripts/common.sh`, rendering the diff, backing up
`/config`, and then running the deployment script.
