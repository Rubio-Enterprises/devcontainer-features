#!/bin/bash
# Run as root in a throwaway baseline container, with src/baseline mounted at
# /tmp/baseline. Exercise the real installer with corrupted release downloads.
set -euo pipefail

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/bin"
cat >"$scratch/bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
/usr/bin/curl "$@"
# install.sh downloads into its temporary working directory with --output.
case "$TAMPER" in
  signature)
    [[ ! -f SHASUMS256.txt.minisig ]] || printf 'invalid signature\n' >SHASUMS256.txt.minisig
    ;;
  checksum)
    for asset in mise-*.tar.gz; do
      [[ ! -f "$asset" ]] || printf 'corruption\n' >>"$asset"
    done
    ;;
esac
EOF
chmod +x "$scratch/bin/curl"
before="$(sha256sum /usr/local/bin/mise)"
for tamper in signature checksum; do
  if PATH="$scratch/bin:$PATH" TAMPER="$tamper" _REMOTE_USER=vscode \
    sh /tmp/baseline/install.sh >"$scratch/$tamper.log" 2>&1; then
    echo "FAIL: installer accepted corrupt $tamper" >&2
    exit 1
  fi
  grep -q 'baseline: mise download/signature/checksum/install failed' "$scratch/$tamper.log"
  if [[ "$tamper" == checksum ]]; then
    grep -q 'Signature and comment signature verified' "$scratch/$tamper.log"
    grep -q 'FAILED' "$scratch/$tamper.log"
  fi
  [[ "$(sha256sum /usr/local/bin/mise)" == "$before" ]]
  echo "PASS: corrupt $tamper rejected without replacing mise"
done
