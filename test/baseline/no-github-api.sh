#!/bin/bash
# Run inside a fresh baseline container with --add-host api.github.com:127.0.0.1.
# No user tools/caches or GitHub credentials may be mounted into the container.
set -euo pipefail

getent hosts api.github.com | grep -q '^127\.0\.0\.1[[:space:]]'
for name in GITHUB_TOKEN GH_TOKEN MISE_GITHUB_TOKEN; do
  if [[ -n "${!name:-}" ]]; then
    echo "Run this test without GitHub credentials ($name is set)" >&2
    exit 1
  fi
done

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
export MISE_DATA_DIR="$scratch/data" MISE_CACHE_DIR="$scratch/cache"
export MISE_CONFIG_DIR="$scratch/config" MISE_STATE_DIR="$scratch/state"
export MISE_GLOBAL_CONFIG_FILE="$scratch/global.toml"
export MISE_SHIMS_DIR="$scratch/shims"
cd "$scratch"
cat >mise.toml <<'EOF'
[tools]
"aqua:jqlang/jq" = "latest"
"github:sharkdp/fd" = "latest"
"aqua:BurntSushi/ripgrep" = "latest"
EOF
mise trust mise.toml
mise install --yes --log-level trace >install.log 2>&1 || {
  cat install.log >&2
  exit 1
}
if grep -q 'https://api\.github\.com/' install.log; then
  echo "Unexpected GitHub API reference in mise install trace" >&2
  grep 'https://api\.github\.com/' install.log >&2
  exit 1
fi
mise exec -- jq --version
mise exec -- fd --version
mise exec -- rg --version
echo "PASS: fresh github:/aqua: latest installs with GitHub API blocked and no API trace references"
