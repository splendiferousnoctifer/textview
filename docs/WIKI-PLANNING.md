# Wiki-style evolution: planning & research

**Goal:** Evolve the app so you can have multiple named “pages” and link between them (wiki-style), while staying **static, client-only, lightweight, and free to host**.

**Scope of this doc:** Planning and research only. No implementation.

---

## FAQ: Where is data? How do changes persist? Fixed links?

**Where are all the pages saved? Just in the hash?**

No. In the **proposed** wiki design:

- The **hash only holds the current page’s name** (e.g. `#Ideas`, `#Home`). It does **not** hold the content of every page.
- The **content** of each page is saved in **localStorage** (one key per page, e.g. `wiki:Ideas`, `wiki:Home`).
- So: **hash = which page you’re on**; **localStorage = the text of all pages**. That way the URL stays short and stable, and you can have many/long pages without hitting hash size limits.

**I can’t push to GitHub Pages – so how do changes stay? Doesn’t everything disappear?**

GitHub Pages only hosts your **app** (the HTML/JS/CSS files). It does **not** store any user data. So:

- **Where changes live:** Only in the **browser**: either in the **URL hash** (current app: one doc per URL) or in **localStorage** (proposed wiki: one key per page). There is no server or database saving anything.
- **Persistence:** As long as you use the same browser and don’t clear site data, changes stay in that browser. If you clear storage or switch device, that data is gone unless you’ve exported/backed it up or used a shareable link that carries the content in the hash (current single-doc behavior).
- So “changes stay” = they stay in **localStorage** (and/or in the hash when you use a shareable single-doc URL). Not on GitHub.

**If the hash changes with every edit, how can I have fixed links between pages?**

In the **current** app, the hash *does* change on every edit (it contains the full compressed document), so the URL is **not** stable and you can’t really “link to this page” in a permanent way.

In the **proposed** wiki design we change that:

- The hash **does not** contain the document. It only contains the **page name** (e.g. `#Ideas`).
- When you **edit** the page, we **only update localStorage** for that page. The hash stays `#Ideas`. So the **link is fixed**: `https://yoursite.com/#Ideas` always means “the page named Ideas.”
- The hash **only** changes when you **navigate** to another page (e.g. click `[[Home]]` → hash becomes `#Home`). Content is saved to localStorage under the current page name; the URL stays stable so you can link back and forth between pages with fixed links like `#Home` and `#Ideas`.

---

## 1. Current behavior (baseline)

- **One document per URL.** The entire document (and optional inline style) is stored in the hash:  
  `#r` or `#e` + base64url(deflate(content + '\x00' + style)).
- **Persistence:** `localStorage` holds a single key `hash` (the last used document).
- **Links:** Normal Markdown links `[text](url)` and bare URLs are rendered as `<a href="..." target="_blank">` and **always open in a new tab**. There is no concept of “internal” pages or in-app navigation.
- **No notion of “pages”:** There is only one document at a time; the hash either carries that document or you fall back to the last one from localStorage.

So today you **cannot** “reference and link pages” in a wiki sense: there are no separate pages, and every link leaves the app.

---

## 2. What “wiki-style” means here

- **Multiple named pages** (e.g. “Home”, “Ideas”, “Project X”) that persist and can be opened by name.
- **Internal links** that navigate to another page **inside the same app** (same tab, no full reload), e.g. `[[Ideas]]` or `[[Page Name|display text]]`.
- **Addressability:** Each page has a stable identifier so you can link to it and (optionally) share it. That usually means a URL that uniquely identifies the page (e.g. hash or path).
- **Optional:** Back-links (“pages that link here”), page list, or “create page on first click” (like classic wikis). These are UX features on top of the core model.

---

## 3. Constraints (unchanged)

- **Static & client-only:** No backend, no server-side DB. Everything must work in the browser (HTML/CSS/JS only).
- **Free to host:** Deploy as static files (e.g. GitHub Pages, Cloudflare Pages, Netlify). Hash-based routing works everywhere; no special server config needed.
- **Lightweight:** Prefer minimal JS and no heavy frameworks. The current stack (vanilla JS, single HTML, deflate in the URL) fits this.

---

## 4. Where can “pages” live? (storage options)

All options below are client-side only and compatible with free static hosting.

### 4.1 All pages in the URL hash (single “blob” wiki)

- **Idea:** Encode a key–value map in the hash, e.g.  
  `{ "Home": "content...", "Ideas": "content..." }` → JSON → compress → base64url → `#w` + payload.
- **Pros:** One URL can represent the entire wiki; share one link, get all pages; no separate storage API.
- **Cons:**
  - **Hash length:** Browsers support long hashes (often 50k+ chars), but IE/old Edge fail around 2k–2.5k. For broad compatibility, staying under ~2k hash is safe. With deflate, a few short pages might fit, but multiple long pages will not.
  - **Grows fast:** Every edit rewrites the whole wiki in the hash; URLs get huge and fragile.
- **Verdict:** Only viable for **very small** wikis (handful of short pages). Not a good fit if you want many or long pages.

### 4.2 One “current page” in hash, rest in localStorage (recommended base)

- **Idea:**  
  - **Page identity in URL:** e.g. `#PageName` or `#/Ideas` (hash = page id).  
  - **Content:** Stored in `localStorage` keyed by page id (e.g. `wiki:Home`, `wiki:Ideas`).  
  - **Load:** On load or hashchange, read page id from hash → load content from localStorage for that page.  
  - **Save:** On edit, write current content to localStorage under current page id; optionally keep URL in sync (hash = page id).
- **Pros:**  
  - No hash size limit for content; many pages, each can be long.  
  - Same static hosting; no backend.  
  - Fits current architecture: you only change how “current document” is chosen (by page id + localStorage instead of “one hash = one doc”).
- **Cons:**  
  - **Not shareable by default:** Opening `https://yoursite.com/#Ideas` on another device has no content unless you add “export/import” or put payload in URL for that page (see hybrid below).  
  - **localStorage limits:** ~5–10 MB per origin; enough for a large personal wiki, but not for huge datasets.  
  - **Tied to browser/device** unless you add export (e.g. JSON or single-file backup).

### 4.3 Same as 4.2 but with IndexedDB

- **Idea:** Same URL model (`#PageName`), but store page contents in IndexedDB instead of localStorage.
- **Pros:** Much larger storage, better for many/long pages; still client-only and free to host.  
- **Cons:** Slightly more code; less “just key–value” than localStorage.  
- **Verdict:** Good upgrade path if you outgrow localStorage.

### 4.4 Hybrid: “Named pages” + optional shareable single-page URL

- **Idea:**  
  - **Normal mode:** Pages live in localStorage (or IndexedDB), URL = `#PageName` (or `#/page/PageName`).  
  - **Shareable mode:** “Share this page” (or “Open in new tab as standalone”) produces a **single-document URL** in the current format: `#r` + compressed payload for **this page only**. That URL is self-contained and works on any device (no localStorage needed).  
  - **Load logic:** If hash looks like a compressed payload (e.g. starts with `#r` or `#e` and then base64), load as today (one document from hash). If hash looks like a page id (e.g. `#Ideas` or `#/Ideas`), load that page from localStorage.
- **Pros:** You keep “share one link = full document” for a single page, and gain a multi-page wiki with internal links.  
- **Cons:** Two URL “modes” to document and maintain (hash format detection).

This keeps your current sharing story and adds the wiki model.

---

## 5. Linking: syntax and behavior

### 5.1 Wiki-style internal links

- **Syntax:** Common convention is `[[Page Name]]` or `[[Page Name|display text]]`.  
  - Must be **distinct from** normal Markdown `[text](url)` so internal links are not opened in a new tab.
- **Behavior:**  
  - Clicking an internal link should: set `location.hash` to the page id (e.g. `#Page Name` or a normalized form like `#page/Page%20Name`), then load that page from storage (no new tab, no full reload).  
  - If the page doesn’t exist, you can either create an empty page (wiki “create on first edit”) or show an “empty state” with a prompt to create.

### 5.2 Distinguishing internal vs external

- **Option A – `[[...]]` only for internal:**  
  - Parse `[[Page Name]]` and `[[Page Name|label]]` in your markdown layer.  
  - Render them as `<a href="#PageName" class="wiki-link">` (or similar), and **intercept click** so you don’t open in new tab: prevent default, set hash, load from storage.  
  - Keep `[text](url)` and bare URLs as external (current behavior: `target="_blank"`).
- **Option B – heuristic:**  
  - Links whose `href` is same-origin and hash-only (e.g. `#Something`) are internal; the rest external.  
  - Then you could use normal Markdown: `[Ideas](#Ideas)` for internal.  
  - Con: less “wiki-like” and easy to forget; `[[Ideas]]` is more discoverable and consistent.

**Recommendation:** Add **wiki links** `[[Page Name]]` / `[[Page Name|label]]` as a **new** markdown-like token (before or alongside `md-link`), render as internal links, and handle their clicks in the app (hash change + load from storage). Leave `[text](url)` and URLs as external.

### 5.3 Implementation touchpoints (for later)

- **Parsing:** In `parseMarkdown`, add a matcher for `[[...]]` and optionally `[[...|...]]`, and output `<a>` with a dedicated class (e.g. `wiki-link`) and `href="#..."` (normalized page id).
- **Serialization:** In `serializeToMarkdown` (or equivalent), when you see that internal link element, emit `[[Page Name]]` or `[[Page Name|label]]` again so round-trip is correct.
- **Click handling:** In the existing `article.addEventListener('click', ...)`, if the target is a wiki-internal link, `event.preventDefault()`, set `location.hash`, and rely on existing `hashchange` + load logic (once load is wired to “page id from hash → load from storage”).

---

## 6. URL design for pages

- **Option A – Hash-only:** `#Home`, `#Ideas`, `#Project%20X`.  
  - Simple; works on any static host.  
  - Page id = decodeURIComponent(hash.slice(1)).  
  - Reserve a prefix for “full payload” URLs if you use the hybrid model (e.g. `#r...` and `#e...` as now).
- **Option B – Path-style in hash:** `#/page/Home`, `#/page/Ideas`.  
  - Makes it easy to add more “routes” later (e.g. `#/list`, `#/search`).  
  - Slightly more parsing; still static and free.

**Recommendation:** Start with **hash-only** page ids (`#PageName`). Normalize when saving (e.g. trim, replace spaces with a single space) so `#Ideas` and `#Ideas` are the same. If you need “create on first visit”, empty hash or unknown id can show a default “Home” or an empty page.

---

## 7. Back-links and “page list” (optional)

- **Page list:** List all known page ids by reading localStorage keys (e.g. all keys with prefix `wiki:`). Show in a simple sidebar or menu. No backend needed.
- **Back-links (“Pages that link here”):** For each page, you could scan its content for `[[CurrentPageName]]` and list those. Requires either storing a reverse index (updated on save) or scanning all pages when opening one. Both are doable in the client; scanning is simpler, indexing is faster for many pages.

These are nice UX additions on top of the core “multiple pages + internal links” model.

---

## 8. Hosting and “free” requirement

- **GitHub Pages / Cloudflare Pages / Netlify (static):** All serve static files. Hash changes are handled in the browser; no server config needed. **Fully compatible** with the model above.
- **No backend, no DB:** Everything stays in the client (hash + localStorage or IndexedDB). **Fits your constraints.**

---

## 9. Summary and suggested direction

| Topic | Suggestion |
|-------|------------|
| **Storage** | **localStorage keyed by page id** (e.g. `wiki:PageName`). Optional: hybrid so “share this page” still produces a single-document URL in current format. |
| **URL** | **Hash = page id:** `#PageName` or `#/PageName`. Keep `#r`/`#e` + payload for optional shareable single-document links. |
| **Internal links** | **Wiki syntax** `[[Page Name]]` and `[[Page Name\|label]]`; render as internal links; on click set hash and load from storage (no new tab). |
| **External links** | Keep current behavior: `[text](url)` and bare URLs open in new tab. |
| **Touchpoints** | `parseMarkdown` (add wiki-link token), `serializeToMarkdown` (round-trip wiki links), `load`/`set` (branch on “hash is page id” vs “hash is payload”), click handler (internal vs external). |
| **Lightweight / free** | Stays static, client-only, no backend; works on any static host. |

This gives you a clear path to a wiki-like experience (multiple pages, internal links) while staying within your constraints. When you’re ready to implement, the next step is to wire **hash = page id** and **load/save by page** (localStorage), then add **`[[...]]` parsing and internal link handling**.
