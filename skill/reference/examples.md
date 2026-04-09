# Examples

Copy-paste JSON payloads for common MODX CLI bridge tasks. Every example is a complete request body you can pipe into `invoke.sh`. Use `jq -n --rawfile` to inject long HTML bodies cleanly; see the last section.

All IDs and names in these examples are placeholders. Replace them with real values from your site.

---

## System

### Smoke test after deployment

```json
{"action": "ping"}
```

### Clear the cache after any element mutation

```json
{"action": "cache_clear"}
```

---

## Resources

### List all direct children of the home page

```json
{"action": "resource_list", "parent": 1}
```

### List only published children

```json
{"action": "resource_list", "parent": 1, "published": true}
```

### Get a resource by id, with full content body

```json
{"action": "resource_get", "id": 5, "include_content": true}
```

### Get a resource by alias (context-scoped)

```json
{"action": "resource_get", "alias": "about", "context": "web"}
```

### Create a simple static page

```json
{
  "action": "resource_create",
  "fields": {
    "pagetitle": "Contact",
    "longtitle": "Contact Us",
    "description": "Get in touch with our team.",
    "content": "<h2>Contact</h2><p>Email us at hello@example.com</p>",
    "parent": 1,
    "template": 1,
    "published": 1,
    "menuindex": 5
  }
}
```

### Create an article under a blog parent, with TVs

```json
{
  "action": "resource_create",
  "fields": {
    "pagetitle": "New Article Title",
    "longtitle": "A Longer Headline for the Article",
    "description": "SEO meta description kept under 160 characters.",
    "introtext": "Short excerpt shown on listing pages.",
    "content": "<p>Article body HTML.</p>",
    "parent": 2,
    "template": 3,
    "hidemenu": 1,
    "published": 1,
    "menuindex": 20
  },
  "tvs": {
    "articleimage": "assets/images/articles/new-article.jpg",
    "tags": "news,update",
    "addCounter": "Yes"
  }
}
```

### Create a scheduled article (publishes automatically at a future date)

```json
{
  "action": "resource_create",
  "fields": {
    "pagetitle": "Scheduled Article",
    "content": "<p>This goes live on the specified date.</p>",
    "parent": 2,
    "template": 3,
    "published": 0,
    "pub_date": 1776038400
  }
}
```

`pub_date` is a Unix timestamp. The MODX publishing cron (or a visitor hitting the resource after the date) flips `published` to 1 automatically.

### Update only the content field of an existing resource

```json
{
  "action": "resource_update",
  "id": 123,
  "fields": {
    "content": "<p>Updated body text.</p>"
  }
}
```

### Soft-delete a resource (recoverable from the recycle bin)

```json
{"action": "resource_delete", "id": 123}
```

### Permanently delete a resource (dangerous)

```json
{"action": "resource_delete", "id": 123, "hard": true}
```

---

## Chunks

### Create or update a chunk

```json
{
  "action": "chunk_update",
  "name": "headerMenu",
  "content": "<nav><ul><li><a href='/'>Home</a></li></ul></nav>",
  "description": "Main site navigation",
  "category": "Navigation"
}
```

### Fetch a chunk's content

```json
{"action": "chunk_get", "name": "headerMenu"}
```

### Delete a chunk

```json
{"action": "chunk_delete", "name": "obsoleteChunk"}
```

---

## Templates

### Create or update a template

```json
{
  "action": "template_update",
  "name": "BasePage",
  "content": "<!DOCTYPE html><html><head><title>[[*pagetitle]]</title></head><body>[[*content]]</body></html>",
  "description": "Minimal base page template",
  "category": "Layouts"
}
```

### Fetch a template's content

```json
{"action": "template_get", "name": "BasePage"}
```

---

## Template variables

### Create a new image TV

```json
{
  "action": "tv_update",
  "name": "articleimage",
  "caption": "Article image",
  "description": "Featured image for blog articles",
  "type": "image",
  "category": "Content"
}
```

### Create a listbox TV with fixed options

```json
{
  "action": "tv_update",
  "name": "accentColor",
  "caption": "Accent color",
  "type": "listbox",
  "elements": "blue||red||green||orange||purple",
  "default": "blue"
}
```

### Assign a TV to a template

```json
{
  "action": "tv_assign_template",
  "tv": "articleimage",
  "template": "BlogArticle"
}
```

### Set a TV value on a specific resource

```json
{
  "action": "tv_setvalue",
  "tv": "articleimage",
  "id": 123,
  "value": "assets/images/articles/hero.jpg"
}
```

### Set a MIGX TV (repeatable structured data)

```json
{
  "action": "tv_setvalue",
  "tv": "videos",
  "id": 123,
  "value": [
    {"MIGX_id": "1", "title": "Intro", "video": "dQw4w9WgXcQ", "youtube": "1"},
    {"MIGX_id": "2", "title": "Demo", "video": "abc123def45", "youtube": "1"}
  ]
}
```

Arrays are auto-JSON-encoded by the bridge.

---

## Snippets

### Create or update a snippet (PHP source)

```json
{
  "action": "snippet_update",
  "name": "helloSnippet",
  "content": "<?php\nreturn 'Hello from a snippet';",
  "description": "Minimal example snippet"
}
```

---

## Categories

### List all categories

```json
{"action": "category_list"}
```

### Create a new category

```json
{"action": "category_create", "name": "Articles"}
```

### Create a nested category

```json
{"action": "category_create", "name": "Featured", "parent": "Articles"}
```

---

## Imports (ModxTransfer required)

### Import elements from a JSON export file

```json
{"action": "import_elements", "file": "assets/imports/elements.json"}
```

### Import resources into a specific parent

```json
{
  "action": "import_resources",
  "file": "assets/imports/resources.json",
  "parentId": 2
}
```

---

## Long content via `jq`

For resources with multi-kilobyte HTML bodies, construct the JSON with `jq -n --rawfile`. This avoids quoting headaches with embedded newlines, backticks, and quotes.

```sh
jq -n --rawfile content /path/to/article-body.html '{
  action: "resource_create",
  fields: {
    pagetitle: "New Article",
    content: $content,
    parent: 2,
    template: 3,
    published: 1,
    menuindex: 20
  },
  tvs: {
    articleimage: "assets/images/articles/new-article.jpg",
    tags: "news"
  }
}' | ~/.claude/skills/modx/scripts/invoke.sh
```

For bulk edits across multiple resources, wrap individual `invoke.sh` calls in a shell loop and check each response before continuing.

---

## Verification pattern

After every mutation, verify the result before moving on:

```sh
# 1. Create
echo '{"action":"resource_create","fields":{"pagetitle":"Test","parent":1,"template":1,"published":1}}' \
  | ~/.claude/skills/modx/scripts/invoke.sh

# 2. Read back (use the id from the create response)
echo '{"action":"resource_get","id":999,"include_content":true}' \
  | ~/.claude/skills/modx/scripts/invoke.sh

# 3. Clear cache
echo '{"action":"cache_clear"}' \
  | ~/.claude/skills/modx/scripts/invoke.sh

# 4. Fetch rendered page
curl -I https://example.com/test.html
```
