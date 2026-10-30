#!/usr/bin/env bash
set -euo pipefail
layout=${1:?OCI image layout required}
digest=${2:?expected manifest digest required}
[[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]
jq -e --arg digest "$digest" '.manifests | length == 1 and .[0].digest == $digest' "$layout/index.json"
manifest="$layout/blobs/sha256/${digest#sha256:}"
for layer in $(jq -er '.layers[].digest' "$manifest"); do
  [[ "$layer" =~ ^sha256:[0-9a-f]{64}$ ]]
  tar -tf "$layout/blobs/sha256/${layer#sha256:}" | awk '
    {
      path = $0
      sub(/^\.\//, "", path)
      if (path == "home/vscode/.oh-my-zsh/.git/config" || path == "root/.oh-my-zsh/.git/config") next
    }
    /(^|\/)\.standards-config(\/|$)/ ||
    /(^|\/)\.git\/config$/ ||
    /^(\.\/)?(home\/[^\/]+|root)\/(\.git-credentials|\.netrc|\.docker\/config.json|\.config\/gh\/hosts.yml)$/ ||
    /^(\.\/)?workspaces\/[^\/]+\/.+/ {
      print "Forbidden checkout or credential path in image layer: " $0 > "/dev/stderr"
      failed = 1
    }
    END { exit failed }
  '
done
printf 'PASS: every layer inspected for standards, repository checkouts and credential files\n'
