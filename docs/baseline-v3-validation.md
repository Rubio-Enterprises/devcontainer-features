# Baseline v3 validation

Validated on 2026-10-13 using the Trixie 2.2.1 Dev Container base image.
All container experiments used Docker context `colima-dev`, disposable
`sol-*` containers, no GitHub credentials, and no user tool/cache mounts.
No host personalization or live Dev Containers were changed.

## Decisions and sources

- Baseline is 3.0.0: removing the previously provided GitHub CLI breaks
  consumers that called it. Existing shims ownership and system git trust
  behavior remain unchanged.
- mise is pinned to 2026.10.9, above the 2026.9.14 mirror floor.
  The installer uses only fixed GitHub release download URLs.
- Debian Trixie's minisign 0.12 verifies `SHASUMS256.txt.minisig` with the key
  published in [mise's installation documentation](https://mise.jdx.dev/installing-mise.html#github-releases)
  and [upstream minisign.pub](https://github.com/jdx/mise/blob/main/minisign.pub).
  SHA-256 then verifies the architecture-specific archive before extraction.
  No fetched key or per-release hash is trusted independently.
- [Renovate's regex manager](https://docs.renovatebot.com/modules/manager/regex/)
  tracks the annotated pin with the GitHub releases datasource.
  [Generic `bumpVersions`](https://docs.renovatebot.com/configuration-options/#bumpversions)
  supports a scoped patch bump of the feature JSON in the same branch;
  `bumpVersion` does not support this manager. The generic option is
  experimental, so reviewers must verify the bump before merging. The release
  workflow remains publish-only; it does not synthesize source versions.

## Checks

| Check | Result |
| --- | --- |
| ARM64 image build with API mapped to 127.0.0.1 | Passed; signature, archive hash, executable version |
| AMD64 installer on the same base image under emulation, API blocked | Passed; signature, archive hash, executable version |
| Dev Container CLI 0.89.0 feature suite, API blocked during build/run | Passed |
| Feature suite with default Colima no-new-privileges | Passed, including refusal to reclaim ownership when sudo is blocked |
| Feature suite with no-new-privileges=false | Passed, including successful remote-user UID ownership recovery |
| Empty-cache latest fd (github), jq/ripgrep (aqua) installs | Passed; no API request URLs in trace, binaries executed |
| Corrupted minisign signature | Rejected; existing mise executable unchanged |
| Corrupted tarball with intact signed manifest | Rejected at SHA-256; existing mise unchanged |
| Renovate 44.155.8 strict config validator | Passed |
| Renovate regex extraction and real bumpVersions fixture | Passed; simulated mise 2026.10.10 update also adds feature 3.0.1 |
| ShellCheck, shfmt, Markdown lint, lefthook pre-commit | Passed |

The API-free installation test now runs from `test/baseline/test.sh`, including
in CI. `verification-failures.sh` is an additional installer fault-injection
test; see the README for its disposable-container invocation.

## Limits found by the experiments

mise's mirror is not a firewall. A mirror miss can fall back to the API.
In the first scratch test, `github:jqlang/jq@latest` resolved jq's nonstandard
tag as `vjq-1.8.2`, received a mirror 404, and attempted the blocked API.
The correct aqua jq backend passed. This is why the test covers supported
backend/tag combinations rather than claiming every possible tool is API-free.
Trace checking excludes static configuration/cache names and checks request
URLs beginning `https://api.github.com/`.

Renovate was validated locally, including its actual generic version-bump
implementation. A hosted Renovate PR and publication on merge are not yet
verified. The fixture used a simulated repository file list, not GitHub writes.

## Operator dotfiles audit (read-only)

The dotfiles source has no mandatory container bootstrap call to `gh`:

- `home/.chezmoiscripts/run_before_check-github-accounts.sh.tmpl` invokes gh on
  hosts, but `home/.chezmoidata/apply_target_gates.toml` excludes that script
  from the container Apply Target Trait.
- The dependency installer and Homebrew/mise migration are also excluded from
  containers. The uv installer mentions `gh auth login` only as diagnostic
  advice after failed git access; it does not execute gh.
- The `aqua:cli/cli` tool and `~/.local/bin/gh` wrapper are excluded from
  containers. Comments assuming the runtime supplies gh are now stale.
- `home/modify_dot_gitconfig.tmpl` preserves the caller's gitconfig unchanged
  in containers rather than installing host credential routes. A copied
  host gitconfig may still reference `git-credential-gh-account`, whose runtime
  authentication requires gh. Authenticated git/gh should stay on the host.

No dotfiles files were changed or applied. The known dotfiles mise 2026.9.5
pin still shadows `/usr/local/bin/mise` after personalization and must be
upgraded separately. This feature alone cannot fix a personalized container
using that older binary. A full dotfiles apply and the reported npm missing-tool
warnings were not tested here.
