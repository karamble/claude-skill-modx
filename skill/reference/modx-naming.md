# MODX naming conventions

MODX does not enforce naming conventions, but consistent naming makes large sites much easier to maintain. This file describes the patterns most working MODX developers use. They are not mandatory, but they make templates, chunks, snippets, and TVs self-documenting.

Adopt what fits your team and be consistent.

---

## Templates

Templates are the outermost wrapper for a resource. Name them by what they render, not by technology or implementation detail.

### Common patterns

| Pattern | Example | When to use |
|---|---|---|
| `PascalCase` | `BasePage`, `BlogArticle`, `LandingPage` | General templates |
| `dotted.lowercase` | `tpl.srv.Detail`, `tpl.blog.Index` | When you prefer explicit grouping |
| `role.prefix` | `layout.default`, `layout.minimal` | When templates serve different layouts |

### What to avoid

- Version numbers in template names (`BlogArticle_v2`) — use git for versioning, not naming
- Abbreviations that are not obvious (`BA` instead of `BlogArticle`)
- Mixing styles in the same site (`BlogArticle` and `tpl.blog.row` in the same codebase)

---

## Chunks

Chunks are reusable HTML fragments. Name them by function.

### Common patterns

| Pattern | Example | When to use |
|---|---|---|
| `camelCase` | `siteHeader`, `articleCard`, `socialLinks` | Most common; short and clear |
| `dotted.namespaced` | `tpl.article.card`, `tpl.article.row`, `cmp.hero` | Use when you have many chunks and need grouping |
| `role.prefix` | `wrapper.main`, `partial.footer` | Emphasizes the chunk's role |

### Conventional prefixes

| Prefix | Means |
|---|---|
| `tpl.` | Chunks used as `&tpl` parameters in snippets (pdoResources rows, FormIt templates) |
| `cmp.` | Component (reusable UI block like a card, hero, banner) |
| `partial.` | Layout partial (header, footer, sidebar) |
| `email.` | Email templates used by FormIt or GoodNews |
| `msg.` | User-facing messages (success, error, validation) |

### Example

```
tpl.article.row           -- row template for pdoResources
tpl.article.card          -- card template for featured articles
cmp.hero                  -- hero banner component
cmp.callout               -- callout box component
partial.header            -- site header partial
partial.footer            -- site footer partial
email.contact.admin       -- admin notification email from contact form
msg.contact.success       -- contact form success message
```

---

## Snippets

Snippets are PHP functions that run during parsing.

### Common patterns

| Pattern | Example |
|---|---|
| `camelCase` | `getArticleList`, `formatDate`, `renderSidebar` |
| Verb-first | `getX`, `renderX`, `countX`, `buildX` |

Third-party snippets (pdoTools, FormIt, getResources, Login, SeoSuite) use their own naming and should be referenced as they ship.

### Core rule

A snippet name should describe what it returns or does, not its implementation. `getArticleList` is better than `articleListFromDb`.

---

## Template variables (TVs)

TVs store per-resource custom data. Name them by what they store.

### Common patterns

| Pattern | Example |
|---|---|
| `lowercase` | `articleimage`, `tags`, `showvideo` |
| `camelCase` | `articleImage`, `showVideo`, `spectag` |
| `dotted` | `article.image`, `article.tags` |

### Important constraint

**TV names must not collide with resource field names.** Do not create a TV called `pagetitle`, `longtitle`, `content`, `alias`, `parent`, `template`, `published`, `publishedon`, `description`, `introtext`, `menutitle`, `hidemenu`, `menuindex`, `searchable`, `cacheable`, `deleted`, `editedby`, `editedon`, `createdby`, `createdon`, `publishedby`, `class_key`, `context_key`, `content_type`, `content_dispo`, `hide_children_in_tree`, `show_in_tree`, `properties`, or any other built-in field. The bridge will let you create such a TV, but the `[[*tvName]]` lookup will return the resource field, not the TV, and debugging the confusion is painful.

If you need "extra description" data, call the TV `shortDescription` or `seoDescription`, not `description`.

### Common TV names for blog sites

| TV name | Type | Purpose |
|---|---|---|
| `articleimage` | image | Featured image for the article |
| `tags` | autotag | Topic or keyword tags |
| `spectag` | autotag | Primary category tag (single value) |
| `showVideo` | checkbox | Toggle a video block |
| `videos` | migx | Repeatable video entries |
| `author` | text | Author name override |
| `seoTitle` | text | SEO-specific title override |
| `seoDescription` | textarea | SEO meta description override |
| `schemaType` | listbox | schema.org type (Article, NewsArticle, BlogPosting, etc.) |
| `featured` | checkbox | Mark an article as featured |
| `sortWeight` | number | Manual sort order override |

### TV category

Assign every TV to a category in the Manager to keep the TV list scannable. Common categories:

- Content (articleimage, tags, spectag, featured)
- SEO (seoTitle, seoDescription, schemaType, canonicalUrl)
- Layout (modelColor, accentColor, hideHeader)
- Features (showVideo, videos, addCounter, showShareButtons)

---

## Categories

MODX categories group elements (chunks, templates, TVs, snippets) in the Manager tree.

### Common categories

| Category | Contains |
|---|---|
| Content | TVs and chunks related to article and page content |
| Layout | Templates, layout chunks (header, footer, sidebar) |
| SEO | SEO TVs, schema chunks, sitemap snippets |
| Navigation | Menu chunks and snippets |
| Forms | FormIt forms, email templates, validation chunks |
| Newsletter | Newsletter templates and chunks |
| SEO (or SEO & Meta) | SEO-related TVs and chunks |
| Media | Image and video handling chunks and TVs |

---

## Resource aliases

The `alias` field is the URL slug. Conventions:

- Lowercase only
- Dashes for spaces (`my-article-title` not `my_article_title` or `MyArticleTitle`)
- No accents or special characters (use the MODX transliteration setting)
- Short but descriptive
- No file extension (MODX adds `.html` automatically via the container suffix setting)
- Unique within the parent (MODX enforces per-parent, not per-site)

### Common mistakes

- Duplicate aliases across different parents (usually fine, but can confuse URL resolvers)
- Aliases containing query strings (`article?id=1`) — these break MODX's URL handling
- Aliases longer than 60 characters — bad for SEO and ugly in URLs

---

## The one rule that applies everywhere

**Pick a convention and stay consistent.** MODX gives you enormous freedom. Inconsistency is the biggest source of technical debt on long-running MODX sites, not any particular naming style.

Write the convention down in a project-level `CLAUDE.md` or `CONTRIBUTING.md` so that Claude and future maintainers follow the same rules. The bridge will happily let you break any convention; the consequences show up months later when someone else has to find where a specific chunk lives.
