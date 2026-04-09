# Changelog

All notable changes to this project will be documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `deploy-bridge.sh`: `ssh_run()` and `scp_to()` referenced `$1` / `$2` *after* `set --` had already replaced the positional parameters with the `ssh`/`scp` command and its flags. As a result, the SSH smoke check ran `ssh` as the remote command (exit 255, surfaced as "SSH connection ... failed") and `scp_to` would have uploaded the wrong paths. Both functions now snapshot their arguments into locals before the first `set --`.
- `resource_get` silently dropped TV values for TVs not formally assigned to the resource's template via `modTemplateVarTemplate`, because `fullResource()` only iterated `$r->getTemplateVars()`. This hid "floating" TVs that store values directly on a resource, most notably Babel's `babelLanguageLinks`, making a successful `tv_setvalue` look like it had silently failed. `fullResource()` now does a second pass over `modTemplateVarResource` rows for the resource id and merges any un-seen TV values into the response.
- `template_get`, `tv_get`, `chunk_get`, and `snippet_get` previously required a `name` key in the payload and leaked a PHP `Undefined array key "name"` warning plus a generic "not found" error when the caller passed `id` instead. All four actions now accept either `id` (numeric PK lookup) or `name`, matching the convention already used by `resource_get` and `tv_setvalue`, and return a clear `{"error": "missing id or name"}` when neither is provided. A new `loadElement()` helper centralises the id-or-name lookup for chunks, snippets, and TVs (templates continue to use the existing `resolveTemplate()` helper because their name column is `templatename` rather than `name`). `reference/actions.md` updated to document the accepted keys on all four actions.
- `resource_create` and `resource_update` now auto-manage `publishedon` and `publishedby` on published-state transitions, matching the behavior of the MODX Manager's `Publish` / `Unpublish` / `Create` processors. Previously the bridge called `$r->save()` directly on the domain object, which bypasses the processor layer where that auto-set logic lives, leaving freshly-published resources with `publishedon=0`. Date-sorted listings built on getResources / pdoResources treat `publishedon=0` as "never published", so a bridge-published article could silently drop out of "latest news" feeds and archives despite returning HTTP 200 on its direct URL. A new `autoManagePublishedTimestamps()` helper sets `publishedon = time()` and `publishedby = <current user id>` on a 0→1 transition, clears both on a 1→0 transition, and is a no-op when `published` doesn't change. An explicit caller-provided `publishedon` or `publishedby` in the same request always wins.

### Added

- `resource_get` now exposes `publishedby` in the full response alongside `createdby` and `editedby`. Previously the field was set correctly on writes but omitted from read-back, which made it impossible to confirm via the bridge whether a publish transition had attributed the correct user without falling back to direct SQL or a server-side PHP script.

## [0.1.0] - 2026-04-09

Initial release.

### Added

- PHP CLI bridge (`skill/bridge/modx-cli.php`) that bootstraps MODX Revolution 3.x in API mode and dispatches JSON commands from stdin.
- Apache deny-all rule (`skill/bridge/modx-cli.htaccess`) to block HTTP access to the bridge directory.
- Claude Code skill definition (`skill/SKILL.md`) describing the site detection, first-run setup, invocation, verification, and error handling flow.
- Helper scripts: `init-site.sh` (interactive credential collection), `deploy-bridge.sh` (scp + chown + chmod + smoke ping), `invoke.sh` (hot-path SSH wrapper), `detect-site.sh` (walks up from `$PWD` to find `.modx-site.yaml`).
- Reference documentation: full action reference (`reference/actions.md`), copy-paste examples (`reference/examples.md`), error envelope and common fixes (`reference/errors.md`), troubleshooting guide including the Collections extra `show_in_tree` gotcha (`reference/troubleshooting.md`).
- Per-site config template (`templates/modx-site.yaml.example`).
- Opt-in editorial companion rules (`optional/editorial-rules.md`) as examples only.
- Install and uninstall scripts (`install.sh`, `uninstall.sh`) that copy the skill tree into `~/.claude/skills/modx/` and leave `~/.config/modx-sites/` alone on removal.
- GitHub Actions workflows for shellcheck, PHP lint across 8.1/8.2/8.3, and a neutrality check that blocks any PR referencing private site identifiers.
- Contributor documentation (`docs/ARCHITECTURE.md`, `docs/CONTRIBUTING.md`, `docs/SECURITY.md`).

### Supported actions

- System: `ping`, `cache_clear`
- Resources: `resource_list`, `resource_get`, `resource_create`, `resource_update`, `resource_delete`
- Chunks: `chunk_list`, `chunk_get`, `chunk_create`, `chunk_update`, `chunk_delete`
- Templates: `template_list`, `template_get`, `template_create`, `template_update`, `template_delete`
- Template variables: `tv_list`, `tv_get`, `tv_create`, `tv_update`, `tv_delete`, `tv_setvalue`, `tv_assign_template`, `tv_unassign_template`
- Snippets: `snippet_list`, `snippet_get`, `snippet_create`, `snippet_update`, `snippet_delete`
- Categories: `category_list`, `category_create`
- Imports (ModxTransfer-dependent): `import_elements`, `import_resources`

### Not yet supported

- MODX Revolution 2.x (uses un-namespaced classes; deferred to v0.2)
- Non-`runuser` privilege drop mechanisms (sudo, su, direct ssh as PHP user)
- Password-based SSH authentication
- Interactive SSH key generation and `ssh-copy-id` automation
- An MCP server variant for native tool schemas
