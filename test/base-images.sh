#!/usr/bin/env bash
set -euo pipefail

base=${1:?base image reference required}
ci=${2:?CI image reference required}
arch=${3:?native architecture required}
digest=${4:?resolved base digest required}
out=${5:?evidence directory required}
mkdir -p "$out"

[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]
actual=$(docker info --format '{{.Architecture}}')
case "$arch:$actual" in
amd64:x86_64 | amd64:amd64 | arm64:aarch64 | arm64:arm64) ;;
*)
  echo "Native Docker architecture mismatch: $arch:$actual" >&2
  exit 1
  ;;
esac

docker image inspect "$base" >"$out/base-config.json"
docker image inspect "$ci" >"$out/base-ci-config.json"
jq -e --arg arch "$arch" '.[0] | .Os == "linux" and .Architecture == $arch' "$out/base-config.json"
jq -e --arg arch "$arch" --arg digest "$digest" '
  .[0] | .Os == "linux" and .Architecture == $arch
  and .Config.User == "vscode"
  and .Config.Labels["org.opencontainers.image.base.name"] == "ghcr.io/rubio-enterprises/devcontainers/base:latest"
  and .Config.Labels["org.opencontainers.image.base.digest"] == $digest
' "$out/base-ci-config.json"
jq -e --slurpfile base "$out/base-config.json" '
  .[0].RootFS.Layers as $layers | $base[0][0].RootFS.Layers as $prefix
  | ($layers | length) > ($prefix | length)
    and $layers[0:($prefix | length)] == $prefix
' "$out/base-ci-config.json"

for image in "$base" "$ci"; do
  docker run --rm --network none --security-opt no-new-privileges --user 1000 \
    --entrypoint bash "$image" -euc '
      cd /
      test "$(id -u)" = 1000
      mise --version
      test -w "$MISE_SHIMS_DIR"
      if sudo -n true 2>/dev/null; then echo "sudo unexpectedly works" >&2; exit 1; fi
      test ! -e /var/run/docker.sock
      test ! -e /dev/kvm
      test ! -e "$HOME/.git-credentials"
      test ! -e "$HOME/.config/gh/hosts.yml"
      test ! -e "$HOME/.docker/config.json"
      test ! -e "$HOME/.netrc"
      if env | cut -d= -f1 | grep -E "^(STANDARDS_PIN|GH_TOKEN|GITHUB_TOKEN|OP_SERVICE_ACCOUNT_TOKEN)$"; then
        echo "Image carries a provisioning pin or credential variable" >&2; exit 1
      fi
    '
done

docker run --rm --network none --security-opt no-new-privileges \
  --entrypoint bash "$ci" -euc '
    cd /
    test "$(id -u)" = 1000
    test "$(/opt/actions-runner/bin/Runner.Listener --version)" = 2.337.0
    gh --version
    jq --version
    mise --version
    "$MISE_DATA_DIR/bin/mise" version --json | jq -er .version
    test "$(readlink "$MISE_DATA_DIR/bin/mise")" = /usr/local/bin/mise
    for directory in "$MISE_DATA_DIR" "$MISE_CACHE_DIR" "$MISE_SHIMS_DIR" /var/cache/devcontainer; do
      touch "$directory/.base-image-write-test"
      rm "$directory/.base-image-write-test"
    done
    for command in git curl tar gzip unzip; do command -v "$command"; done
  '
printf 'PASS: native linux/%s, exact base pairing, common-prefix layers and restricted non-root runtime\n' "$arch"
