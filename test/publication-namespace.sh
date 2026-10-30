#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$root/.github/workflows/release.yaml"
namespace=$(awk '$1 == "features-namespace:" { print $2 }' "$workflow")
registry=$(awk '$1 == "oci-registry:" { print $2 }' "$workflow")
registry=${registry:-ghcr.io}

if [[ "$namespace" != rubio-enterprises/devcontainer-features ]]; then
  echo "Feature publication must use the literal historical namespace, not the source repository name" >&2
  exit 1
fi

if [[ "$registry/$namespace/baseline" != ghcr.io/rubio-enterprises/devcontainer-features/baseline ]]; then
  echo "baseline Feature identity changed" >&2
  exit 1
fi

if [[ "$registry/$namespace:latest" != ghcr.io/rubio-enterprises/devcontainer-features:latest ]]; then
  echo "Feature collection identity changed" >&2
  exit 1
fi

printf 'PASS: fixed Feature and collection identities (source: %s)\n' "${GITHUB_REPOSITORY:-local}"
