# MODX tag syntax reference

MODX Revolution uses a unified `[[...]]` tag syntax for everything dynamic in templates, chunks, and content. This file is a fast-lookup reference for the tag types, their prefixes, and their quirks. Keep it open while editing MODX templates or chunks.

---

## Tag type summary

| Tag | Syntax | What it renders |
|---|---|---|
| Snippet | `[[snippetName? &param=\`value\`]]` | Output of a PHP snippet |
| Cached snippet | `[[snippetName]]` | Same, but cached (no leading `!`) |
| Uncached snippet | `[[!snippetName]]` | Re-runs on every request |
| Chunk | `[[$chunkName]]` | Chunk content (pre-parsed reusable HTML) |
| Chunk with properties | `[[$chunkName? &prop=\`value\`]]` | Chunk with placeholder substitution |
| Resource field | `[[*pagetitle]]` | Field of the current resource |
| Template variable | `[[*tvName]]` | Value of a TV on the current resource |
| System setting | `[[++site_name]]` | Value of a system setting |
| Placeholder | `[[+placeholderName]]` | Value of a placeholder set by a snippet |
| Link | `[[~123]]` | URL of resource id 123 |
| Link with scheme | `[[~123? &scheme=\`full\`]]` | Absolute URL of resource id 123 |
| Language string | `[[%lexiconKey]]` | Localized text from a lexicon |
| Comment | `[[- this is a comment -]]` | Nothing (removed from output) |

---

## Tag prefixes explained

The first character after `[[` determines the tag type:

| Prefix | Type | Example |
|---|---|---|
| (none) | Snippet (cached) | `[[pdoResources]]` |
| `!` | Uncached snippet | `[[!FormIt]]` |
| `$` | Chunk | `[[$siteHeader]]` |
| `*` | Resource field or TV | `[[*pagetitle]]`, `[[*articleimage]]` |
| `+` | Placeholder | `[[+author]]` |
| `++` | System setting | `[[++site_url]]` |
| `~` | Resource link | `[[~1]]` |
| `%` | Lexicon entry | `[[%home_link]]` |
| `-` | Comment | `[[- note -]]` |

---

## Snippet calls

A snippet is a PHP function that returns a string. Call it with parameters using the `?` and backtick-wrapped values:

```
[[pdoResources?
    &parents=`0`
    &limit=`10`
    &tpl=`articleRowTpl`
    &includeTVs=`articleimage,tags`
]]
```

**Cached vs uncached.** A cached call runs once per cache generation and stores the output with the page cache. An uncached call (`[[!snippetName]]`) runs on every request. Use uncached for things that change per request (forms, search results, login state) and cached for things that are stable (navigation, article lists that regenerate only when articles change).

**Nested tags inside parameters.** You can reference other tags inside snippet parameters:

```
[[pdoResources?
    &parents=`[[*id]]`
    &tpl=`[[*template:is=`3`:then=`articleTpl`:else=`pageTpl`]]`
]]
```

---

## Chunk calls

Chunks are reusable HTML snippets with placeholder interpolation. Call with `$`:

```
[[$siteHeader]]
```

With properties:

```
[[$articleCard?
    &title=`[[*pagetitle]]`
    &image=`[[*articleimage]]`
    &summary=`[[*introtext]]`
]]
```

Inside the chunk, access properties via `[[+title]]`, `[[+image]]`, `[[+summary]]`.

---

## Resource fields vs placeholders

This is the single most confusing part of MODX for newcomers. The rule:

- **`[[*field]]`** is the current resource's own field or TV. Works in templates and chunks rendering as part of that resource.
- **`[[+field]]`** is a placeholder set by a snippet. Works inside snippet-provided templates (row templates for `pdoResources`, message templates for `FormIt`, etc.).

### When to use `[[*field]]`

- In the main content or template of a resource
- In a chunk called from the resource's template
- When referring to the current page's pagetitle, longtitle, content, pub_date, or TVs

### When to use `[[+field]]`

- In a row template for `pdoResources`, `getResources`, `getPage`
- In a chunk used as the `tpl` parameter of a snippet
- When processing form data inside a `FormIt` success or error template
- When a snippet explicitly sets placeholders with `$modx->setPlaceholder()`

### Common mistake

Using `[[*pagetitle]]` inside a `pdoResources` row template will render the CURRENT page's title repeatedly, not the title of each resource in the list. Use `[[+pagetitle]]` inside row templates.

```
[[pdoResources?
    &parents=`0`
    &tpl=`articleRowTpl`
]]
```

Inside `articleRowTpl`:

```html
<!-- CORRECT -->
<article>
    <h2><a href="[[~[[+id]]]]">[[+pagetitle]]</a></h2>
    <p>[[+introtext]]</p>
</article>

<!-- WRONG: renders current page, not the article in the row -->
<article>
    <h2>[[*pagetitle]]</h2>
</article>
```

---

## System settings

Reference any MODX system setting with `[[++key]]`:

```
<base href="[[++site_url]]">
<meta name="description" content="[[++site_name]] is a great site">
```

Common system settings:

| Key | Description |
|---|---|
| `site_name` | Site display name |
| `site_url` | Full site URL |
| `site_start` | Resource id of the home page |
| `unauthorized_page` | Resource id of the 401 page |
| `error_page` | Resource id of the 404 page |
| `default_template` | Default template id for new resources |

Custom settings created via ClientConfig or the Manager are also accessible via `[[++custom_key]]`.

---

## Links

`[[~id]]` generates the URL for a resource:

```html
<a href="[[~1]]">Home</a>
<a href="[[~[[*id]]]]">Permalink to this page</a>
```

### Link schemes

Pass `&scheme` to control absolute vs relative:

```
[[~123? &scheme=`full`]]      -> https://example.com/article.html
[[~123? &scheme=`http`]]      -> http://example.com/article.html
[[~123? &scheme=`https`]]     -> https://example.com/article.html
[[~123? &scheme=`abs`]]       -> /article.html
[[~123? &scheme=`relative`]]  -> article.html (default for same-context links)
```

Use `scheme=full` when the link will appear in email, RSS feeds, or social media cards.

---

## Output filters (modifiers)

Any tag can be chained with output filters using `:filter=\`value\``:

```
[[*pagetitle:uppercase]]
[[*pub_date:date=`%Y-%m-%d`]]
[[*introtext:ellipsis=`100`]]
[[*published:is=`1`:then=`Published`:else=`Draft`]]
[[+price:number_format=`2`]]
```

### Common filters

| Filter | What it does |
|---|---|
| `uppercase`, `lowercase`, `ucfirst`, `ucwords` | Case transformations |
| `length`, `strlen` | String length |
| `ellipsis=\`N\`` | Truncate to N chars with ellipsis |
| `date=\`%Y-%m-%d\`` | Format a timestamp |
| `if`, `is`, `eq`, `notempty`, `empty` | Conditionals (chain with `then` and `else`) |
| `math=\`?+1\`` | Arithmetic (`?` is the value) |
| `number_format=\`2\`` | Format a number with N decimal places |
| `strip_tags` | Remove HTML tags |
| `escapehtml`, `htmlent` | Escape HTML entities |
| `url`, `urlencode` | URL-encode |

### Conditional chains

```
[[*template:is=`3`:then=`Article`:else=`Page`]]
[[*published:is=`1`:and:ne=`0`:then=`Live`:else=`Draft`]]
```

---

## Comments

`[[- comment -]]` is stripped from output during parsing:

```
[[- this will not appear in HTML -]]
<p>This will.</p>
```

**HTML comments (`<!-- -->`) are NOT stripped** and can leak sensitive information, so use MODX comments for anything you do not want in the rendered page source.

---

## Lexicon entries

`[[%key]]` pulls from a lexicon (language file):

```
<button>[[%submit_button]]</button>
```

The active lexicon is determined by the resource's context and the user's language setting. Useful for multi-language sites.

---

## Escaping

If you need a literal `[[` in your content (e.g. in documentation about MODX itself), escape it with HTML entities or split it across tokens:

```
&#91;&#91;literal&#93;&#93;
```

---

## Quick reference card

```
[[snippetName? &param=`value`]]     snippet (cached)
[[!snippetName]]                    snippet (uncached)
[[$chunkName]]                      chunk
[[$chunkName? &prop=`val`]]         chunk with properties
[[*pagetitle]]                      current resource field
[[*articleimage]]                   current resource TV
[[+placeholderName]]                placeholder (set by snippet)
[[++site_name]]                     system setting
[[~123]]                            URL for resource id 123
[[~[[*id]]]]                        URL for current resource
[[%lexicon_key]]                    lexicon entry
[[- comment -]]                     removed from output
[[*pagetitle:ellipsis=`50`]]        with output filter
```
