# Base images

The image workflow builds these two Linux amd64 + arm64 images:

| Image | Contents |
| --- | --- |
| `ghcr.io/rubio-enterprises/devcontainers/base:latest` | Digest-pinned Microsoft Trixie base with the existing baseline Feature |
| `ghcr.io/rubio-enterprises/devcontainers/base-ci:latest` | The exact base above, plus Actions runner 2.337.0, gh, jq and writable runner/mise cache paths |

These are image identities, not a change to the historical Feature or collection
namespace `ghcr.io/rubio-enterprises/devcontainer-features`.
First publication and anonymous access/package association require a separate
owner checkpoint; source preparation alone does not establish availability.

## Build and validation

`images/base/devcontainer.json` uses the existing baseline Feature installer;
there is no second mise installer. Its workspace is an empty temporary directory,
not the repository checkout. `images/base-ci/Dockerfile` has an empty build
context and uses `COPY --link` to add the digest-pinned runner under
`/opt/actions-runner`, preserving the base's filesystem-layer prefix.

`.github/workflows/base-images.yml` uses the declared Docker x64 and ARM routes
with their existing hosted fallbacks. Each architecture must match its actual
Docker daemon and image configuration; no QEMU emulation qualifies. Both images
are run as UID 1000 with no network and no-new-privileges. Smoke tests verify
runner version, gh/jq/mise, the mise-action-compatible
`$MISE_DATA_DIR/bin/mise` link, writable shims/cache and failed sudo escalation.

Every layer is inspected for standards/repository checkouts and credential
files, retaining the two known Oh My Zsh checkout configurations shipped by the
Microsoft base (root and vscode); these are not organization source. The
layer-inspector regression covers both allowed paths and unrelated rejected
Git checkouts. Checksum-pinned Trivy scans both images and their configuration for
secrets, reporting identifiers and locations, never matched values. The images
contain no standards checkout, provisioning pin or credentials. They do not
fetch standards at runtime.

## Digest pairing for rebase

The base is pushed only to an ephemeral job-local registry before resolving its
**platform manifest digest**. Base-ci uses that immutable digest in `FROM`, not a
moving tag, and records these standard OCI image labels:

- `org.opencontainers.image.base.name`:
  `ghcr.io/rubio-enterprises/devcontainers/base:latest`
- `org.opencontainers.image.base.digest`: that architecture's exact
  `sha256:<64 lowercase hex>` base manifest digest.

A consumer must select the desired architecture from the published base index
and compare **that platform manifest digest**, not the multiarch index digest,
with the matching base-ci label before `crane rebase`. The name records the
public base identity; the digest is the immutable pairing authority. Layer
prefixes must also match. Rebase preserves the repository image's configuration:
base-ci's USER/ENV/labels do not automatically replace it.

OCI layouts preserve the exact manifests and compressed layer blobs across
architecture jobs. The publishing job checks every pushed digest against the
validated local digest before assembling the two multiarch indices. Do not
replace this transport with Docker save/load, which need not preserve compressed
manifest identities.

## Publication boundary

Pull requests only build, smoke, inspect and scan; they have no package-write
permission or registry login. No standards-reader credential is needed. On a
reviewed default-branch push (or manually authorized default-branch dispatch),
a separate package-write job publishes only after **both** native jobs pass.
It publishes commit-scoped `sha-<commit>` / `sha-<commit>-<arch>` references, then
advances `latest` for each image. Registry tag updates are not transactional:
consumers must enforce the pairing labels while resolving moving tags.

The OCI source label follows the actual source repository, including an eventual
identity-preserving rename. Public package visibility and package association
must be verified after the first owner-authorized publication; this workflow
does not mutate package visibility, repository settings or runner configuration.
