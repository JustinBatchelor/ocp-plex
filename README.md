# Plex on OpenShift

This repository deploys a single Plex Media Server instance to the `plex`
namespace on the `sno.batchelor.live` OpenShift cluster.

## Current deployment

Plex is deployed and claimed. Helm release `plex` is healthy, the pod is
running with the `anyuid` SCC, both PVCs are bound, and the TLS Route is
admitted. The one-time `plex-claim` Secret and `PLEX_CLAIM` environment
variable have been removed.

On 2026-09-20, release revision 3 switched Plex to its pinned AMD64 image in
the internal registry. Both registry and Plex pod replacements passed;
an authenticated `Always` image pull, preserved server identity and libraries,
trusted HTTPS Web UI, HTTP redirect, and two media byte ranges were verified
while Docker Hub DNS remained unavailable to Plex. Actual offline client
playback and seeking still require client confirmation.

## Architecture

- Public URL: `https://plex.apps.sno.batchelor.live`
- TLS: edge termination with the cluster wildcard certificate
- Plex service: internal `ClusterIP` on TCP 32400
- Media: `truenas.batchelor.live:/mnt/main/plex`, mounted read-only at `/data`
- Plex state: 50 GiB PVC from `truenas-nfs`, mounted at `/config`
- Transcoding: node ephemeral storage at `/transcode`
- Security: a Plex-only service account receives the `anyuid` SCC
- Networking: TCP 32400 is allowed from OpenShift's ingress policy group,
  including cluster host-network sources required by the HostNetwork router

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

An already claimed server does not need a new claim token to restart or change
its image registry.

## Local image registry and offline deployment

The internal registry uses its own 100 GiB RWX `truenas-nfs` PVC in
`openshift-image-registry`, with one replica and a `Recreate` rollout. It is
pinned to `worker-0`, which already has the registry's OpenShift 4.22.4 image
cached. Registry availability therefore depends on that worker and TrueNAS.
This change does not make all OpenShift operators or upgrades disconnected.

To configure the registry from the checked-in manifests:

```sh
sh scripts/configure-registry.sh
```

For a Mac using hotspot internet and Ethernet to the LAN, install scoped DNS:

```sh
sh scripts/configure-macos-dns.sh
```

This sends only `batchelor.live` queries to `10.45.45.1`. Podman's VM uses
NetworkManager's dnsmasq plugin with the matching scoped rule; the source
files are in `config/podman`. Public DNS continues through the hotspot.

Mirror a version while the Mac has internet access:

```sh
sh scripts/mirror-plex-image.sh 1.43.3.10896-cb3ebc72d
```

The script pulls Linux AMD64 explicitly, uses a one-hour token for
`plex/plex-image-publisher`, and pushes over the registry's trusted TLS Route.
The publisher has `system:image-builder` access only in namespace `plex`.
Credentials are temporary and are removed on exit. The destination digest,
OCI recovery archive, and archive checksum are stored in ignored `recovery/`.
Treat the archive as a local copy, not as a backup if this Mac's disk fails.

Plex pulls from `image-registry.openshift-image-registry.svc:5000/plex/plex`.
Set `image.tag` and `image.sha` in `helm/values.yaml` to the mirrored version
and destination digest before rendering and deploying. Same-namespace
registry access uses OpenShift's generated service-account pull secret;
mounting an API token into Plex is unnecessary.

Helm chart 1.7.1 is vendored in `vendor/` with its published SHA-256 checksum.
Deploy, render, and claim removal use that local chart and do not refresh an
internet Helm repository. Future chart upgrades require downloading and
verifying a new package and updating `vendor/SHA256SUMS` and the pinned version.

Existing media, configuration, claim state, and the Plex HTTPS address are
preserved. Offline playback still depends on local DNS; see the LAN access
configuration below for the explicitly enabled authentication exception.
Use the local `/web` URL and test your actual clients without WAN access.
Optional backup job images are not mirrored by this workflow.

Validation includes an `Always`-pull test pod (`manifests/registry-pull-test.yaml`)
and an authenticated Route/media check:

```sh
oc -n plex exec -i plex-0 -- sh -s < scripts/check-plex-in-pod.sh
```

The latter reads the saved claim token only inside Plex, lists library names,
and fetches two 1 MiB byte ranges from a movie through the trusted HTTPS Route.
It verifies media delivery and range support; actual client playback and
long-running transcoding still need client testing. If changing the Plex image
version, update the pull-test manifest to the same image digest.

The network policy uses `policy-group.network.openshift.io/ingress`, as
documented in [OpenShift network policy guidance](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/network_security/network-policy).
Selecting only the `openshift-ingress` namespace blocked the HostNetwork
router on `sno` when Plex ran on `worker-0`. The ingress group also includes
cluster host-network traffic; its permission is limited here to TCP 32400.

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

## Offline LAN access and VPN boundary

The Plex Route allows only sources in `10.45.45.0/24`, enforced by
`haproxy.router.openshift.io/ip_allowlist`. Forwarded headers are replaced,
and the allowlist checks the actual connection source, not a supplied header.
Non-LAN requests are dropped, which can appear as an empty HTTP response.

Plex sees routed connections from `10.128.0.2`, the `sno` router's internal
OVN management address. Its persistent `allowedNetworks` setting trusts only
`10.128.0.2/255.255.255.255` without authentication. This was explicitly enabled
for offline LAN use. Requests from LAN clients through this Route therefore
do not require Plex sign-in. The server remains claimed.

Credential-free library listing and two movie byte ranges passed from the Mac
with browser-style Origin/Referer headers. `/web/` stays on HTTPS and redirects
to `/web/index.html`. A non-LAN source was rejected even with a forged LAN
`X-Forwarded-For` header.

The Route removes `Host`, `Origin`, and `Referer` on the backend hop. Plex
otherwise classifies the custom hostname as non-local and rejects anonymous
requests even from an allowed IP. With `Host` omitted, Plex emits relative Web
UI redirects, preserving the browser's public HTTPS URL. The client URL and
trusted edge TLS certificate remain `https://plex.apps.sno.batchelor.live`.
This offline mode relies on the LAN source-IP boundary rather than Plex's
custom-domain/origin checks. Use it only on a trusted LAN.

**Keep the Route allowlist in place while this exception is enabled.**
All clients admitted by the Route share password-free access through the
trusted proxy, including owner-level access to server settings. Cluster host
processes sharing that proxy source are also
trusted; cluster administrators remain part of the trust boundary. Changing
router placement or source NAT requires rechecking the observed source address.

To reproduce the setting after applying and verifying the LAN-restricted Route:

```sh
sh scripts/configure-plex-offline-lan.sh enable
oc -n plex rollout restart statefulset/plex
oc -n plex rollout status statefulset/plex --timeout=3m
sh scripts/check-plex-offline-lan.sh
```

To restore required Plex authentication, run the same configuration script with
`disable` and restart Plex. It clears only this known exception and retains
the Route allowlist. It refuses to overwrite an unexpected existing exception.

VPN clients are admitted only if their connection is translated into the LAN
range. Other VPN CIDRs are currently blocked. Adding a CIDR also grants its
clients password-free Plex access through this Route, so treat that as a
deliberate access-policy change.

During an internet outage, a browser that sends an old account token may still
stall while Plex tries to validate that token online. Use a fresh private
window at `https://plex.apps.sno.batchelor.live/web/index.html` without signing
in to Plex's online service to use the credential-free local path.

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
