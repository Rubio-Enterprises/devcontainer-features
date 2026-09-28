# Agent context

This repo follows Rubio-Enterprises standards. Run `/audit-standards` from a Claude Code session to check conformance, or `/onboard-repo` for greenfield setup.

Repo-specific context (in-progress migrations, gotchas, agent guidance):

This repository publishes Dev Container Features to
`ghcr.io/rubio-enterprises/devcontainer-features/<id>`. `baseline` is the org
Dev Container baseline; the standards audit rule REPOSITORY-WORKSPACE-FILE
requires every native repository to pin it. See `README.md` for what it
provides, how to test it, and how releases work.

- Keep the repository public: clients pull features from GHCR without
  registry credentials.
- Any change under `src/<feature>/` bumps that feature's `version` in the same
  pull request; merging publishes it. Removing an option or environment
  variable is a major bump.
- Feature tests need a Docker daemon (`devcontainer features test`).
