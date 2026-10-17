# Authoring a lesson

Every lesson is one hand-authored HTML page that uses `assets/lesson.css` and `assets/spine.js`, works
from `file://`, and follows the markup contract below. `first.jai - check-lessons` enforces the contract;
run it before committing a page. Lesson text uses American spelling (color, initialization), since
that is what the reader writes; Vulkan's own identifiers are quoted as they are.

## Start from the template

1. Copy `lessons/_template.html` to `lessons/<track>/NN-<slug>.html`, for example
   `lessons/vulkan/03-shaders.html`. Two digits, a dash, a short slug.
2. The template lives one directory up from the tracks, so fix the relative paths after copying:
   `assets/` becomes `../assets/`, every link that starts with `../` gains one more `../` (the index
   crumb, the exercise link, the sources, the next link), and the deep-dives link becomes
   `deep-dives/README.md`. `check-lessons` reports any link that still misses.
3. Set `data-track` and `data-number` on the `<article>`, the crumbs, the title, and the exercise link.
4. Write the steps, the spine, the sidebars, the endnotes, the sources and the next link, in that
   order on the page.
5. Run `~/jai/jai/bin/jai-linux first.jai - check-lessons`, then `first.jai - concept-map` if you added
   or changed a sidebar, and add the page to `index.html`.

`_template.html` is itself checked like any lesson, so it always shows a page that passes. It is never
linked from the index, and the concept map ignores it because it does not live in a track directory.

## Anatomy, in page order

| Part                            | What it is                                                                                                          |
|---------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `<header class="lesson-head">`  | crumbs (`Track · N`), the `<h1>`, and `<a class="exercise">` pointing at the exercise                               |
| `<div class="where">`           | the pinned panel: an empty `<div class="strip">` that `spine.js` fills, then the `<aside class="spine">` with lanes |
| `<div class="body">`            | everything that scrolls: the parts below                                                                            |
| `<noscript>`                    | one line saying the panel does not follow the text without scripts                                                  |
| `<p class="lead">`              | one paragraph on what the lesson is about                                                                           |
| `<ul class="outcomes">`         | exactly three "after this you can" bullets                                                                          |
| `<section class="step" id="…">` | one per step, each with an `<h2>`, prose, a snippet, and where it applies a sidebar                                 |
| `<section class="endnotes">`    | at most three `<details class="endnote">`, each a common alternative flag setup, collapsed                          |
| `<p class="deep-dive">`         | links to deep-dive pages, or to `deep-dives/README.md` when there are none                                          |
| `<section class="sources">`     | the primary sources the load-bearing claims rest on                                                                 |
| `<p class="next">`              | "now do exercise N", linking the exercise                                                                           |

## The markup contract

The checker reports the message in the right column, with the page and line.

| Element                                                                                           | Required                                                                             | Checker message when violated                                                  |
|---------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `<article class="lesson" data-track="vulkan" data-number="3">`                                    | exactly one; both attributes present                                                 | `no <article class="lesson">` / `article lacks data-track`                     |
| `<header class="lesson-head">` with one `<h1>` and `<a class="exercise" href="…">`                | one of each inside the header                                                        | `header has no h1` / `header has no exercise link`                             |
| `<ul class="outcomes">`                                                                           | exactly three `<li>`                                                                 | `outcomes has N items, want 3`                                                 |
| `<section class="step" id="…">` with an `<h2>`                                                    | one or more; ids unique; each id has at least one spine box                          | `duplicate step id 'x'` / `step 'x' has no box in the spine`                   |
| `<pre class="snippet" data-src="path:line"><code>…</code></pre>`                                  | `path` exists under the repo root, `line` is 1..line count                           | `snippet 'p:n': no such file` / `snippet 'p:n': line is past the end`          |
| `<pre class="snippet" data-illustrative="d3d12\|metal\|legacy"><code>…</code></pre>`              | no `data-src` on an illustrative snippet; one of the two attributes on every snippet | `illustrative snippet carries data-src` / `snippet has neither …`              |
| `<aside class="sidebar" id="…" data-term="…">` containing `<dl class="elsewhere">` with `dt`/`dd` | id and term present; at least one `dt`/`dd` pair                                     | `sidebar lacks id` / `sidebar lacks data-term` / `sidebar has no dl.elsewhere` |
| `<details class="endnote"><summary>…</summary>…</details>`                                        | at most three; none has the `open` attribute                                         | `N endnotes, at most 3` / `endnote is open by default`                         |
| `<div class="where">` holding `<div class="strip">` then `<aside class="spine">`                  | exactly one `.where`; the strip empty in the source                                  | `no .where container` / `.where lacks .strip or .spine`                        |
| `<div class="lane" data-lane="cpu">` with `<span class="lane-tag">` and `<div class="bar">`       | three lanes, `cpu`, `driver`, `gpu`, in that order                                   | `lanes are [..], want cpu, driver, gpu`                                        |
| `<button class="box" data-step="…">` and `<span class="arrow" data-step="…">` inside a `.bar`     | every `data-step` names a step id                                                    | `box refers to unknown step 'x'`                                               |
| `<section class="sources"><ul>…</ul></section>`                                                   | present, at least one `<li>`                                                         | `no sources section` / `sources has no entries`                                |
| `<p class="next"><a href="…">…</a></p>`                                                           | present                                                                              | `no next link`                                                                 |
| every relative `href` and `src` (`<a>`, `<link>`, `<script>`, `<img>`)                            | resolves to an existing file; a `#fragment` resolves to an id in the page            | `link target does not exist: …` / `no element with id 'x'`                     |
| `<noscript>`                                                                                      | present once                                                                         | `no noscript note`                                                             |

## Snippets

A snippet shown in a lesson is copied from code in this repository that compiles: the exercise's
`given.jai`, the reference solution, or the harness. `data-src` names where it came from as
`path:line`, the path relative to the repo root and the line where the copied text starts, so drift can
be audited later. Wrap the line the step is about in `<mark>`. Escape `<`, `>` and `&` inside `<code>`.

Code that cannot compile here, for another API or a legacy form, is illustrative: it carries
`data-illustrative="d3d12"`, `"metal"` or `"legacy"` instead of `data-src`, and the stylesheet labels it
as such. Keep it to a few lines.

## Sidebars

A sidebar is where a concept gets its cross-API names. Its `data-term` is the Vulkan term; the
`dl.elsewhere` holds one `dt`/`dd` pair per other API, and the `dt` is spelled exactly `D3D12` or `Metal`,
the two columns the map has (the checker rejects any other spelling). That shape is what `first.jai - concept-map` reads
to assemble `lessons/concept-map.html`, which is why it is required: a sidebar written as free prose
would be invisible to the glossary. Give each sidebar an `id` (`sb-<slug>`) so the map can link to it.

## Endnotes

At most three per lesson, collapsed by default, each in the shape "a common alternative is X, which
enables Y; useful for Z; the cost is setting up A and B at initialization". Enough to know the detail
exists, not the detail itself.

## The spine

The three lanes are `cpu`, `driver` and `gpu`, always in that order; lesson 0 gives them their meaning.
A **box** is one thing that happens in a lane, tagged with the step it belongs to; a step may own several
boxes across several lanes, and that is how a hand-off reads: when the step activates, its boxes light
in document order, CPU first. An **arrow** sits between two boxes in a lane and is tagged with the step
it belongs to, usually the one it leads into. Keep box labels short: the panel is about a third of the
window at desktop width, and a long label makes the lane scroll.

`spine.js` lights the boxes of the step nearest the reading line, fills the strip's chips below 1100 px,
and jumps to a step when its box is clicked. It needs nothing from the page beyond the contract.

## Diagrams

Every lesson has one `<figure class="diagram">` holding an inline `<svg viewBox="…" role="img">` and a
`<figcaption>`; no external images, so the page works from `file://` and themes with the tokens. The
`viewBox` does the scaling: the stylesheet gives the SVG the page's measure (`max-width: 70ch`) and
`height: auto`. Draw with the lane tokens:

- a band is `<g data-lane="cpu|driver|gpu">` holding a `<rect class="band">` (filled and stroked with
  that lane's color through `--lane-color`) and a `<text class="band-tag">` label;
- a box inside a band is `<g class="node"><rect/><text/></g>`;
- a thing that moves between layers (bytecode, a buffer, a stream) is `<g class="token"><rect/><text/></g>`,
  drawn dashed so it reads as data rather than a component;
- arrows are `<path class="link">` ending in the figure's own `<marker id="arrowhead">`; add `hot` for
  the one the step is about;
- the text size is set by the stylesheet (`.78rem`), so position with the `viewBox` units and keep
  labels short enough for the 720 px column.

Lesson 0 draws the three bands every later diagram reuses; copy its figure and change the boxes.

## Deep dives

A deep dive is an optional page on one topic, added only when that topic grabs you. It lives at
`lessons/<track>/deep-dives/<slug>.html`, is linked from its lesson's `p.deep-dive`, and is not listed on
the index. The checker holds it to a lighter contract than a lesson: no outcomes, no steps, no `.where`,
no `<noscript>`, no exercise link and no next link.

| Element                                                                               | Required                             | Checker message when violated                                                                   |
|---------------------------------------------------------------------------------------|--------------------------------------|-------------------------------------------------------------------------------------------------|
| `<article class="deep-dive page" data-track="vulkan" data-lesson="3">`                | exactly one; both attributes present | `no <article class="deep-dive">` / `deep-dive lacks data-track` / `deep-dive lacks data-lesson` |
| `<p class="crumbs">` with an `<a>` whose href resolves to `lessons/<track>/NN-*.html` | present                              | `deep dive has no crumb link to its lesson`                                                     |
| `<h1>`                                                                                | exactly one                          | `deep dive has no h1` / `deep dive has more than one h1`                                        |
| snippets, sidebars, endnotes, sources, links and fragments                            | the lesson rules above, unchanged    | the lesson messages                                                                             |
