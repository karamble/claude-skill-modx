# claude-skill-modx

A [Claude Code](https://claude.com/claude-code) skill for managing MODX Revolution 3.x websites. Point your Claude Code session at an installed copy of this skill, tell Claude which MODX site you want to work on, and Claude will deploy a small PHP CLI bridge to your server and drive every subsequent edit through JSON commands over SSH.

No Manager UI clicks. No web-editable endpoints. Just SSH + PHP + Claude.

## What it does

Once installed and initialized for a site, Claude can:

- Create, read, update, and delete resources (pages, articles, etc.)
- Create and edit chunks, templates, template variables, snippets, and categories
- Set and unset template variable values per resource
- Assign and unassign TVs to templates
- Clear the MODX cache
- Bulk-import elements or resources via the ModxTransfer extra (optional)

All actions run as the configured PHP user on your server via `runuser`, behind an Apache deny-all rule on the CLI directory, with a `PHP_SAPI` guard inside the bridge itself. Nothing is ever served over HTTP.

## What Claude learns from this skill

Beyond the bridge operations, this skill ships a self-contained MODX knowledge library so Claude can write correct MODX templates, chunks, and articles without guessing. The knowledge files teach Claude:

- **MODX tag syntax**: the unified `[[...]]` grammar for snippet calls, chunk calls, resource fields, placeholders, system settings, links, lexicon entries, comments, and output filters. Covers the critical `[[*field]]` vs `[[+placeholder]]` distinction that trips up every MODX newcomer.
- **Naming conventions**: templates, chunks, snippets, TVs, and resource aliases. Includes the list of reserved field names that must not be used as TV names.
- **Common extras**: how pdoTools, MIGX, FormIt, Collections, Tagger, SeoSuite, Image+, GoodNews, Login, reCaptcha, HybridAuth, TableOfContentsX, readingtime, modxMinify, and AutoSchema work, with typical usage patterns and the gotchas to avoid.

This means Claude can write, edit, and push a working MODX template or article in one session without needing an external MODX knowledge reference.

## Requirements

- **MODX Revolution 3.x** target site (3.0+). MODX 2.x is not supported in v0.1.
- **SSH access** to the server as a user who can `runuser` to the PHP user (commonly `root`).
- **PHP 8.1+** on the server (the version MODX 3.x runs on).
- **`runuser`** utility on the server (part of `util-linux`, present on Debian, Ubuntu, RHEL, and most managed hosts).
- **SSH key-based authentication** already set up between your workstation and the server.
- **Claude Code** installed locally.
- Optional: **ModxTransfer** extra on the target site if you want to use the `import_elements` and `import_resources` actions.

## Install

Clone the repo into your Claude Code skills directory:

```sh
git clone https://github.com/karamble/claude-skill-modx.git /tmp/claude-skill-modx
cd /tmp/claude-skill-modx
./install.sh
```

This copies the `skill/` subtree into `~/.claude/skills/modx/`. Nothing else on your system is touched. The `install.sh` script does not create `~/.config/modx-sites/` or any server-side files; both of those happen on first use when you run the init flow through Claude.

To uninstall:

```sh
./uninstall.sh
```

This removes `~/.claude/skills/modx/`. It intentionally leaves `~/.config/modx-sites/` alone so your site credentials survive a reinstall.

## First-run setup

After installing, open a Claude Code session in any directory (typically your local MODX project folder) and tell Claude something like:

> "I want to work on my MODX site."

Claude will detect that no site is configured yet, ask you for:

- A short alias for the site (e.g. `mysite`)
- SSH hostname
- SSH user (the user who can `runuser` to the PHP user)
- SSH port (defaults to 22)
- Optional SSH key path (defaults to your SSH agent)
- PHP user (the POSIX user MODX runs as)
- PHP binary path (defaults to `php`)
- Web root (absolute path to the MODX docroot on the server)

Claude will write the credentials to `~/.config/modx-sites/<alias>.yaml` and a tiny pointer file `.modx-site.yaml` in your current directory, then deploy the bridge to `<web_root>/cli/modx-cli.php` and run a smoke ping to verify everything works. On subsequent sessions in the same project, Claude auto-detects the site from the pointer file and starts working immediately.

## Per-site configuration

The skill uses a two-file pattern to balance multi-site support against credential hygiene:

- **`.modx-site.yaml`** in your project directory holds only `site: <alias>`. Safe to commit.
- **`~/.config/modx-sites/<alias>.yaml`** holds the actual credentials (host, SSH user, PHP user, web root). Never committed.

Resolution walks up from `$PWD` looking for `.modx-site.yaml`, then reads the matching registry file. Falls back to `~/.config/modx-sites/default.yaml` if no pointer is found.

See `skill/templates/modx-site.yaml.example` for the full schema.

## Action reference

The complete list of JSON actions the bridge exposes, with required and optional fields and example payloads, lives in `skill/reference/actions.md` and `skill/reference/examples.md`. Error strings and common fixes are in `skill/reference/errors.md`. Debugging guidance, including the Collections extra gotcha and OPcache issues, is in `skill/reference/troubleshooting.md`.

## Optional editorial rules

If you maintain a MODX content site and want opinionated content conventions (long-dash avoidance, external link `rel` attributes, etc.), see `skill/optional/editorial-rules.md`. These rules are examples you can adopt, adapt, or discard. The skill does not enforce them by default.

## Security model

The bridge is invoked over SSH as a developer you trust. It assumes the entire server is already under that developer's control and exists purely to give that access a clean, idiomatic API surface rather than a Manager UI. It does not add privilege and does not create new attack surface when deployed correctly:

1. The `cli/` directory has an `.htaccess` that returns 403 for any HTTP request.
2. The bridge file itself has a `PHP_SAPI !== 'cli'` guard that returns 403 if somehow reached via HTTP.
3. The file is mode 0640, owned by the PHP user, not world-readable.
4. All actions execute as the PHP user via `runuser`, never as root, so MODX cache files keep correct ownership.

See `docs/SECURITY.md` for the full threat model.

## Related projects

There is a small but growing ecosystem around MODX and Claude. This skill is designed to complement, not replace, these other projects:

- **[crecorn/MODX-ClaudeSkill](https://github.com/crecorn/MODX-ClaudeSkill-)** is a knowledge skill that teaches Claude the MODX tag syntax, naming conventions, extras (pdoTools, MIGX, FormIt, Collections, Tagger), and structured data patterns. It ships no bridge and does not act on a site. **Install both**: this skill lets Claude _do_ things on your MODX site, `crecorn/MODX-ClaudeSkill` teaches Claude _what things mean_. They coexist without conflict.

- **[Finetuned/modx-cli](https://github.com/Finetuned/modx-cli)** is a Symfony Console based MODX CLI with a much larger command surface, Composer distribution, PHAR builds, multi-instance config, `@alias` shorthands, and a plugin system. If you want a full-featured CLI that runs directly on your workstation and shells into the server, use it instead of this skill. This skill is a drop-in PHP bridge with zero server-side dependencies, which makes it a better fit for managed hosts where you cannot install Composer globally, or for users who want the smallest possible attack surface on their server.

- **[Ibochkarev/revolution AGENTS.md](https://github.com/Ibochkarev/revolution/blob/main/AGENTS.md)** is the official AI assistant guide for contributing to MODX Revolution core itself. If you are patching the CMS rather than managing a site that runs it, read that file first.

This skill targets **site owners and content maintainers** who want Claude Code to handle day-to-day MODX operations (create articles, update templates, manage chunks, clear cache) over SSH with minimal setup and no server-side dependencies beyond PHP and `runuser`.

## License

MIT. See `LICENSE`.

## Contributing

Bug reports, feature requests, and pull requests welcome. See `docs/CONTRIBUTING.md` for how to add a new action to the dispatcher, how to run the lint and neutrality checks locally, and the PR requirements.

## Project status

v0.1.0 initial release. Scope: MODX 3.x only, `runuser` required, key-based SSH auth assumed. Future work on the v0.2 roadmap: MODX 2.x compatibility, `sudo` / `su` fallbacks for hosts without `runuser`, and an optional MCP server variant for native tool integration.
