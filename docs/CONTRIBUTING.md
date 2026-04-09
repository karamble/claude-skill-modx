# Contributing

Thanks for considering a contribution to `claude-skill-modx`. This document covers the development setup, how to add a new action to the bridge dispatcher, how to run the local checks that CI will run on your PR, and the submission rules.

## Development setup

Clone the repo and make the local checks runnable:

```sh
git clone https://github.com/karamble/claude-skill-modx.git
cd claude-skill-modx

# Install the git hooks
git config core.hooksPath .githooks
chmod +x .githooks/*

# Install shellcheck and php if you do not have them
apt-get install -y shellcheck php-cli    # Debian/Ubuntu
brew install shellcheck php              # macOS
```

To test changes against a real MODX site without publishing, install the modified skill into a temporary Claude Code skills path:

```sh
HOME=/tmp/test-home ./install.sh
# Then point a Claude Code session at /tmp/test-home and test
```

## Running the checks

CI runs three checks on every PR. Run them locally before submitting:

```sh
# 1. shellcheck on all POSIX sh scripts
shellcheck install.sh uninstall.sh skill/scripts/*.sh

# 2. PHP syntax check on the bridge
php -l skill/bridge/modx-cli.php

# 3. Neutrality check (no private site identifiers leaked)
# The forbidden identifier list lives in .github/workflows/neutrality-check.yml
# and the local pre-commit hook at .githooks/pre-commit mirrors it. Run either:
git commit   # the pre-commit hook runs automatically if core.hooksPath is set
# or reproduce the CI step manually:
sh .githooks/pre-commit
```

If the neutrality check finds anything, your PR will be rejected automatically by CI. Do not reference any specific site; use `example.com`, `web_user`, `/var/www/example.com/web`, `mysite` in all examples and documentation.

## Adding a new action to the dispatcher

All actions live in the `dispatch()` function in `skill/bridge/modx-cli.php`. To add a new action:

1. **Pick a verb and a noun.** The convention is `<noun>_<verb>`: `resource_list`, `chunk_create`, `tv_setvalue`. Keep the noun consistent with MODX's own terminology.

2. **Add a new `case` in `dispatch()`** that extracts the request keys and calls the appropriate MODX ORM methods. Follow the pattern of existing cases.

3. **Return an associative array** that will be JSON-encoded. On success, include enough context for the caller to verify what happened (ids, names, counts). On failure, throw an exception; the top-level try/catch will wrap it in the standard error envelope.

4. **Reuse existing helpers** where possible: `loadResource()`, `applyResourceFields()`, `setResourceTvs()`, `resolveTemplate()`, `resolveCategoryId()`. Do not duplicate ORM lookups inline.

5. **Document the action** in `skill/reference/actions.md`. Add an H3 subsection under the appropriate H2 group with the request keys table, a request example, and a response example.

6. **Add at least one usage example** to `skill/reference/examples.md` showing the JSON payload for a typical call.

7. **Add error cases** to `skill/reference/errors.md` if the new action can fail in ways not already documented.

8. **Bump `bridge_version`** in the `ping` case if the change is meaningful. Version follows SemVer: patch for backward-compatible fixes, minor for new actions, major for breaking changes.

9. **Run the local checks.** PRs that fail shellcheck, php -l, or the neutrality grep will be rejected.

## PR rules

- **One logical change per PR.** Do not bundle a new action, a bug fix, and a doc rewrite in the same PR.
- **Commit messages in imperative mood.** `Add snippet_duplicate action`, not `Added` or `Adding`.
- **Include a changelog entry** in `CHANGELOG.md` under the `## [Unreleased]` section (create it if missing).
- **Do not edit `LICENSE` or `.github/workflows/neutrality-check.yml`** without a separate issue discussion first.
- **Tests**: the bridge has no automated test suite yet (adding one is in scope for contributions). At minimum, demonstrate manually that your action works on a real MODX install and include the ping response in the PR description showing the bridge version.

## What not to contribute

Some ideas are explicitly out of scope and will be closed without merging:

- **MODX 2.x compatibility.** Adding conditional class resolution for 2.x vs 3.x would double the bridge's complexity. If you want 2.x support, please open a separate repo with a 2.x-specific bridge.
- **Site-specific editorial rules.** Rules like "always use em-dash" or "always set rel=nofollow" belong in `optional/editorial-rules.md` as neutral examples, not in the core skill.
- **Authentication alternatives.** SSH key auth is the only supported mechanism. Password auth, OAuth, agent forwarding, jump hosts, etc. are user-side SSH config concerns, not bridge concerns. The skill intentionally uses `BatchMode=yes` to fail fast and stay non-interactive.
- **Web UI or GUI installer.** The skill is a CLI-only tool that integrates with Claude Code. A GUI would be a different project.
- **Anything that references a specific live site.** The neutrality check blocks PRs that mention any of the forbidden strings in `.github/workflows/neutrality-check.yml`.

## Security reports

Do not file security issues in the public issue tracker. See `docs/SECURITY.md` for the reporting process.
