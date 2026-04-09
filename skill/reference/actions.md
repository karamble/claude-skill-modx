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
  "bridge_version": "0.1.0",
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

## Resources

### `resource_list`

List child resources of a parent, optionally filtered by template or published state.

**Request keys:**
| Key | Required | Type | Notes |
|---|---|---|---|
| `parent` | optional | int | Parent resource id. If omitted, lists top-level resources. |
| `template` | optional | int or string | Template id or template name. |
| `published` | optional | bool | Filter by published state. |

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
| `context` | optional | string | Context key. Defaults to `web`. |
| `include_content` | optional | bool | If `true`, includes the full `content` body. Default `false` to keep responses small. |

**Request:**
```json
{"action": "resource_get", "id": 5, "include_content": true}
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
| Key | Required | Type |
|---|---|---|
| `name` | required | string |

**Request:**
```json
{"action": "chunk_get", "name": "headerMenu"}
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
| Key | Required | Type |
|---|---|---|
| `name` | required | int or string (id or template name) |

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
| Key | Required | Type |
|---|---|---|
| `name` | required | string |

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

Identical shape to chunks. Snippet `content` is PHP source code. Run `cache_clear` after any change.

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
