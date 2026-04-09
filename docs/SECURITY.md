# Security model

This document describes the threat model for the MODX CLI bridge, the assumptions it makes about the deployment environment, and how to report security issues.

## Threat model

The bridge is a PHP script that runs on a MODX server in CLI mode, invoked over SSH from a trusted developer workstation. It exposes the full MODX ORM to anyone who can:

1. SSH into the server as the configured `ssh_user`, AND
2. Run a command that starts the PHP process as the `php_user` (typically via `runuser`)

Anyone who has both of those capabilities already has full control of the site via direct SSH and file editing. The bridge does not add privilege; it gives existing privilege a cleaner API surface.

### What the bridge protects against

1. **Accidental HTTP exposure.** Three independent layers prevent the bridge from being reachable over HTTP:
   - `PHP_SAPI !== 'cli'` guard at the top of the PHP file
   - Apache `.htaccess Require all denied` in the `cli/` directory
   - File mode 0640 owned by the PHP user (not world-readable)

2. **Cache file ownership drift.** Actions run as the PHP user via `runuser`, not as root. Cache files written by the bridge have the same ownership as cache files written by normal MODX page requests, so Apache can keep serving them.

3. **Command injection via JSON payloads.** The bridge decodes JSON with `json_decode()` in strict mode and passes values to MODX ORM methods, which use prepared statements via xPDO. User-supplied data never touches shell commands, filesystem paths (except via MODX's own path resolution), or `eval()`.

### What the bridge does NOT protect against

1. **A compromised SSH key.** If an attacker steals the user's SSH private key, they have the same access as the user. Use strong passphrases, keep keys in agents, rotate regularly.

2. **A compromised workstation.** Claude Code and any other tool on the workstation can invoke the bridge without additional authentication. Treat the workstation as a trusted device.

3. **A malicious `ssh_user`.** If the configured SSH user is itself compromised (e.g. a shared service account on a multi-tenant host), the bridge inherits that compromise. Use a dedicated account for MODX management where possible.

4. **Privilege escalation from the `php_user` to root.** The bridge runs as the PHP user, which has read and write access to the MODX file tree and database. An attacker who tricks the bridge into executing malicious MODX code can do anything the PHP user can do (which is significant, but not root-level).

5. **Race conditions against concurrent Manager users.** If a human is editing a resource in the Manager UI at the same time the bridge is updating it via `resource_update`, the last write wins. There is no locking.

## Deployment assumptions

The bridge assumes all of the following are true on the target server:

- MODX Revolution 3.x is installed at `<web_root>` with a valid `index.php`, `core/`, and a working database connection.
- The `<web_root>/cli/` directory exists or can be created, is writable by the PHP user, and is not served outside of the Apache deny rule.
- `runuser` is installed (`util-linux` package).
- The configured PHP binary is the same PHP version MODX was installed for (same extensions, same configuration).
- Apache (or the active web server) reads `.htaccess` files in the MODX docroot (`AllowOverride All`).
- The PHP user has full read and write access to `<web_root>`, `<web_root>/core/cache/`, and the database referenced by MODX's config.

If any assumption is violated, the bridge may partially work, return confusing errors, or (in the worst case) leave cache files with wrong ownership that break normal front-end rendering.

## Recommended hardening

Beyond the default deployment, consider the following if you are paranoid about your MODX site:

1. **Use a dedicated SSH user for MODX management.** Create a unix account whose only purpose is to invoke the bridge. Add it to `/etc/sudoers.d/` with a narrow `runuser` rule, not full sudo.

2. **Restrict the PHP binary path.** Set `php_binary: "/usr/bin/php8.2"` explicitly in the registry file. This avoids PATH manipulation attacks (low risk over SSH, but still a good habit).

3. **Audit the `cli/` directory periodically.** If any file other than `modx-cli.php` and `.htaccess` appears there, investigate immediately.

4. **Monitor the PHP error log.** Exceptions raised by the bridge are also written to the PHP error log. Tail the log during first-run deployment to catch bootstrap problems.

5. **Keep MODX itself patched.** The bridge is only as secure as the MODX install it bootstraps. Follow MODX's security announcements and apply updates.

6. **Do not check in the registry file.** `~/.config/modx-sites/<alias>.yaml` contains SSH and server details that should never appear in any git history. The default `.gitignore` in this repo blocks `*.local.yaml` and `.modx-site.yaml`, but the registry file lives outside the repo and is your responsibility to protect.

## Reporting a vulnerability

If you discover a security issue in the bridge or the supporting scripts, please do NOT open a public issue. Instead:

1. Open a private security advisory on the GitHub repository at https://github.com/karamble/claude-skill-modx/security/advisories
2. Or email the maintainer at the address listed on the karamble GitHub profile

Include:

- A description of the issue
- Steps to reproduce
- The version of the skill and the bridge (`bridge_version` from `ping`)
- Your assessment of the impact

Responses are best-effort; this is an open-source project maintained in spare time. Critical issues (remote code execution, authentication bypass, HTTP exposure of the bridge) will be acknowledged within 72 hours. Lesser issues may take longer.
