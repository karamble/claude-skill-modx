# Troubleshooting

Operational problems that are not JSON-level bridge errors. For JSON error envelopes returned by the bridge itself, see `errors.md`.

---

## SSH connection fails during `deploy-bridge.sh` or `invoke.sh`

Symptoms: scripts exit with SSH warnings or `Permission denied (publickey)`.

Checks:

1. **Can you SSH manually from the same shell?**
   ```sh
   ssh -p <ssh_port> <ssh_user>@<host> 'echo ok'
   ```
   If this fails, fix SSH auth first. The skill does not set up SSH keys.

2. **Is the SSH agent running and does it have your key loaded?**
   ```sh
   ssh-add -l
   ```
   If empty, add your key: `ssh-add ~/.ssh/id_ed25519`.

3. **If you use a non-default key, is the path set in the registry?**
   Edit `~/.config/modx-sites/<alias>.yaml` and set `ssh_key: "~/.ssh/your_key"`.

4. **Is `BatchMode=yes` blocking a password prompt?**
   The skill intentionally uses `BatchMode=yes` to fail fast. If you need password auth, the skill does not support it in v0.1. Set up key auth first.

5. **Is `StrictHostKeyChecking=accept-new` failing because the host key changed?**
   Edit `~/.ssh/known_hosts` to remove the stale entry, then retry. The script will accept the new key on first connection.

---

## `runuser: command not found` on the remote

Symptoms: the SSH connection succeeds but the remote command errors with `runuser: command not found`.

Cause: the server does not have `runuser` installed. It is part of `util-linux`, which is present on Debian, Ubuntu, RHEL, CentOS, Rocky, Alma, and most managed hosts. Alpine and some minimal container images omit it.

Fix for v0.1: install `util-linux` on the server. On Debian/Ubuntu:

```sh
apt-get update && apt-get install -y util-linux
```

On Alpine:

```sh
apk add util-linux
```

If you cannot install `util-linux`, the bridge cannot be used in its current form. A `sudo` / `su` fallback is on the v0.2 roadmap.

---

## Bridge ping works but `user` field does not match `php_user`

Symptoms: `ping` response shows `"user": "root"` (or some other user) when your config says `php_user: "web_user"`.

Cause: `runuser` is not dropping privileges. Common reasons:

1. **The invoking SSH user does not have permission to run `runuser -u`.** Only users who can escalate (usually `root`) can drop to another user. If you SSH as a non-root user, `runuser` silently runs as the current user instead.

2. **The MODX files are owned by root, not the PHP user.** Even if `runuser` works, MODX may fall back to the invoking user because of file permissions on the cache directories.

Fix: verify that the `ssh_user` in your registry file is a user who can `runuser -u <php_user>` without a password. `root` always can. Other users need to be in the `runuser` sudoers rule (uncommon). If you have to use a non-root SSH user, the bridge will work but cache file ownership may drift.

---

## `.htaccess` is not blocking HTTP access to the bridge

Symptoms: `curl https://<host>/cli/modx-cli.php` returns HTTP 200 (or the PHP `CLI only` message) instead of 403.

Cause: Apache is not reading `.htaccess` overrides in the MODX directory. Usually because the MODX vhost config has `AllowOverride None` or the `.htaccess` file is not present.

Fix:

1. **Verify the `.htaccess` file was uploaded:**
   ```sh
   ssh <user>@<host> "ls -la <web_root>/cli/.htaccess"
   ```
   If missing, re-run `deploy-bridge.sh`.

2. **Verify Apache is allowing overrides** for the MODX directory. Check the vhost config:
   ```
   <Directory /var/www/example.com/web>
       AllowOverride All
   </Directory>
   ```

3. **Restart Apache after config changes** (`systemctl reload apache2`).

4. **Fallback protection:** even if `.htaccess` is ignored, the `PHP_SAPI !== 'cli'` guard inside the bridge returns HTTP 403. Verify it works:
   ```sh
   curl -I https://<host>/cli/modx-cli.php
   ```
   Should return `HTTP/1.1 403 Forbidden`.

---

## Changes are saved but do not appear on the front end

Symptoms: `resource_update` returns `ok: true`, `resource_get` shows the new content, but the rendered page still shows the old version.

Cause: MODX cached the compiled page and the cache was not cleared.

Fix: run `cache_clear` after every mutation. If you did run it and the page is still stale, the PHP OPcache may be holding compiled bytecode. Restart PHP-FPM:

```sh
systemctl restart php-fpm  # or php8.2-fpm depending on version
```

If you cannot restart PHP-FPM, wait for the OPcache revalidation interval (usually 60 seconds on most configs).

---

## Collections extra: new articles do not appear in section listings

Symptoms: after creating a resource via `resource_create`, it exists in the database (visible via `resource_get` and `resource_list`), but it does not show up on the front-end listing for its parent section.

Cause: the parent resource is a `Collections\Model\CollectionContainer`, and the Collections extra's listing snippets filter children by `show_in_tree = 0`. When you create a resource via the bridge, MODX defaults `show_in_tree` to `1`, so the resource is "in the tree" (visible in the Manager tree view) but hidden from the Collections grid and front-end listings.

Detection:

```sh
# Get the parent and check its class_key
echo '{"action":"resource_get","id":<parent_id>}' | ~/.claude/skills/modx/scripts/invoke.sh
```

If the response shows `"class_key": "Collections\\Model\\CollectionContainer"`, the parent is a Collections container and the rule applies.

Fix: set `show_in_tree: 0` when creating or updating resources under a Collections container parent:

```json
{
  "action": "resource_create",
  "fields": {
    "pagetitle": "New Article",
    "parent": 2,
    "template": 3,
    "published": 1,
    "show_in_tree": 0,
    "menuindex": 20
  }
}
```

Also set a non-zero `menuindex` so the resource orders correctly in the Collections grid.

**This rule only applies when the parent is a Collections container.** On plain MODX sites without the Collections extra, leave `show_in_tree` at its default of 1. Forcing 0 on a plain site hides the resource from the Manager tree for no reason.

---

## ModxTransfer import actions fail

Symptoms: `import_elements` or `import_resources` returns a PHP fatal error or an empty response.

Cause: the ModxTransfer extra is not installed on the target site.

Fix: install ModxTransfer via the MODX Manager:

1. Log in to the Manager.
2. Go to **Extras > Installer**.
3. Search for **modxtransfer** and install.
4. Re-run the import action.

ModxTransfer is an optional dependency. The rest of the bridge works fine without it.

---

## Bridge version drift between skill and server

Symptoms: `ping` returns a `bridge_version` that does not match the version in your locally installed skill at `~/.claude/skills/modx/bridge/modx-cli.php`.

Cause: you updated the skill locally but did not redeploy the bridge to the server.

Fix: re-run `deploy-bridge.sh <alias> --force` to overwrite the server copy with the current local version.

---

## HTTP 500 from the bridge

Symptoms: the bridge returns a PHP fatal error or the response is truncated/garbled.

Cause: almost always a problem in MODX itself or an installed extra, not the bridge. Common cases:

- A corrupted element (chunk, template, snippet) with invalid PHP or MODX template syntax
- An expired MODX license for a commercial extra
- A recent MODX core upgrade that broke an extra
- Missing PHP extension required by a MODX extra

Fix: check the PHP error log on the server. The bridge preserves the original error location in the exception envelope, so the response usually includes `file` and `line` pointing at the offending file.

---

## `posix_getpwuid` returns `unknown` in ping response

Symptoms: `ping` returns `"user": "unknown"` even though the bridge is running correctly.

Cause: PHP was compiled without the `posix` extension (uncommon on Linux, more common on Windows or minimal PHP builds).

Fix: install `php-posix` on the server:

```sh
apt-get install php8.2-posix  # or the version matching your install
```

The bridge still works without it; the `user` field just cannot be reported.
