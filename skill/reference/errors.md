# Errors

Every error envelope the MODX CLI bridge can return, with cause and fix. The bridge wraps thrown exceptions in a JSON object:

```json
{"error": "message", "type": "ExceptionClass", "file": "...", "line": 131}
```

When you see an error envelope in a response, stop and diagnose before retrying.

---

## Bootstrap and dispatch errors

### `MODX failed to bootstrap`

The bridge could not load MODX from `dirname(__DIR__) . '/index.php'`. Causes:

- The bridge file is not in `<web_root>/cli/` (i.e. one directory below the MODX docroot)
- The MODX docroot does not contain an `index.php` entry point
- File permissions prevent the PHP user from reading the MODX core files

**Fix:** Verify the bridge is deployed to the correct path. Run `ls -la <web_root>/index.php` on the server and confirm the PHP user can read it. Re-run `deploy-bridge.sh`.

---

### `no JSON command received on stdin`

The bridge was invoked but stdin was empty. This usually means the calling code forgot to pipe the JSON payload.

**Fix:** Always pass the JSON via `echo '...' | invoke.sh` or `invoke.sh <alias> '<json>'`. Check the command history if you're running manually.

---

### `invalid JSON or missing 'action': <parser error>`

stdin contained text but it was not valid JSON, or the JSON object had no `action` key.

**Fix:** Validate the JSON with `jq` before sending. Make sure the top-level object has `{"action": "..."}`.

---

### `unknown action: <name>`

The bridge does not recognize the action name. Common causes:

- Typo in the action name
- Using a verb from a later bridge version against an older deployed bridge
- Trying to use a third-party extra action that the bridge does not expose as a first-class verb

**Fix:** Check `reference/actions.md` for the correct name. If you're using a new action, verify that the deployed bridge on the server is at the same version as your local skill (run `ping` and compare `bridge_version`).

---

## Resource errors

### `resource not found`

Returned by `resource_get`, `resource_update`, `resource_delete`, and `tv_setvalue` when the given `id` or `alias` does not match any existing resource.

**Fix:** Run `resource_list` to find the correct id. Double-check the `context` if you're using `alias`; contexts default to `web`.

---

### `save failed`

Returned by `resource_create`, `resource_update`, `chunk_create`, `chunk_update`, `template_create`, `template_update`, `tv_create`, `tv_update`, `snippet_create`, `snippet_update`, `category_create`, and `tv_assign_template` when MODX's `save()` method returned false.

Causes:

- A required field is missing (e.g. `pagetitle` for resources, `name` for chunks)
- Alias collision (trying to create a resource with an alias that already exists in the same context)
- Database constraint violation
- PHP user lacks write permission on MODX cache directories

**Fix:** Double-check all required fields are present and have valid values. For alias collisions, either pick a unique alias or use `resource_update` on the existing resource.

---

### `remove failed`

Returned by `resource_delete` with `hard: true` when the database row could not be removed.

**Fix:** This is rare. Usually indicates a foreign key constraint (child resources, TV values, or cache entries still referencing the resource). Soft-delete instead, or clean up references first.

---

## Element errors

### `chunk not found`, `template not found`, `tv not found`, `snippet not found`

The named element does not exist.

**Fix:** Run the matching `*_list` action to see what does exist. Check spelling.

---

### `tv not found` (on `tv_assign_template` or `tv_unassign_template`)

Either the TV or the template name is wrong. The error does not specify which.

**Fix:** Run `tv_list` and `template_list` to verify both names exist.

---

### `template not found` (on `tv_assign_template`)

The template name could not be resolved. Note that `template` can be either an id (integer) or a template name (string); mismatched types can cause this.

**Fix:** Use the exact template name or the integer id.

---

## TV errors

### `tv save failed` (on `tv_setvalue`)

Setting the TV value failed. Causes:

- The resource exists but the TV is not assigned to that resource's template
- The value type does not match the TV type (e.g. trying to set a checkbox TV to a complex object)

**Fix:** Run `tv_get` and check the `templates` field to confirm the TV is assigned to the resource's template. If not, run `tv_assign_template` first.

---

## Import errors

### `file not found: <path>`

Returned by `import_elements` and `import_resources` when the given `file` path does not exist on the server.

**Fix:** The `file` path is resolved relative to `MODX_BASE_PATH` on the server. Verify the file exists at that absolute path by running `ls -la <web_root>/<file>`.

---

### `invalid json in file`

The file exists but its contents are not valid JSON.

**Fix:** Run `jq . <file>` to validate locally before uploading. Re-export from the source site.

---

### `ModxTransfer` require_once failure

If you see a PHP fatal referencing `modxtransfer.class.php`, the ModxTransfer extra is not installed on the target site.

**Fix:** Install the ModxTransfer extra via the MODX Manager (Extras > Installer) and re-run the import.

---

## Category errors

### `save failed` (on `category_create`)

Usually means the category name is invalid (empty string, too long) or there is a database constraint violation.

**Fix:** Verify the name is non-empty. Try a shorter name if the original was long.

---

## Unknown type or unexpected error

### A response with an `error` key and a `type` that is not documented above

The bridge caught a PHP exception outside the expected paths. The `file` and `line` fields point to where in the dispatcher the exception was caught.

**Fix:** Check the server's PHP error log (`tail -n 100 /var/log/php_errors.log` or the site-specific log) for the full stack trace. This usually indicates a problem in MODX itself or in an extra, not the bridge.

---

## Exit codes from `invoke.sh`

When `invoke.sh` exits non-zero without an error envelope in the response, something broke at the SSH or config layer, not inside the bridge:

| Exit code | Cause |
|---|---|
| `0` | Success |
| `1` | Bad args, site alias not found in registry, or JSON payload missing |
| `2` | Required config key missing in the registry YAML file |
| `255` | SSH connection failed (network, key auth, wrong user) |
| other | Remote command returned that exit code |

For SSH-level failures, see `troubleshooting.md`.
