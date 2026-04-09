---
name: modx
description: Manage MODX Revolution 3.x sites over SSH via a JSON CLI bridge. Create, read, update, and delete resources, chunks, templates, template variables, snippets, and categories, and manage the MODX cache. Works with any MODX 3.x install once the bridge is deployed to the target server.
when-to-use: Use when the user is working in a directory with .modx-site.yaml, when the user explicitly mentions MODX (or modResource, chunks, template variables, TVs, MODX templates), or when the user is editing content for a MODX-powered website.
---

# MODX Revolution skill

A Claude Code skill for managing MODX Revolution 3.x websites. The skill wraps a small PHP CLI bridge that runs on the target server behind an Apache deny-all rule. Every action is a JSON object piped over SSH into the bridge, which dispatches into the MODX ORM and returns a JSON response.

## What this skill does

Once a MODX site is configured and the bridge is deployed, this skill lets you:

- List, read, create, update, and delete resources (pages, articles, containers)
- Manage chunks, templates, template variables (TVs), snippets, and categories
- Set TV values on individual resources
- Assign and unassign TVs from templates
- Clear the MODX cache after element mutations
- Bulk-import elements or resources via the optional ModxTransfer extra

Every action runs as the site's PHP user on the remote server via `runuser`, so MODX cache files keep correct ownership. The bridge file is guarded against HTTP access by both an `.htaccess` deny rule and a `PHP_SAPI` check inside the PHP file itself.

## Prerequisites

- The target site runs MODX Revolution 3.x (3.0 or newer). MODX 2.x is not supported in this version.
- SSH access to the server as a user (typically `root`) who can `runuser` to the PHP user.
- PHP 8.1 or newer on the server.
- The `runuser` utility on the server (part of `util-linux`).
- SSH key-based authentication already configured between the user's workstation and the server. This skill does not set up SSH keys.
- Optional: the ModxTransfer extra on the target site if `import_elements` or `import_resources` actions will be used.

## How to use this skill

The skill provides four helper scripts at `~/.claude/skills/modx/scripts/`:

- `detect-site.sh` — resolves which MODX site the current working directory is associated with
- `invoke.sh` — runs a JSON action against the resolved (or named) site
- `deploy-bridge.sh` — uploads the bridge PHP file to a configured site
- `init-site.sh` — interactive credential collection (users typically don't run this directly; see the first-run flow below)

### 1. Detect the active site

Before running any action, resolve which site the current project is configured for:

```sh
~/.claude/skills/modx/scripts/detect-site.sh
```

On success, this prints the full path to the matching `~/.config/modx-sites/<alias>.yaml` registry file. On failure, it exits non-zero and the first-run flow should be used instead.

The resolution rule: walk up from `$PWD` looking for a `.modx-site.yaml` pointer file. That file has a single key, `site: <alias>`, which maps to `~/.config/modx-sites/<alias>.yaml`. If no pointer is found, fall back to `~/.config/modx-sites/default.yaml`.

### 2. First-run self-setup (if detect-site fails)

If `detect-site.sh` exits non-zero, the skill has not been initialized for this project yet. Walk the user through the following, using `AskUserQuestion` to collect each value:

1. **Announce the flow** in plain language: explain that no site config exists for this project yet, and you need to collect SSH and MODX server details, deploy a small PHP bridge, and verify it works.

2. **Collect credentials** via `AskUserQuestion`. The set of questions:

   | Key | Question | Default |
   |---|---|---|
   | `alias` | Short name for this site (used as config filename) | — |
   | `host` | SSH hostname or IP | — |
   | `ssh_user` | SSH username | `root` |
   | `ssh_port` | SSH port | `22` |
   | `ssh_key` | Path to SSH private key (leave blank to use the SSH agent) | — |
   | `php_user` | POSIX user MODX runs as on the server | — |
   | `php_binary` | PHP binary path on the server | `/usr/bin/php` |
   | `web_root` | Absolute path to the MODX docroot on the server | — |

   Ask these in one or two batches of `AskUserQuestion` calls. Use "Other" text input for free-form values like hostnames and paths.

3. **Write the registry file** to `~/.config/modx-sites/<alias>.yaml` using the schema in `templates/modx-site.yaml.example`. Create the directory if needed and set its mode to `0700`. Set the file mode to `0600`.

4. **Write the pointer file** at `./.modx-site.yaml` in the current directory containing just `site: <alias>`.

5. **Test raw SSH connectivity** with `ssh <ssh_user>@<host> 'echo ok'`. If it fails, stop and point the user at `reference/troubleshooting.md`. Do not try to fix SSH auth; that is out of scope for the skill.

6. **Deploy the bridge** by running `~/.claude/skills/modx/scripts/deploy-bridge.sh <alias>`. This uploads the bridge PHP file and the `.htaccess` deny rule to `<web_root>/cli/`, sets the correct ownership and modes, and runs a `ping` smoke test.

7. **Check the ping result**. The response should include `ok: true`, `bridge_version`, `modx` (server version), `site_name`, `php` (PHP version), and `user`. If `user` does not match the configured `php_user`, warn loudly that `runuser` is not taking effect and halt.

8. **Check the HTTP guard** (optional but recommended). Run `curl -s -o /dev/null -w "%{http_code}" https://<host>/cli/modx-cli.php`. Expect `403` or `404`. If `200`, the `.htaccess` is not being read; halt and surface the issue.

9. **Report ready** to the user and continue with the original request.

### 3. Invoking actions (the normal case)

Once the site is configured and the bridge is deployed, every action is a single `invoke.sh` call. Pass the JSON payload on stdin or as a second argument.

```sh
# Auto-detected site, JSON on stdin
echo '{"action":"ping"}' | ~/.claude/skills/modx/scripts/invoke.sh

# Explicit site alias
~/.claude/skills/modx/scripts/invoke.sh mysite '{"action":"ping"}'

# Auto-detected site, JSON as argument
~/.claude/skills/modx/scripts/invoke.sh '{"action":"resource_list","parent":1}'
```

`invoke.sh` reads the registry file, constructs the SSH command, pipes the JSON into the remote bridge, and returns the bridge's stdout (which is JSON) on this script's stdout. Non-zero exit code means an error at the SSH or config layer; a JSON object with an `error` key in the response body means the bridge itself rejected the action.

For long payloads (chunk or template content, article HTML), use `jq` to construct the JSON from a file and pipe it in:

```sh
jq -n --rawfile content /path/to/body.html \
    '{action:"resource_create", fields:{pagetitle:"Title", content:$content, parent:1, template:1}}' \
  | ~/.claude/skills/modx/scripts/invoke.sh
```

### 4. Action reference

Full action reference with required keys, optional keys, return envelopes, and examples: `reference/actions.md`. Copy-paste examples grouped by task: `reference/examples.md`.

Rule: before constructing a payload for an action you have not used in the current session, consult `reference/actions.md`. Do not guess key names.

### 4a. MODX concept reference

This skill also ships a self-contained MODX knowledge library so Claude can write templates, chunks, and articles that actually work on a real MODX site without needing a separate knowledge skill. Consult these files when the task involves writing or editing MODX source (templates, chunks, snippets, TVs) rather than just dispatching bridge actions:

- **`reference/modx-tag-syntax.md`** — the unified `[[...]]` tag syntax for everything dynamic in MODX. Covers snippet calls, chunk calls, resource fields, placeholders, system settings, links, lexicon entries, comments, output filters, and the critical `[[*field]]` vs `[[+placeholder]]` distinction that trips up every MODX newcomer.
- **`reference/modx-naming.md`** — naming conventions for templates, chunks, snippets, TVs, categories, and resource aliases. Includes the list of reserved field names that must NOT be used as TV names (e.g. `description`, `content`, `alias`).
- **`reference/modx-extras.md`** — reference for the most common MODX extras (pdoTools, MIGX, FormIt, Collections, Tagger, SeoSuite, Image+, GoodNews, Login, reCaptcha, HybridAuth, TableOfContentsX, readingtime, modxMinify, AutoSchema). Each entry explains what the extra does, typical usage, and the most common gotchas.

Rule: before writing or editing a MODX template, chunk, snippet, or TV, consult the relevant concept reference file. Do not guess tag syntax or naming conventions based on other CMS experience; MODX has its own idioms.

Supported actions (v0.1.0):

- **System:** `ping`, `cache_clear`
- **Resources:** `resource_list`, `resource_get`, `resource_create`, `resource_update`, `resource_delete`
- **Chunks:** `chunk_list`, `chunk_get`, `chunk_create`, `chunk_update`, `chunk_delete`
- **Templates:** `template_list`, `template_get`, `template_create`, `template_update`, `template_delete`
- **TVs:** `tv_list`, `tv_get`, `tv_create`, `tv_update`, `tv_delete`, `tv_setvalue`, `tv_assign_template`, `tv_unassign_template`
- **Snippets:** `snippet_list`, `snippet_get`, `snippet_create`, `snippet_update`, `snippet_delete`
- **Categories:** `category_list`, `category_create`
- **Imports (ModxTransfer only):** `import_elements`, `import_resources`

### 5. Error handling

Exit codes from `invoke.sh`:

- `0` — success. stdout contains the bridge response.
- `1` — bad input, missing site alias, or registry file not found.
- `2` — required config key missing in the registry file.
- non-zero from SSH — connection failed, authentication failed, or remote command failed.

The bridge itself wraps thrown exceptions in a JSON envelope:

```json
{"error": "resource not found", "type": "Error", "file": "...", "line": 131}
```

When you see an error envelope, consult `reference/errors.md` for cause and fix. Do not retry blindly; diagnose first.

### 6. Verification after mutations

After any state-changing action, confirm the change before moving on:

- After `resource_create`, `resource_update`, or `resource_delete`: run `resource_get` with the id and verify the response matches the intended state. For create, also verify the `id` returned in the create response is consistent.
- After `chunk_create`, `chunk_update`, `template_create`, `template_update`, `tv_create`, `tv_update`, `snippet_create`, `snippet_update`: run the matching `*_get` action to verify content.
- After any **element** mutation (chunk, template, TV, snippet, category), run `cache_clear`. MODX caches compiled elements aggressively and stale caches will hide your change on the front end.
- Resource mutations (`resource_*`) do not require cache_clear for content changes, but do clear cache if you modified published state, pub_date, parent, or template.
- For anything that should be visible on the public site, curl the resource URL after cache clear to confirm it renders as expected.

### 7. Dangerous operations

The following actions require explicit user confirmation before you execute them:

- `resource_delete` with `hard: true` (permanent deletion, not moved to recycle bin)
- Any `*_delete` action without the option to soft-delete (`chunk_delete`, `template_delete`, `tv_delete`, `snippet_delete`)
- `import_elements` or `import_resources` (can overwrite many elements at once)
- `resource_update` that changes `parent`, `template`, `alias`, or `published` on a production resource
- Any operation touching more than 10 resources in a single batch

Announce the operation, explain the blast radius, and wait for explicit confirmation. A user saying "go ahead" or "yes" is required; silence or ambiguity is not consent.

### 8. Common workflows

Each workflow below is a sequence of actions that produces a concrete result. Full JSON examples are in `reference/examples.md`.

**Publish a new article:**
1. `resource_list` with the target parent to find the next available `menuindex`
2. `resource_create` with pagetitle, longtitle, description, introtext, content, parent, template, hidemenu, published, publishedon
3. Set TVs via the `tvs` object in the create payload (or `tv_setvalue` afterwards)
4. `cache_clear`
5. Curl the resource URL to verify it renders

**Update article content:**
1. `resource_get` to confirm the resource exists and fetch current fields
2. `resource_update` with the changed fields only (send `fields.content` with new HTML)
3. `cache_clear` only if published state or parent/template changed
4. Verify the rendered output

**Add a TV to a template:**
1. `template_get` to confirm the template exists
2. `tv_get` to confirm the TV exists
3. `tv_assign_template` with `tv` and `template` names
4. `cache_clear`

**Create a new chunk:**
1. `chunk_create` with name, content (HTML or MODX template syntax), optional category
2. `cache_clear`
3. `chunk_get` to verify

### 9. Limitations

- **MODX 2.x is not supported.** The bridge uses MODX 3.x namespaced classes (`MODX\Revolution\*`). A 2.x variant is on the v0.2 roadmap.
- **Core actions only.** Third-party MODX extras (Collections, Articles, Gallery, etc.) are not exposed as first-class verbs. However, the bridge returns `class_key` on resources so you can detect extras and work around them. See `reference/troubleshooting.md` for the Collections `show_in_tree` quirk.
- **`import_*` actions require ModxTransfer.** If the extra is not installed, those actions return an error and the user must install it first.
- **`runuser` is required.** Alternative privilege drops (sudo, su, direct SSH as the PHP user) are not supported in v0.1.
- **No interactive operations.** Everything runs non-interactively over SSH. Long-running operations will hold open the SSH connection.

### 10. Optional editorial rules

Some content teams maintain strict conventions about how articles are written (voice, long-dash avoidance, external link `rel` attributes, etc.). These rules are not part of the core skill because every site has different conventions. An example set of opinionated rules lives at `optional/editorial-rules.md` that users can adopt, adapt, or ignore.

If the user has copied or symlinked `optional/editorial-rules.md` into their project (or referenced it from their project's CLAUDE.md), load and follow those rules for content work. Otherwise, do not apply them.

### 11. Troubleshooting

Common problems and fixes live at `reference/troubleshooting.md`. It covers:

- SSH authentication failures
- Missing `runuser` on the server
- Bridge returns empty output
- Stale OPcache after bridge deployment
- ModxTransfer missing for `import_*` actions
- Collections extra `show_in_tree` gotcha (new articles disappearing from section listings)

## Reference files

**Bridge operations (what the skill can do):**
- `reference/actions.md` — full action reference
- `reference/examples.md` — copy-paste JSON payloads
- `reference/errors.md` — error envelope reference and common fixes
- `reference/troubleshooting.md` — operational gotchas and fixes

**MODX concepts (how MODX works, for writing templates, chunks, articles):**
- `reference/modx-tag-syntax.md` — `[[...]]` tag syntax and output filters
- `reference/modx-naming.md` — naming conventions and reserved field names
- `reference/modx-extras.md` — common MODX extras (pdoTools, MIGX, FormIt, Collections, etc.)

**Configuration and content:**
- `templates/modx-site.yaml.example` — config schema
- `optional/editorial-rules.md` — opt-in content conventions

**Deployed assets (sent to the server):**
- `bridge/modx-cli.php` — the PHP bridge source
- `bridge/modx-cli.htaccess` — Apache deny-all rule

**Helper scripts (run on the workstation):**
- `scripts/detect-site.sh` — resolves active site
- `scripts/invoke.sh` — runs JSON actions
- `scripts/deploy-bridge.sh` — uploads the bridge
- `scripts/init-site.sh` — interactive init helper for non-Claude users
