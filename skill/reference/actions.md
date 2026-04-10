# Action reference

Every JSON action the MODX CLI bridge exposes, with required keys, optional keys, and the shape of the response. All actions are sent via `invoke.sh`, which pipes the JSON on stdin to the remote bridge and returns the bridge's stdout. A response with an `error` key means the bridge rejected the action; see `errors.md`.

Conventions in this file:
- `required` means the key must be present or the bridge returns an error.
- `optional` means the bridge accepts the key but defaults are sensible if omitted.
- Responses are shown as abbreviated shapes. Full responses may include more keys.

---

## System

### `ping`

Bootstraps MODX and returns bridge and server metadata. Use this for smoke tests after deployment or config changes.

**Request:**
```json
{"action": "ping"}
```

**Response:**
```json
{
  "ok": true,
  "bridge_version": "0.2.0",
  "modx": "3.2.0-pl",
  "site_name": "My Site",
  "base_path": "/var/www/example.com/web/",
  "core_path": "/var/www/example.com/web/core/",
  "php": "8.2.10",
  "user": "web_user"
}
```

Pay attention to the `user` field. It should match the `php_user` in your registry config. If it does not, `runuser` is not taking effect.

---

### `cache_clear`

Refreshes the MODX cache. Run this after any chunk, template, TV, or snippet mutation.

**Request:**
```json
{"action": "cache_clear"}
```

**Response:**
```json
{"ok": true, "cache": "refreshed"}
```

---

### `setting_get`

Read a MODX system setting by key.

**Request keys:**
| Key | Required | Type |
|---|---|---|
| `key` | required | string |

**Request:**
```json
{"action": "setting_get", "key": "site_name"}
```

**Response:**
```json
{
  "key": "site_name",
  "value": "My Site",
  "xtype": "textfield",
  "namespace": "core",
  "area": "site"
}
```

---

### `setting_update`

Create or update a MODX system setting. If the key does not exist, it is created.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `key` | required | string | Setting key |
| `value` | required | string | Setting value |
| `xtype` | optional | string | Field type (e.g. `textfield`, `combo-boolean`, `numberfield`). Only used on create. |
| `namespace` | optional | string | Namespace (e.g. `core`, `seosuite`). Only used on create. |
| `area` | optional | string | Setting area. Only used on create. |

**Request:**
```json
{"action": "setting_update", "key": "site_name", "value": "New Name"}
```

**Response:**
```json
{"ok": true, "key": "site_name", "created": false}
```

After updating settings, run `cache_clear`.

---

### `context_setting_get`

Read a context-level setting.

**Request keys:**
| Key | Required | Type |
|---|---|---|
| `context_key` | required | string |
| `key` | required | string |

**Request:**
```json
{"action": "context_setting_get", "context_key": "de", "key": "locale"}
```

**Response:**
```json
{
  "context_key": "de",
  "key": "locale",
  "value": "de_DE",
  "xtype": "textfield",
  "namespace": "core",
  "area": "language"
}
```

---

### `context_setting_update`

Create or update a context-level setting. If the setting does not exist for the given context, it is created.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `context_key` | required | string | Context key (e.g. `web`, `de`, `en`) |
| `key` | required | string | Setting key |
| `value` | required | string | Setting value |
| `xtype` | optional | string | Field type. Only used on create. |
| `namespace` | optional | string | Namespace. Only used on create. |
| `area` | optional | string | Setting area. Only used on create. |

**Request:**
```json
{"action": "context_setting_update", "context_key": "de", "key": "locale", "value": "de_DE"}
```

**Response:**
```json
{"ok": true, "context_key": "de", "key": "locale", "created": true}
```

After updating context settings, run `cache_clear`.

---

## Resources

### `resource_list`

List child resources of a parent, optionally filtered by template or published state.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `parent` | optional | int | Parent resource id. If omitted, lists top-level resources. |
| `context` | optional | string | Context key (e.g. `web`, `de`, `en`). Filters by `context_key`. |
| `template` | optional | int or string | Template id or template name. |
| `published` | optional | bool | Filter by published state. |
| `limit` | optional | int | Maximum number of results to return. |

**Request:**
```json
{"action": "resource_list", "parent": 1}
```

**Response:** array of brief resource records.
```json
[
  {
    "id": 5,
    "pagetitle": "About",
    "alias": "about",
    "parent": 1,
    "template": 3,
    "class_key": "MODX\\Revolution\\modDocument",
    "published": true,
    "show_in_tree": 1,
    "menuindex": 0
  }
]
```

Results are sorted by `menuindex` ascending.

---

### `resource_get`

Fetch a single resource with all metadata and template variable values.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `id` | one of | int | Resource id. |
| `alias` | one of | string | Resource alias (must be globally unique within its context). |
| `context` | optional | string | Context key. Defaults to `web`. Used with `alias` lookups. |
| `exclude_content` | optional | bool | If `true`, omits the `content` body from the response. Default `false` — content is always included. |

**Request:**
```json
{"action": "resource_get", "id": 5}
```

**Response:** full resource record including TVs.
```json
{
  "id": 5,
  "pagetitle": "About",
  "longtitle": "About Our Team",
  "alias": "about",
  "description": "...",
  "introtext": "...",
  "menutitle": "",
  "parent": 1,
  "template": 3,
  "class_key": "MODX\\Revolution\\modDocument",
  "context_key": "web",
  "content_type": 1,
  "content_dispo": 0,
  "published": true,
  "publishedon": "2026-04-09 12:00:00",
  "pub_date": 0,
  "unpub_date": 0,
  "hidemenu": false,
  "show_in_tree": 1,
  "searchable": true,
  "deleted": false,
  "menuindex": 0,
  "uri": "about.html",
  "createdon": "2026-04-01 10:00:00",
  "createdby": 1,
  "editedon": "2026-04-09 12:00:00",
  "editedby": 1,
  "content": "<p>...</p>",
  "tvs": {
    "articleimage": "assets/images/about.jpg",
    "tags": "team,company"
  }
}
```

The `class_key` field tells you whether the resource is a plain document or belongs to an extra like Collections (`Collections\Model\CollectionContainer`). The `show_in_tree` field is significant on sites using the Collections extra; see `troubleshooting.md`.

The `tvs` object contains every TV that has a value for this resource: TVs formally assigned to the resource's template (via `modTemplateVarTemplate`) AND "floating" TVs that store values directly on the resource without a template assignment. The latter pattern is used by extras like Babel, which writes `babelLanguageLinks` (or whatever `babel.babelTvName` points to) on every translated resource.

---

### `resource_create`

Create a new resource. Accepts a `fields` object of modResource columns and an optional `tvs` object for template variable values.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `fields` | required | object | modResource columns to set. See below. |
| `tvs` | optional | object | Keyed by TV name. Values are strings, numbers, or arrays (auto-JSON-encoded for MIGX). |

**Common `fields` keys:**
- `pagetitle` (required for most use cases)
- `longtitle`, `description`, `introtext`, `menutitle`
- `alias` (auto-generated from pagetitle if omitted)
- `parent` (default 0 = root)
- `template` (default depends on MODX config)
- `content` (HTML or template syntax)
- `published` (0 or 1; default 0)
- `publishedon` (Unix timestamp or datetime string; MODX auto-sets if `published: 1` and omitted)
- `pub_date` (future Unix timestamp for scheduled publishing)
- `hidemenu` (0 or 1)
- `show_in_tree` (0 or 1; see Collections note in troubleshooting.md)
- `menuindex` (integer sort position within parent)
- `class_key` (defaults to `MODX\Revolution\modDocument`)

**Request:**
```json
{
  "action": "resource_create",
  "fields": {
    "pagetitle": "New Article",
    "longtitle": "A Longer Headline",
    "description": "SEO meta description around 150 characters.",
    "introtext": "Short excerpt shown on listing pages.",
    "content": "<p>Full article HTML here.</p>",
    "parent": 2,
    "template": 3,
    "hidemenu": 1,
    "published": 1,
    "menuindex": 10
  },
  "tvs": {
    "articleimage": "assets/images/articles/new-article.jpg",
    "tags": "news,update"
  }
}
```

**Response:**
```json
{"ok": true, "id": 123, "alias": "new-article"}
```

The response only confirms save. Run `resource_get` with the returned `id` to verify the stored state matches intent.

---

### `resource_update`

Update an existing resource. Any fields or TVs not included are left unchanged.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `id` | one of | int | Resource id. |
| `alias` | one of | string | Resource alias. |
| `context` | optional | string | Context key. Defaults to `web`. |
| `fields` | optional | object | modResource columns to update. |
| `tvs` | optional | object | TV values to update. |

**Request:**
```json
{
  "action": "resource_update",
  "id": 123,
  "fields": {
    "content": "<p>Updated body.</p>",
    "editedon": 1775758076
  }
}
```

**Response:**
```json
{"ok": true, "id": 123, "alias": "new-article"}
```

---

### `resource_delete`

Delete a resource. By default performs a soft delete (sets `deleted = 1`, recoverable via the Manager). Pass `hard: true` to permanently remove.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `id` | one of | int | Resource id. |
| `alias` | one of | string | Resource alias. |
| `hard` | optional | bool | If `true`, permanently removes the row from the database. |

**Request:**
```json
{"action": "resource_delete", "id": 123}
```

**Response:**
```json
{"ok": true, "id": 123, "hard": false}
```

**Dangerous when `hard: true`** — always confirm with the user before sending this.

---

## Chunks

### `chunk_list`

List all chunks with id, name, description, and category.

**Request:**
```json
{"action": "chunk_list"}
```

**Response:** array of `{id, name, description, category}`.

---

### `chunk_get`

Fetch a chunk's full content and metadata.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `id` | one of | int | Chunk id. |
| `name` | one of | string | Chunk name. |

**Request:**
```json
{"action": "chunk_get", "name": "headerMenu"}
```

Or by id:
```json
{"action": "chunk_get", "id": 12}
```

**Response:**
```json
{
  "id": 12,
  "name": "headerMenu",
  "description": "Main navigation",
  "category": 2,
  "content": "<nav>...</nav>"
}
```

---

### `chunk_create` and `chunk_update`

Create a new chunk or update an existing one. The same action name (`chunk_update`) works for both; the bridge checks whether a chunk with the given name exists and creates or updates accordingly. You can also use `chunk_create` for clarity.

**Request keys:**
| Key | Required | Type |
|---|---|---|
| `name` | required | string |
| `content` | optional | string (chunk body) |
| `description` | optional | string |
| `category` | optional | int or string (category id or name) |

**Request:**
```json
{
  "action": "chunk_update",
  "name": "headerMenu",
  "content": "<nav>...</nav>",
  "description": "Main navigation",
  "category": "Navigation"
}
```

**Response:**
```json
{"ok": true, "name": "headerMenu", "id": 12, "created": false}
```

After any chunk change, run `cache_clear`.

---

### `chunk_delete`

**Request keys:**
| Key | Required | Type |
|---|---|---|
| `name` | required | string |

**Request:**
```json
{"action": "chunk_delete", "name": "obsoleteChunk"}
```

**Response:**
```json
{"ok": true, "name": "obsoleteChunk"}
```

**Dangerous.** Confirm with the user before running.

---

## Templates

### `template_list`

List all templates with id, name, description, and category.

---

### `template_get`

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `id` | one of | int | Template id. |
| `name` | one of | string | Template name (`templatename` column). |

**Request:**
```json
{"action": "template_get", "name": "BlogArticle"}
```

Or by id:
```json
{"action": "template_get", "id": 4}
```

**Response:** `{id, templatename, description, category, content}`

---

### `template_create` and `template_update`

Same dual-purpose pattern as chunks.

**Request keys:**
| Key | Required | Type |
|---|---|---|
| `name` | required | string |
| `content` | optional | string (template body) |
| `description` | optional | string |
| `category` | optional | int or string |

**Response:** `{ok, templatename, id, created}`

Run `cache_clear` after.

---

### `template_delete`

**Dangerous.** Removes a template. Resources currently using the template may end up orphaned. Always confirm.

---

## Template variables (TVs)

### `tv_list`

Lists all TVs with id, name, caption, and type.

---

### `tv_get`

Fetches a TV's full metadata including which templates it is assigned to.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `id` | one of | int | TV id. |
| `name` | one of | string | TV name. |

**Response:**
```json
{
  "id": 1,
  "name": "articleimage",
  "caption": "",
  "description": "",
  "type": "image",
  "default": "",
  "elements": null,
  "display": "default",
  "category": 13,
  "templates": ["BlogArticle"]
}
```

---

### `tv_create` and `tv_update`

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `name` | required | string | TV name |
| `caption` | optional | string | Human-readable label |
| `description` | optional | string | |
| `type` | optional | string | TV type: `text`, `textarea`, `richtext`, `image`, `file`, `listbox`, `checkbox`, `radio`, `autotag`, `migx`, etc. |
| `default` | optional | string | Default value |
| `elements` | optional | string | For listbox/radio: pipe-separated options like `opt1\|\|opt2\|\|opt3` |
| `display` | optional | string | Usually `default` |
| `category` | optional | int or string | |

Run `cache_clear` after.

---

### `tv_assign_template`

Attach an existing TV to an existing template so that resources using the template can set values for it.

**Request keys:**
| Key | Required | Type |
|---|---|---|
| `tv` | required | string (TV name) |
| `template` | required | int or string (template id or name) |

**Response:**
```json
{"ok": true, "assigned": "articleimage -> BlogArticle"}
```

If the TV is already assigned, returns `{"ok": true, "already_assigned": true}`.

---

### `tv_unassign_template`

Reverse of `tv_assign_template`.

**Request keys:** `tv`, `template`

---

### `tv_delete`

**Dangerous.** Removes a TV and all its values across all resources.

---

### `tv_setvalue`

Set a specific TV value on a specific resource.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `tv` | required | string | TV name |
| `id` | one of | int | Resource id |
| `alias` | one of | string | Resource alias |
| `value` | required | string or array | Value to set. Arrays are JSON-encoded automatically (useful for MIGX TVs). |

**Request:**
```json
{
  "action": "tv_setvalue",
  "tv": "articleimage",
  "id": 123,
  "value": "assets/images/articles/hero.jpg"
}
```

**Response:**
```json
{"ok": true, "tv": "articleimage", "resource": 123}
```

---

## Snippets

### `snippet_list`, `snippet_get`, `snippet_create` / `snippet_update`, `snippet_delete`

Identical shape to chunks. `snippet_get` accepts either `id` or `name` (same as `chunk_get`). Snippet `content` is PHP source code. Run `cache_clear` after any change.

---

## Categories

### `category_list`

Returns all categories with `id`, `category` (name), and `parent`.

---

### `category_create`

**Request keys:**
| Key | Required | Type |
|---|---|---|
| `name` | required | string |
| `parent` | optional | int or string (parent category id or name) |

**Response:**
```json
{"ok": true, "id": 15, "name": "Articles"}
```

If a category with the same name already exists, returns `{"ok": true, "id": <existing_id>, "already_exists": true}`.

---

## Imports (ModxTransfer-dependent)

These two actions require the [ModxTransfer](https://github.com/modxcms/modxtransfer) extra to be installed on the target MODX site. If it is not installed, the bridge returns an error.

### `import_elements`

Bulk import chunks, templates, TVs, snippets, and categories from a JSON export file on the server.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `file` | required | string | Path relative to `MODX_BASE_PATH` on the server. Must exist. |
| `update` | optional | bool | Update existing elements (default `true`) or skip them. |

**Request:**
```json
{"action": "import_elements", "file": "assets/imports/elements.json"}
```

**Dangerous.** Can overwrite many elements at once. Always confirm with the user and ideally run a diff against the source file before sending.

---

### `import_resources`

Bulk import resources from a JSON export file.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `file` | required | string | Path relative to `MODX_BASE_PATH`. |
| `update` | optional | bool | Update existing resources. Default `true`. |
| `parentId` | optional | int | Target parent id for imported resources. Default 0. |

**Dangerous.** Same caveats as `import_elements`.

---

## Packages

### `package_list`

List all installed MODX extras with version information.

**Request:**
```json
{"action": "package_list"}
```

**Response:** array of installed packages.
```json
[
  {
    "signature": "seosuite-3.2.0-pl",
    "name": "seosuite",
    "version": "3.2.0",
    "release": "pl",
    "installed": "2026-03-25, 20:38",
    "provider": 1
  }
]
```

---

### `package_search`

Search the MODX extras repository for packages.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `query` | required | string | Search term |
| `provider` | optional | int | Provider id. Default `1` (modx.com). |
| `limit` | optional | int | Max results. Default `10`. |

**Request:**
```json
{"action": "package_search", "query": "seosuite"}
```

**Response:** array of available packages.
```json
[
  {
    "id": "a17ca68c-e199-443a-81c2-9e5adf75b7f5",
    "name": "SEO Suite",
    "version": "3.2.1",
    "release": "pl",
    "signature": "SEO Suite-3.2.1-pl",
    "description": "...",
    "author": "Sterc",
    "downloads": 12345
  }
]
```

---

### `package_check_updates`

Check if an installed package has a newer version available.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `signature` | required | string | Installed package signature (e.g. `seosuite-3.2.0-pl`) |

**Request:**
```json
{"action": "package_check_updates", "signature": "seosuite-3.2.0-pl"}
```

**Response:**
```json
{
  "ok": true,
  "updates": [
    {
      "signature": "seosuite-3.2.1-pl",
      "version": "3.2.1",
      "release": "pl",
      "changelog": "- Fix relation definitions...",
      "location": "https://rest.modx.com/extras/download/...",
      "info": "https://rest.modx.com/extras/download/...::seosuite-3.2.1-pl"
    }
  ],
  "up_to_date": false
}
```

When no updates are available: `{"ok": true, "updates": [], "up_to_date": true}`

---

### `package_install`

Download and install a package from the repository. Use the `info` URL from `package_check_updates` or `package_search`, or provide a `signature` for a previously downloaded package.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `info` | one of | string | Download info URL from `package_check_updates` or `package_search` |
| `signature` | one of | string | Signature of an already-downloaded package |
| `provider` | optional | int | Provider id. Default `1`. Used with `info`. |

**Request:**
```json
{"action": "package_install", "info": "https://rest.modx.com/extras/download/...::seosuite-3.2.1-pl"}
```

**Response:**
```json
{"ok": true, "signature": "seosuite-3.2.1-pl", "message": ""}
```

**Dangerous.** Installing or updating a package can modify database tables, run PHP installers, and change system behavior. Always confirm with the user before executing.

---

### `package_update`

Update an installed package to the latest available version. This downloads and installs the newest version from the repository.

**Request keys:**
| Key | Required | Type |
|---|---|---|
| `signature` | required | string |

**Request:**
```json
{"action": "package_update", "signature": "seosuite-3.2.0-pl"}
```

**Response:**
```json
{"ok": true, "message": ""}
```

**Dangerous.** Same caveats as `package_install`.

---

### `package_uninstall`

Uninstall a package. This runs the package's uninstall script and removes its components.

**Request keys:**
| Key | Required | Type |
|---|---|---|
| `signature` | required | string |

**Request:**
```json
{"action": "package_uninstall", "signature": "seosuite-3.2.0-pl"}
```

**Response:**
```json
{"ok": true, "message": ""}
```

**Dangerous.** Uninstalling a package removes its database tables, chunks, snippets, plugins, and other elements. This is destructive and cannot be undone without a backup.
