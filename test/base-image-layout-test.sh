#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
manifest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
layer=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
mkdir -p "$tmp/layout/blobs/sha256" "$tmp/files"
printf '{"manifests":[{"digest":"%s"}]}\n' "$manifest" >"$tmp/layout/index.json"
printf '{"layers":[{"digest":"%s"}]}\n' "$layer" >"$tmp/layout/blobs/sha256/${manifest#sha256:}"
printf 'ordinary image file\n' >"$tmp/files/ordinary"
mkdir -p "$tmp/files/home/vscode/.oh-my-zsh/.git" "$tmp/files/root/.oh-my-zsh/.git"
touch "$tmp/files/home/vscode/.oh-my-zsh/.git/config" "$tmp/files/root/.oh-my-zsh/.git/config"
tar -C "$tmp/files" -czf "$tmp/layout/blobs/sha256/${layer#sha256:}" .
bash "$root/test/base-image-layout.sh" "$tmp/layout" "$manifest"

for forbidden in home/vscode/.standards-config/config/mise/base.toml \
  root/.git-credentials home/vscode/.config/gh/hosts.yml \
  home/vscode/.docker/config.json home/vscode/.netrc \
  workspaces/repository/source.txt opt/checkout/.git/config; do
  rm -rf "$tmp/files"
  mkdir -p "$tmp/files/$(dirname "$forbidden")"
  touch "$tmp/files/$forbidden"
  tar -C "$tmp/files" -czf "$tmp/layout/blobs/sha256/${layer#sha256:}" .
  if bash "$root/test/base-image-layout.sh" "$tmp/layout" "$manifest" >"$tmp/result.log" 2>&1; then
    echo "Inspector accepted forbidden layer path: $forbidden" >&2
    exit 1
  fi
  grep -q 'Forbidden checkout or credential path' "$tmp/result.log"
done
if bash "$root/test/base-image-layout.sh" "$tmp/layout" "$layer" >"$tmp/result.log" 2>&1; then
  echo "Inspector accepted a mismatched manifest digest" >&2
  exit 1
fi
echo 'PASS: clean layer, seven forbidden paths, mismatched manifest digest'
