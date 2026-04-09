# MODX extras reference

MODX Revolution ships with a minimal core, and most real-world sites depend on a handful of extras for common functionality. This file covers the extras Claude will most often encounter on a working MODX site, with syntax examples and the gotchas that trip up developers.

The bridge does not depend on any of these extras (other than the optional ModxTransfer for imports), but understanding them helps Claude write templates, chunks, and articles that actually work on a given site.

---

## pdoTools

**What it is.** A high-performance replacement for the core listing snippets (`getResources`, `getPage`, `Wayfinder`). If a MODX site does any kind of article listing, gallery, or tag filter, it almost certainly uses pdoTools.

**The main snippets:**

| Snippet | Purpose |
|---|---|
| `pdoResources` | List child resources with filtering, sorting, and pagination |
| `pdoMenu` | Render a navigation menu from the resource tree |
| `pdoCrumbs` | Breadcrumb trail for the current resource |
| `pdoField` | Fetch a single field from another resource by id |
| `pdoPage` | Pagination wrapper for listings |
| `pdoNeighbors` | "Previous" and "next" links relative to the current resource |
| `pdoSitemap` | XML sitemap generator |
| `pdoTitle` | Dynamic page title generation |
| `pdoArchive` | Archive listings grouped by year/month |

### pdoResources example

List the 10 most recent published children of resource id 2:

```
[[!pdoResources?
    &parents=`2`
    &limit=`10`
    &sortby=`publishedon`
    &sortdir=`DESC`
    &includeTVs=`articleimage,tags`
    &tpl=`tpl.article.row`
]]
```

Common parameters:

- `parents`: comma-separated parent ids; `0` means the entire site
- `depth`: how deep to recurse (default `10`)
- `limit`: max results (default `10`, `0` = unlimited)
- `offset`: skip the first N results (use with pagination)
- `sortby`: field to sort by (`publishedon`, `menuindex`, `createdon`, etc.)
- `sortdir`: `ASC` or `DESC`
- `tpl`: chunk name to use as the row template
- `includeTVs`: comma-separated TV names to fetch alongside
- `processTVs`: comma-separated TV names to render as their configured output (image TVs become `<img>` tags, etc.)
- `where`: JSON-encoded extra WHERE clause for filtering
- `showHidden`: include resources with `hidemenu=1`
- `showUnpublished`: include unpublished resources

### pdoMenu example

Render the main navigation from the top level:

```
[[pdoMenu?
    &parents=`0`
    &level=`2`
    &tplOuter=`tpl.menu.outer`
    &tpl=`tpl.menu.row`
]]
```

### Important gotchas

- **`[[+id]]` vs `[[*id]]` inside row templates.** Use `[[+id]]`, `[[+pagetitle]]`, `[[+introtext]]` inside `tpl` chunks. The `*` prefix refers to the current page, not the row.
- **Cached by default.** Use `[[!pdoResources...]]` (uncached) when the listing depends on per-request state like search queries or login status.
- **`includeTVs` vs `processTVs`.** `includeTVs` makes the raw value available. `processTVs` makes the rendered HTML available (images become `<img>` tags). Most template code wants `includeTVs`; use `processTVs` only when you want pdoTools to handle the rendering.

---

## MIGX (Multi Items Gallery Extra)

**What it is.** A TV type that stores structured repeatable data as JSON. Use it when you need "a list of related items" (gallery images with captions, FAQ entries, team members, video embeds) attached to a single resource.

**Storage format.** MIGX TVs store a JSON array:

```json
[
  {"MIGX_id": "1", "title": "First item", "image": "path/to/1.jpg"},
  {"MIGX_id": "2", "title": "Second item", "image": "path/to/2.jpg"}
]
```

Each item has an auto-generated `MIGX_id` plus any fields defined in the MIGX configuration.

### Rendering MIGX in a template

Use the `migxLoopCollection` snippet to iterate over a MIGX TV:

```
[[!migxLoopCollection?
    &tvname=`galleryItems`
    &tpl=`tpl.gallery.item`
]]
```

Inside `tpl.gallery.item`:

```html
<figure>
    <img src="[[+image]]" alt="[[+title]]">
    <figcaption>[[+title]]</figcaption>
</figure>
```

### Writing MIGX data via the bridge

The bridge accepts MIGX values as PHP arrays or JSON strings; if you pass an array to `tv_setvalue`, it is JSON-encoded automatically:

```json
{
  "action": "tv_setvalue",
  "tv": "galleryItems",
  "id": 42,
  "value": [
    {"MIGX_id": "1", "title": "Hero shot", "image": "assets/gallery/hero.jpg"},
    {"MIGX_id": "2", "title": "Detail view", "image": "assets/gallery/detail.jpg"}
  ]
}
```

### Gotchas

- MIGX configurations are stored in a system setting or MIGX extra settings, not in the TV itself. If you create a MIGX TV via the bridge, you also need to configure its form schema in the Manager.
- `MIGX_id` is required for every item even if you do not use it elsewhere. If you omit it, MIGX may fail to render the item.
- The order of items in the array is the display order.

---

## FormIt

**What it is.** A form-handling snippet for contact forms, registration, feedback, and any user input. Handles validation, CSRF protection, email sending, and redirect-after-submit.

### Basic usage

```
[[!FormIt?
    &hooks=`spam,email,redirect`
    &emailTpl=`tpl.email.contact`
    &emailTo=`hello@example.com`
    &emailSubject=`New contact form submission`
    &redirectTo=`5`
    &validate=`name:required,email:email:required,message:required`
]]
<form action="[[~[[*id]]]]" method="post">
    <input type="text" name="name" value="[[!+fi.name]]">
    <span class="error">[[!+fi.error.name]]</span>

    <input type="email" name="email" value="[[!+fi.email]]">
    <span class="error">[[!+fi.error.email]]</span>

    <textarea name="message">[[!+fi.message]]</textarea>
    <span class="error">[[!+fi.error.message]]</span>

    <button type="submit">Send</button>
</form>
```

### Key parameters

| Parameter | Purpose |
|---|---|
| `hooks` | Pipeline of processors (`spam`, `recaptcha`, `email`, `redirect`, custom) |
| `preHooks` | Processors that run before the hook pipeline (e.g. to pre-populate fields) |
| `validate` | Validation rules per field |
| `emailTpl` | Chunk name for the email body |
| `emailTo` | Recipient address |
| `emailSubject` | Email subject line |
| `emailFrom` | Sender address |
| `redirectTo` | Resource id to redirect to after successful submission |
| `submitVar` | Name of the submit button (defaults to `spam`) |

### Placeholders inside FormIt templates

- `[[!+fi.fieldName]]` — the submitted value (for repopulating after validation errors)
- `[[!+fi.error.fieldName]]` — the validation error message for a field
- `[[!+fi.success]]` — `1` if the form submitted successfully (use this to conditionally show a success message)

### Important gotchas

- **Always use uncached (`!`) tags with FormIt.** Cached calls will cache the form state across requests and break validation.
- **The success redirect must be a real resource.** Use `redirectTo` with a resource id, not a hardcoded URL.
- **reCaptcha integration is via a separate hook.** Add `recaptcha` to the hooks parameter and install the reCaptcha extra.

---

## Collections

**What it is.** An extra that turns a resource into a "collection container" with a grid-view child listing in the Manager, similar to a database admin UI. Perfect for blog post lists, event lists, portfolio items, anywhere you want a tabular view of child resources.

### How it changes things

1. The parent resource gets `class_key = Collections\Model\CollectionContainer`
2. Children are plain `modDocument` resources but appear in the grid view
3. Children typically have `show_in_tree = 0` so they do not clutter the resource tree
4. Listing snippets (usually pdoResources) filter children by `show_in_tree = 0` to match the grid

### The big gotcha

When creating a new child resource under a Collections container via the bridge, you MUST set `show_in_tree: 0` in the `fields` object. Otherwise the new resource will exist in the database but will not appear in the collection grid or in any front-end listing that filters on `show_in_tree`.

```json
{
  "action": "resource_create",
  "fields": {
    "pagetitle": "New article",
    "parent": 2,
    "template": 3,
    "published": 1,
    "show_in_tree": 0,
    "menuindex": 20
  }
}
```

Detect Collections containers by inspecting the parent's `class_key` before creating children:

```json
{"action": "resource_get", "id": 2}
```

If `class_key` is `"Collections\\Model\\CollectionContainer"`, apply the rule.

### Other notes

- Collections does not change the underlying data model. A "Collection child" is just a modDocument with `show_in_tree = 0` and a specific parent.
- The grid view is configured per container via a system setting or the Collections extra settings panel.
- Removing the Collections extra from a site leaves orphaned containers as plain modDocuments; the children remain accessible but lose the grid view.

---

## Tagger

**What it is.** A tagging system that lets you attach multiple tags (from predefined groups) to resources. Replaces the need for custom autotag TVs when you have more than a few categories.

### Typical usage

- Create tag groups in the Manager (`Topic`, `Category`, `Location`)
- Attach tags to resources via the Tagger UI
- List resources by tag using `TaggerGetTags` and `TaggerGetResources` snippets

### Snippets

- `TaggerGetTags` — list all tags in a group, often used to render a tag cloud
- `TaggerGetResources` — list resources filtered by tag (thin wrapper around pdoResources)

### Why use Tagger vs custom TVs

- Tags are shared across resources (one canonical list, no typos)
- Tag count and usage stats are tracked
- UI for adding and managing tags is consistent
- Resources can have unlimited tags per group

Use a custom autotag TV only for one-off tags that do not need a shared vocabulary.

---

## SeoSuite

**What it is.** A suite of SEO-related snippets and TVs, the most common being:

- `SeoSuiteMeta` — outputs `<meta name="description">` and related tags from a resource's SEO TVs
- `SeoSuiteSitemap` — XML sitemap generator
- `SeoSuiteKeywords` — keyword analysis

### Typical usage in a template

```html
<head>
    <title>[[*seoTitle:default=`[[*pagetitle]]`]] | [[++site_name]]</title>
    [[!SeoSuiteMeta]]
    <link rel="canonical" href="[[*canonicalUrl:default=`[[~[[*id]]? &scheme=`full`]]`]]">
</head>
```

### Gotchas

- SeoSuite adds its own TVs (`seo_title`, `seo_description`, `seo_keywords`, etc.) to the Manager. These live under the resource's SEO panel, not the main TVs panel.
- The XML sitemap generated by `SeoSuiteSitemap` respects the `searchable` field on resources. Set `searchable = 0` to exclude a resource from the sitemap.
- Do not create your own TV called `seoDescription` if SeoSuite is installed; use SeoSuite's built-in fields to avoid duplicates.

---

## Image+

**What it is.** A replacement for the core `image` TV type that adds crop, resize, focal point, and multiple preset variants. Most modern MODX sites use Image+ instead of the plain image TV.

### Why use it

- One TV stores one image but can render multiple sizes (thumbnail, medium, large, hero)
- Focal point selection so crops stay on the subject
- Automatic cache of generated variants

### Template usage

```
[[+articleimage:phpthumbon=`w=800&h=450&zc=1`]]
```

The `phpthumbon` output filter is provided by Image+ and accepts pThumb-style parameters.

### Gotcha

Image+ stores its data in a slightly different format than the plain image TV. If you migrate from plain image to Image+, existing values need to be converted via a small script. The bridge cannot auto-convert; it just sets the value you pass.

---

## GoodNews

**What it is.** A full newsletter system for MODX. Subscribe forms, user lists, HTML email templates, delivery, bounce handling, and unsubscribe links.

Only relevant if the site sends newsletters. Adds several system tables, a Manager CMP, and a handful of snippets (`GoodNewsSubscription`, `GoodNewsProfile`, `GoodNewsUnsubscription`, etc.).

Most common interaction from a Claude Code skill: editing the HTML chunks used as email templates.

---

## Login

**What it is.** User registration, login, logout, password reset, profile editing. Pair with the `Register`, `Login`, `Logout`, `ChangePassword`, `ForgotPassword`, `ResetPassword`, `UpdateProfile`, and `Profile` snippets.

Relevant on any MODX site with user accounts. Common in combination with FormIt (for richer forms) and reCaptcha (for anti-abuse).

---

## reCaptcha

**What it is.** Integration with Google reCaptcha v2 and v3. Pair with FormIt via the `recaptcha` hook.

### Typical usage

Install reCaptcha, set the site key and secret key in the system settings, and add `recaptcha` to the FormIt hooks pipeline.

---

## HybridAuth

**What it is.** Social login via HybridAuth (Google, Facebook, Twitter/X, GitHub, LinkedIn, etc.). Use alongside Login and Register for social signup flows.

Relevant only on sites with social login. Adds third-party credential storage and UI.

---

## TableOfContentsX

**What it is.** Automatically generates a table of contents from headings in a resource's content. Useful for long articles and documentation.

```
[[!TableOfContentsX]]
```

Placed at the top of an article, it builds a nested `<ul>` of all H2, H3, H4 headings in the current resource's content.

---

## readingtime

**What it is.** An output filter that calculates reading time from text content.

```
[[+content:readingtime]]
```

Returns something like `"4 min read"`. Useful for article listings.

---

## modxMinify

**What it is.** Asset minification and bundling. Concatenates multiple CSS or JS files into a single minified file for better load performance.

Usually configured once and forgotten. Relevant if a Claude skill is adding new CSS or JS and needs to know how they get bundled.

---

## AutoSchema

**What it is.** Auto-generates schema.org structured data (JSON-LD) from resource fields and TVs. Removes the need to maintain hand-written JSON-LD in templates.

Relevant for SEO work. Extends the SEO stack alongside SeoSuite.

---

## Which extras to expect where

General patterns:

| Site type | Likely extras |
|---|---|
| Blog or news site | pdoTools, MIGX, SeoSuite, Tagger, Collections, Login, AutoSchema, TableOfContentsX |
| Marketing site | pdoTools, MIGX, FormIt, reCaptcha, SeoSuite, Image+ |
| Community site | pdoTools, Login, Register, HybridAuth, FormIt, GoodNews |
| E-commerce | pdoTools, Commerce or MODShop, plus SeoSuite, Image+, FormIt |
| Portfolio or agency | pdoTools, Collections, MIGX, Image+, FormIt, SeoSuite |

Before writing templates or chunks for a new MODX site, always list the installed extras (the Manager's Extras panel, or query the `modx_transport_packages` table) to know which tooling is available.
