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

Each native job resolves its base **platform manifest digest** in an ephemeral
local registry and uses that immutable digest in base-ci's `FROM`, not a moving
tag. After both native jobs pass, a read-only assembly job constructs the base
**multiarch index** and stamps these standard OCI image-config labels on each
base-ci platform image with pinned crane's metadata-only mutation:

- `org.opencontainers.image.base.name`:
  `ghcr.io/rubio-enterprises/devcontainers/base:latest`
- `org.opencontainers.image.base.digest`: the exact **base multiarch index**
  digest, `sha256:<64 lowercase hex>`, identical on both base-ci architectures.

The labels live in OCI config `config.Labels`, not manifest annotations. This
matches `.github/actions/repository-image/image.mjs` at
`65f11ddf3b57a2dc4950db4c62cfb0d7ca28a724`: its exported `validatePair`
function is exercised against both assembled architectures. A platform child
digest is deliberately rejected. Base/CI index platform membership is checked;
compressed layers, rootfs diff IDs and runtime configuration stay identical to
the native-smoked, secret-scanned inputs except the one digest label. The
assembly step introduces no filesystem layer or arbitrary configuration value.

Consumers compare the resolved base **index** digest to each base-ci config
label and validate the same-platform layer prefixes before `crane rebase`.
Rebase preserves the repository image's configuration: base-ci's USER/ENV/labels
do not automatically replace it.

OCI layouts preserve the exact manifests and compressed layer blobs across
architecture, assembly and publication jobs. Both final index layouts pass a
job-local push/pull digest roundtrip before export. The publishing job verifies
each pushed **index** digest before moving latest. Do not replace this transport
with Docker save/load, which need not preserve compressed manifest identities.
Use crane's default push of the layout's single index descriptor, not `--index`
(which would publish the outer layout index instead).

## Publication boundary

Pull requests only build, smoke, inspect and scan; they have no package-write
permission or registry login. No standards-reader credential is needed. On a
reviewed default-branch push (or manually authorized default-branch dispatch),
a separate package-write job publishes only after **both** native jobs and the
read-only pairing assembly pass. It publishes commit-scoped `sha-<commit>`
index references, then
advances `latest` for each image. Registry tag updates are not transactional:
consumers must enforce the pairing labels while resolving moving tags.

The OCI source label follows the actual source repository, including an eventual
identity-preserving rename. Public package visibility and package association
must be verified after the first owner-authorized publication; this workflow
does not mutate package visibility, repository settings or runner configuration.
