# Working on Plex

Read [the repository skill](skills/ocp-plex/SKILL.md) before changing deployment
scripts or manifests. It maps the source and explains the storage, claim-token,
and offline LAN access constraints. Keep it aligned with the implementation.

For GitHub work, prefer the user's authenticated `gh` CLI for API and PR
operations, and the configured Git remote for commits and pushes. The app
connector has returned integration-permission errors despite the CLI having
repository access. Check `gh auth status` when needed; never print tokens.
