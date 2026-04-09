# Architecture

This document explains how the MODX CLI bridge and the surrounding Claude Code skill fit together at runtime. It is written for contributors; end users do not need to read it.

## The moving parts

```
  +-----------------------+         +----------------------+
  |   User's workstation  |  SSH    |    MODX 3.x server   |
  |                       | +-----> |                      |
  |  ~/.claude/skills/    |         |  <web_root>/cli/     |
  |    modx/              |         |    modx-cli.php      |
  |      SKILL.md         |         |    .htaccess         |
  |      scripts/         |         |                      |
  |        invoke.sh      |         |    <web_root>/       |
  |        detect-site.sh |         |      index.php       |
  |        deploy-bridge.sh         |      (MODX bootstrap)|
  |      bridge/          |         |                      |
  |        modx-cli.php   |         |  MODX core + DB      |
  |      reference/       |         |                      |
  |      templates/       |         +----------------------+
  |      optional/        |
  |                       |
  |  ~/.config/modx-sites/|
  |    <alias>.yaml       |
  |                       |
  |  ~/project-dir/       |
  |    .modx-site.yaml    |
  +-----------------------+
```

Four layers:

1. **Claude Code** reads `SKILL.md` and decides when to invoke the skill based on the `when-to-use` trigger. It calls `invoke.sh` via the Bash tool with a JSON payload.
2. **`invoke.sh`** resolves the active site via `detect-site.sh`, reads the matching `~/.config/modx-sites/<alias>.yaml`, builds the SSH command, and pipes the JSON payload into the remote bridge.
3. **SSH** transports the JSON from the workstation to the server. The remote command is `runuser -u <php_user> -- <php_binary> <web_root>/cli/modx-cli.php`, with the JSON arriving on stdin.
4. **The PHP bridge** bootstraps MODX in API mode (`MODX_API_MODE = true`), parses the JSON, dispatches to the matching action handler, and writes a JSON response to stdout.

The response path is the same in reverse. SSH copies stdout back to the workstation, `invoke.sh` prints it, and Claude Code parses the JSON from the tool output.

## The bridge in detail

### Bootstrap

```php
define('MODX_API_MODE', true);
require dirname(__DIR__) . '/index.php';
```

Setting `MODX_API_MODE` before loading `index.php` tells MODX to bootstrap the full object graph (database, configuration, permissions, ORM) without running the frontend request handler. After this line, `$modx` is a fully initialized `MODX\Revolution\modX` instance ready for ORM calls.

The `dirname(__DIR__)` trick assumes the bridge lives in `<web_root>/cli/` and the MODX docroot is one directory up. If the bridge is deployed elsewhere, the path resolution breaks. This is intentional: the deployment contract is "bridge at `<web_root>/cli/modx-cli.php`, nothing else".

### Safety guards

Three layers of defense prevent the bridge from being accessible over HTTP:

1. **`PHP_SAPI !== 'cli'` check** at the very top of the file. If PHP is running under any non-CLI SAPI (Apache mod_php, PHP-FPM, CGI, whatever), the script returns HTTP 403 and exits immediately. This is the belt.
2. **Apache `.htaccess` Deny rule** in the `cli/` directory. Apache blocks the request before PHP is even invoked. This is the suspenders.
3. **File mode 0640 owned by the PHP user**. Even if the above two protections fail somehow, the file is not readable by the web server user (which is usually `www-data` or similar, not the PHP user MODX runs as). This is the belt around the suspenders.

### Dispatcher

The dispatcher is a single `switch` on `$cmd['action']` that routes to per-verb handlers. Each handler:

1. Extracts its required and optional keys from `$cmd`
2. Calls the appropriate MODX ORM methods
3. Returns an associative array

The array is JSON-encoded and written to stdout as the final step. Exceptions thrown from the handlers are caught at the top level and wrapped in an error envelope.

See `skill/bridge/modx-cli.php` for the full implementation. The dispatcher is a flat `switch` rather than a plugin registry because the action set is small enough that the switch is more readable than an abstraction layer.

### Field exposure

The `fullResource()` helper returns every core `modResource` column that might matter for debugging or operations:

- Identifiers: `id`, `alias`, `uri`, `class_key`, `context_key`
- Content fields: `pagetitle`, `longtitle`, `description`, `introtext`, `content` (optional)
- Hierarchy: `parent`, `template`, `menuindex`, `menutitle`
- Publishing state: `published`, `publishedon`, `pub_date`, `unpub_date`
- Tree and visibility: `hidemenu`, `show_in_tree`, `searchable`, `deleted`
- Audit: `createdon`, `createdby`, `editedon`, `editedby`
- Type details: `content_type`, `content_dispo`
- All template variables via `$r->getTemplateVars()`

This is deliberately exhaustive. Anything less and debugging "why does this resource not behave like the others" becomes an inline-PHP exercise over SSH.

### Extras agnosticism

The bridge never assumes any MODX extra is installed. It does not depend on Collections, Articles, Gallery, Tagger, or any third-party extra. The fields it exposes are core `modResource` columns; extras that store their metadata in those columns (like Collections using `class_key` and `show_in_tree`) are visible but not privileged.

This means:

- The bridge works on any MODX 3.x install out of the box
- Detection of extras happens in the caller (Claude) by inspecting `class_key` on resources
- Adding extras-specific verbs would couple the bridge to third-party code and is explicitly out of scope for v0.1

The one exception is `import_elements` / `import_resources`, which require ModxTransfer. Those actions return a clean error if ModxTransfer is not installed, and they are documented as optional.

## Configuration resolution

The two-file config pattern (`.modx-site.yaml` pointer plus `~/.config/modx-sites/<alias>.yaml` registry) is resolved by `detect-site.sh`:

1. Start in `$PWD`, walk up parents, stop at `$HOME` or `/`
2. At each directory, check for `.modx-site.yaml`
3. If found, read the `site:` key and return the matching registry file path
4. If no pointer found anywhere, fall back to `~/.config/modx-sites/default.yaml`
5. If nothing exists, exit non-zero with an init hint

This design is deliberate: secrets stay out of project directories, pointers stay in projects so detection is automatic, and there is no ambient dependency on environment variables.

## Why POSIX sh instead of Bash

All scripts in `skill/scripts/` use `#!/bin/sh` and avoid Bash-specific features. Reasons:

1. The scripts run on the user's workstation, not the MODX server. User workstations range from macOS (where `/bin/sh` used to be Bash but now dash or similar) to minimal Linux containers to FreeBSD. POSIX sh is the lowest common denominator.
2. The scripts do only simple things: parse YAML with sed, build argv arrays with `set --`, run SSH and SCP. None of this needs Bash features.
3. `shellcheck` lints POSIX sh consistently across systems.

If a future feature genuinely needs Bash (associative arrays, process substitution), that script can bump its shebang to `#!/bin/bash` as a localized exception.

## Why YAML for config instead of JSON

Readable by humans. Supports comments. Tolerates mixed quoting. Every modern developer has seen it. The parsing logic in `invoke.sh` is a one-line `sed` per key because the schema is flat; no YAML library is needed.

A JSON alternative would require `jq` on every user machine, or custom JSON parsing. We already rely on `jq` for constructing payloads, but requiring it for config reads is an extra burden.

## Why not an MCP server

Model Context Protocol servers would expose each bridge action as a native tool with schema validation, which is ergonomically nicer than JSON-on-stdin. A v0.2 MCP variant is on the roadmap.

For v0.1, the skill approach wins on simplicity:

- Skills ship as a directory of markdown and scripts, no runtime
- MCP servers ship as a long-running process that must be managed, restarted, and kept in sync with the skill
- The skill approach lets users inspect exactly what is happening via shell commands
- MCP adds a layer of abstraction that is valuable when you have 50+ tools; with our handful of actions, the abstraction is overhead

Both can coexist if the MCP variant arrives later: users can use the skill for drop-in simplicity and upgrade to MCP when they want more ergonomics.
