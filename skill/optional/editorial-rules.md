# Optional editorial rules (examples)

> **These rules are EXAMPLES that some content teams adopt for MODX blog and article work. The skill does not enforce any of them by default. Adopt, adapt, or discard any rule that does not fit your project.**

To opt in, reference this file from your project's `CLAUDE.md` or copy the rules you want into a project-local doc that Claude reads on every session.

---

## Typography

### Long-dash avoidance

Some editorial teams ban the em-dash (`—` or `&mdash;`) in blog copy because:

- Proofreaders cannot reliably tell it apart from a hyphen or en-dash
- Copy-paste between tools sometimes converts it unpredictably
- A comma, colon, parenthetical, or full sentence stop is almost always available as a cleaner substitute

If you adopt this rule:

- Before pushing an article, grep the draft for `—`, `&mdash;`, `&#8212;`, and `&#x2014;`
- Rewrite each occurrence with a comma, period, colon, or parenthetical
- Regular hyphens in compound words (e.g. `open-source`, `state-of-the-art`) are fine; only the sentence-punctuation long dash is banned

### Smart quotes

Some teams prefer straight ASCII quotes (`"` `'`) over curly quotes (`"` `"` `'` `'`) because:

- ASCII quotes are easier to grep, replace, and diff
- Smart quotes can break when content is copy-pasted between editors or fed into code blocks

If you adopt this rule, configure your editor to disable smart-quote auto-conversion, and scan drafts for `&rsquo;`, `&lsquo;`, `&rdquo;`, `&ldquo;` before publishing.

---

## Links

### External link attributes

For SEO and referrer-privacy reasons, some teams add `rel="nofollow noreferrer"` to every link that points to a third-party domain, while leaving internal (same-domain) links untagged.

If you adopt this rule:

- Every `<a href="http...">` pointing outside your own domain gets `rel="nofollow noreferrer"`
- Internal links starting with `/` or without a scheme are left alone
- If the link also uses `target="_blank"`, include `noopener`: `rel="nofollow noopener noreferrer"`

Before pushing, grep the draft for `<a href="http` and verify each external anchor has the attribute.

---

## Article structure

### Opening paragraph (no H1)

Most MODX blog templates render `pagetitle` as the H1 automatically. If that is true on your site, do not include an `<h1>` in the `content` body. Start with a `<p>` containing the opening hook.

### Section hierarchy

- `<h2>` for major sections
- `<h3>` for subsections inside an H2
- Avoid going deeper than H3 for readability
- Do not skip levels (no H2 followed directly by H4)

### Length

A typical MODX blog article is 500 to 1500 words. Shorter pieces can feel thin for SEO; longer pieces lose reader attention unless broken into clearly scannable sections.

### Code blocks

Wrap code in `<pre><code>...</code></pre>`. Most MODX blog templates have CSS for this pattern already. Avoid inline styling in the content body; let the template handle presentation.

### Calls to action

End every article with a short paragraph that links to a relevant internal page (another article, a service page, a category listing). This keeps readers on site and helps internal linking for SEO.

---

## SEO fields on MODX resources

### Standard fields

- `pagetitle`: short indexable title (under 60 characters)
- `longtitle`: the extended "hook" headline, often shown as the article's display title
- `description`: meta description, target 150 to 160 characters, include the primary keyword
- `introtext`: short excerpt shown on listing pages, target 140 to 200 characters
- `alias`: URL slug, lowercase with dashes

### Typical TV fields for blog articles

Common template variable names for blog articles on MODX sites:

- `articleimage` (image): featured image for the article
- `tags` (autotag): brand or topic tags
- `spectag` (autotag): specialty or category tag (often a single primary topic)
- `showVideo` (checkbox): toggles a video block
- `videos` (migx): repeatable video entries
- `addCounter` (checkbox): toggles a read counter or similar widget
- `modelColor` (listbox): accent color for the article card

Every site has different TV names; check with `tv_list` and the existing article schema before assuming names.

---

## What to avoid in copy

- Filler marketing words like "innovative", "cutting-edge", "leverage", "synergy", "seamless", "revolutionary"
- Lorem ipsum left in any field, ever
- AI-generated boilerplate that does not match your site's voice
- Contractions if your site uses a formal tone; spelled-out forms if it uses a casual tone (pick one and stay consistent)
- Orphaned articles with no internal links either in or out

---

## How to apply these rules

Copy any rules you want into a project-local file (for example, `CLAUDE.md` at the root of your MODX project) and reference this file from there. Claude will read your project file on every session and apply the rules consistently.

Rules from this file are NOT automatically loaded. This is deliberate: every MODX site has different conventions, and forcing one set on everyone would cause silent drift from the user's actual preferences.
