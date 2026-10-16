# Lesson Web Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shell every lesson page runs on: the stylesheet with its tokens and the spine layout, the spine script, a lesson template whose anatomy a checker enforces, the landing page, and the concept-map generator, verified in Brave at desktop and laptop widths.

**Architecture:** Hand-authored HTML with one stylesheet and one script, no build step, working from `file://`. The lesson anatomy is a markup contract (class names and data attributes) that a Jai scanner enforces through a `check-lessons` verb of `first.jai`; the same scanner feeds a `concept-map` verb that assembles `lessons/concept-map.html` from every sidebar. `spine.js` has a pure core (pick the active step from positions) and a DOM layer (light the boxes, fill the strip chips, expand and collapse), tested by a page that runs in any browser.

**Tech Stack:** HTML5, CSS custom properties and grid, vanilla JavaScript (Web Animations API, `matchMedia`), Jai beta 0.2.030 for the checker and generator, Brave over the chrome-devtools MCP for browser verification.

**Spec:** `docs/superpowers/specs/2026-10-16-graphics-api-learning-design.md` (section 3 "Web" and "Screen real estate", section 4 items 3 and 7, section 5 items 1, 6, 7, 9 and 10, section 10 expansion pack). Plan 2 of 3; plan 1 is `2026-10-16-foundation.md`.

## Global Constraints

- Web: "No npm/node, no build step. Hand-authored HTML; vendored JS only if a concrete need appears; pages must work from `file://` (so no `fetch` of local files) and from any static server."
- Screen: "Base text 17 px, prose measure about 70 characters, code blocks scroll sideways rather than shrink. Two-column spine at or above about 1100 CSS px; a one-line pinned strip below that." The breakpoint is exactly 1100 CSS px.
- Endnotes: "at most three per lesson, collapsed by default."
- Theme: "Dark and light via `prefers-color-scheme`." Inline SVG diagrams take their colours from the same tokens. No animation library.
- Snippets shown in a lesson carry `data-src="path:line"` (path relative to the repo root); illustrative code (other APIs, legacy forms) carries no `data-src`, carries `data-illustrative`, and is visibly marked.
- Lanes are exactly three, in this order: `cpu`, `driver`, `gpu`. Lesson 0 will set their meaning (app / loader+ICD / kernel+GPU); the shell only fixes the names.
- Layout must not make a later `lessons/advanced/` track awkward: nothing in the CSS, the checker or the index assumes `vulkan/` is the only track directory.
- Repo: branch `master`; Markdown tables aligned in the source; every commit ends with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`; everything runs through `~/jai/jai/bin/jai-linux first.jai - <verb>` from the repo root; `print` for first-class output, `log_error` for failures, never a silent failure.
- Fonts are system stacks (`system-ui` and `ui-monospace` first); nothing is loaded from the network.

## Review Focus

1. **`spine.js` fails to load or scripts are disabled**: the page must still read top to bottom, the spine panel visible and static at wide widths, endnotes opening (native `<details>`). Pinned by the scripts-disabled verification in Task 3 and the `<noscript>` line in the template.
2. **An author forgets a spine box for a step**: the panel would never light for that step. Pinned by `step-without-box` in Task 1.
3. **A solution file is edited so a snippet's `data-src` line is past the end**: the checker must say which snippet and which file. Pinned by `snippet-line-past-end` in Task 1.
4. **The window is resized across 1100 px while the strip is expanded**: switching modes must reset the expansion, so the panel is visible at wide widths and the strip is collapsed at narrow. Pinned by `mode change resets expanded` in Task 3.
5. **A lane with many boxes at 720 px**: the lane bar scrolls sideways and the page itself never scrolls horizontally. Pinned by `lanes scroll, the page does not` in Task 3 and the 720 px screenshot in Task 2.

---

### The markup contract

Every lesson page is one `<article class="lesson">`. The checker (Task 1) enforces the rules in the right column; `lessons/README.md` (Task 2) documents them for whoever writes lesson 0.

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
| `<div class="where">` holding `<div class="strip">` then `<aside class="spine">`                  | exactly one `.where`; the strip empty in the source (JS fills it)                    | `no .where container` / `.where lacks .strip or .spine`                        |
| `<div class="lane" data-lane="cpu">` with `<span class="lane-tag">` and `<div class="bar">`       | three lanes, `cpu`, `driver`, `gpu`, in that order                                   | `lanes are [..], want cpu, driver, gpu`                                        |
| `<button class="box" data-step="…">` and `<span class="arrow" data-step="…">` inside a `.bar`     | every `data-step` names a step id                                                    | `box refers to unknown step 'x'`                                               |
| `<section class="sources"><ul>…</ul></section>`                                                   | present, at least one `<li>`                                                         | `no sources section` / `sources has no entries`                                |
| `<p class="next"><a href="…">…</a></p>`                                                           | present                                                                              | `no next link`                                                                 |
| every relative `href` and `src` (`<a>`, `<link>`, `<script>`, `<img>`)                            | resolves to an existing file; a `#fragment` resolves to an id in the page            | `link target does not exist: …` / `no element with id 'x'`                     |
| `<noscript>`                                                                                      | present once                                                                         | `no noscript note`                                                             |

Scanning is a tag scanner, not an HTML parser: authored pages are well formed, and the rules only need open tags, their attributes, and the text between an open tag and its closing tag.

### Task 1: The lesson checker and the `check-lessons` verb

**Files:**
- Create: `tools/lesson-check/check.jai`, `tools/lesson-check/tests.jai`, `tools/lesson-check/fixtures/src/sample.jai` (12 lines of any valid Jai), `tools/lesson-check/fixtures/lessons/vulkan/neighbour.html` (any small page). The fixtures directory is the `root` the tests pass, so paths inside it mirror the repo: `data-src` paths resolve from `fixtures/`, page-relative links from `fixtures/lessons/vulkan/`.
- Modify: `first.jai` (VERBS, the `#run` dispatch, `test_all`), `README.md` (verb table and layout table)

**Interfaces:**
- Consumes: `first.jai`'s `ROOT`, `build_target`, `run_binary`, `TEST_ENV` as they exist.
- Produces, in `check.jai` (which `first.jai` and `tests.jai` both `#load`; it carries its own `#import`s of Basic, File, File_Utilities and String):

```jai
Finding :: struct { path: string; line: int; message: string; }   // line is 1-based, 0 when unknown

check_lesson     :: (html: string, page_path: string, root: string) -> [..] Finding;   // page_path relative to root, e.g. "lessons/vulkan/03-shaders.html"
check_links      :: (html: string, page_path: string, root: string) -> [..] Finding;   // the href/src/fragment rules alone, usable on any page
check_js         :: (js: string, path: string) -> [..] Finding;                        // flags "fetch(" and "XMLHttpRequest"
resolve_relative :: (page_path: string, href: string) -> string;                       // ("lessons/vulkan/03.html", "../assets/x.css") -> "lessons/assets/x.css"
line_of          :: (text: string, offset: int) -> int;                                // 1-based line of a byte offset
lesson_pages     :: (root: string) -> [..] string;                                     // every lessons/**/*.html except lessons/assets/** and concept-map.html, sorted, relative to root
check_all        :: (root: string) -> (findings: [..] Finding, pages: int);            // lesson_pages, plus lessons/assets/spine.js through check_js when it exists (+ index.html from Task 4, the concept map from Task 5); pages counts the HTML pages checked
```

- Produces, in `first.jai`: the verb `check-lessons` (prints one `path:line: message` line per finding, then `N pages checked, M findings`, fails when `M > 0`) and `tools` as a fourth root that `test-all` scans.

- [ ] **Step 1: Write the test table**

`tests.jai` imports Basic and String and `#load "check.jai"`. It holds one well-formed lesson as a `#string` constant, `GOOD`, that satisfies every rule above: two steps `s1`, `s2`; one snippet with `data-src="src/sample.jai:3"`; one illustrative snippet (`data-illustrative="d3d12"`); one sidebar (`data-term="Command buffer"`); two endnotes followed by the comment `<!-- endnote slot -->`; three lanes, with one box `data-step="s1"`, one box `data-step="s2"` (the only element carrying that value) and one arrow `data-step="s1"`; a body link `<a class="see" href="neighbour.html">` and a fragment link `href="#s2"`; the stylesheet, script, exercise and next links all point at `neighbour.html`, which exists, so the link rule passes without the real assets. Every `from` string below occurs exactly once in `GOOD` unless the case says otherwise, because `replace` replaces every occurrence. Cases mutate `GOOD` and name the findings they expect:

```jai
Case :: struct { name: string; from: string; to: string; expect: [] string; }   // expect: one substring per expected finding

CASES :: Case.[
    .{"good",                       "", "", .[]},
    .{"four-endnotes",              "<!-- endnote slot -->", "<details class=\"endnote\"><summary>x</summary>a</details><details class=\"endnote\"><summary>y</summary>b</details>", .["4 endnotes, at most 3"]},
    .{"open-endnote",               "<details class=\"endnote\">", "<details class=\"endnote\" open>", .["endnote is open by default", "endnote is open by default"]},   // both endnotes match
    .{"snippet-neither",            "data-src=\"src/sample.jai:3\"", "", .["snippet has neither data-src nor data-illustrative"]},
    .{"snippet-line-past-end",      "src/sample.jai:3", "src/sample.jai:99", .["snippet 'src/sample.jai:99': line is past the end"]},
    .{"snippet-missing-file",       "src/sample.jai:3", "src/missing.jai:1", .["snippet 'src/missing.jai:1': no such file"]},
    .{"illustrative-with-src",      "data-illustrative=\"d3d12\"", "data-illustrative=\"d3d12\" data-src=\"src/sample.jai:1\"", .["illustrative snippet carries data-src"]},
    .{"step-without-box",           "data-step=\"s2\"", "data-step=\"s1\"", .["step 's2' has no box in the spine"]},
    .{"box-unknown-step",           "data-step=\"s2\"", "data-step=\"nope\"", .["box refers to unknown step 'nope'", "step 's2' has no box in the spine"]},
    .{"duplicate-step-id",          "id=\"s2\"", "id=\"s1\"", .["duplicate step id 's1'", "box refers to unknown step 's2'", "no element with id 's2'"]},
    .{"two-outcomes",               "<li>outcome three</li>", "", .["outcomes has 2 items, want 3"]},
    .{"sidebar-no-term",            " data-term=\"Command buffer\"", "", .["sidebar lacks data-term"]},
    .{"sidebar-no-dl",              "<dl class=\"elsewhere\">", "<dl>", .["sidebar has no dl.elsewhere"]},
    .{"lanes-out-of-order",         "data-lane=\"driver\"", "data-lane=\"gpu\"", .["lanes are [cpu, gpu, gpu], want cpu, driver, gpu"]},
    .{"no-sources",                 "<section class=\"sources\">", "<section class=\"refs\">", .["no sources section"]},
    .{"no-next",                    "<p class=\"next\">", "<p class=\"last\">", .["no next link"]},
    .{"broken-link",                "class=\"see\" href=\"neighbour.html\"", "class=\"see\" href=\"nowhere.html\"", .["link target does not exist: nowhere.html"]},
    .{"broken-fragment",            "href=\"#s2\"", "href=\"#ghost\"", .["no element with id 'ghost'"]},
    .{"no-noscript",                "<noscript>", "<nonscript>", .["no noscript note"]},
    .{"no-article",                 "<article class=\"lesson\"", "<article class=\"page\"", .["no <article class=\"lesson\">"]},
];
```

Every case asserts: the number of findings equals `expect.count`, and each expected substring occurs in some finding. The page path passed is `"lessons/vulkan/03-sample.html"` and `root` is `tprint("%fixtures/", #filepath)`, so `src/sample.jai` resolves to `fixtures/src/sample.jai` and `neighbour.html` to `fixtures/lessons/vulkan/neighbour.html`.

Two more tables, sequential:

```jai
// resolve_relative
.{"lessons/vulkan/03.html", "../assets/lesson.css", "lessons/assets/lesson.css"},
.{"lessons/vulkan/03.html", "./04.html",            "lessons/vulkan/04.html"},
.{"index.html",             "lessons/concept-map.html", "lessons/concept-map.html"},
.{"lessons/vulkan/03.html", "../../vulkan/exercise-3/README.md", "vulkan/exercise-3/README.md"},
// line_of
line_of("a\nb\nc", 0) == 1,  line_of("a\nb\nc", 2) == 2,  line_of("a\nb\nc", 4) == 3
```

And one for `check_js`: `"const x = fetch('a')"` yields one finding containing `fetch(`; `"const y = 1"` yields none.

The runner prints `PASS <name>` or `FAIL <name>: <detail>` per case, then `N passed, M failed`, and `exit(1)` when any failed. No Gfx_Test import: this target needs no GPU.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `~/jai/jai/bin/jai-linux first.jai - test tools/lesson-check`
Expected: FAIL to build, `check.jai` not found (the target directory exists but the checker does not).

Create `check.jai` with the signatures above and empty bodies returning no findings, then run again.
Expected: `good` and the `check_js` negative pass; every other case FAILs with `0 findings, want 1` or similar; the summary line reports the failures; exit code 1.

- [ ] **Step 3: Implement `check.jai`**

A tag scanner: `next_tag(html, from) -> (tag: Tag, found: bool)` where `Tag` holds `name`, the attribute text, `start`, and `end` offsets of the open tag; `attr(tag, name) -> (value: string, found: bool)`; `has_class(tag, name) -> bool` (token match on `class`); `inner(html, tag) -> string` (text to the matching `</name>`, nesting ignored, enough for `aside`, `ul`, `header`, `section`, `div.bar`). Build the rules on those. `data-src` resolves the path against `root`, reads the file and counts lines. Links resolve with `resolve_relative`; `http://`, `https://`, `mailto:`, `data:` and bare `#` are skipped. `lesson_pages` uses `file_list(tprint("%lessons", root), recursive = true)` filtered on `.html`, excluding `concept-map.html`, sorted.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `~/jai/jai/bin/jai-linux first.jai - test tools/lesson-check`
Expected: every case `PASS`; the summary ends in `0 failed`; exit code 0.

- [ ] **Step 5: Add the verb and the fourth test root**

In `first.jai`: `#load "tools/lesson-check/check.jai";` after the imports; a VERBS row `check-lessons                      check every lessons/**/*.html, index.html and spine.js against the markup contract`; a dispatch case that calls `check_all(ROOT)`, prints the findings as `%:%: %` lines, prints `% pages checked, % findings`, and sets `ok = findings.count == 0`; `test_all` iterates `string.["vulkan", "directx", "metal", "tools"]` and its VERBS row and the README row say so.

Run: `~/jai/jai/bin/jai-linux first.jai - check-lessons`
Expected: `0 pages checked, 0 findings`, exit 0 (nothing under `lessons/` yet; a missing `spine.js` is not a finding in itself, the template's `<script src>` link catches it in Task 2).

Run: `~/jai/jai/bin/jai-linux first.jai - test-all`
Expected: `tools/lesson-check: ok` and `vulkan/harness-check: ok`, `2 targets, 0 failed`.

- [ ] **Step 6: README rows, then commit**

Add the `check-lessons` verb row and a `tools/` row to the layout table in `README.md`, both aligned.

```bash
git add tools/lesson-check first.jai README.md
git commit -m "Add the lesson checker: markup contract rules, check-lessons verb, tools/ as a test root"
```

### Task 2: Stylesheet, the lesson template, and the authoring guide

**Files:**
- Create: `lessons/assets/lesson.css`, `lessons/_template.html`, `lessons/README.md`, `lessons/vulkan/deep-dives/README.md`
- Test: `check-lessons` (Task 1) and screenshots in Brave

**Interfaces:**
- Consumes: the markup contract; `vulkan/harness-check/tests.jai` as the source of real snippets.
- Produces: the class names Task 3 scripts against (`.where`, `.strip`, `.spine`, `.lane[data-lane]`, `.lane-tag`, `.bar`, `.box[data-step]`, `.arrow[data-step]`, `section.step[id]`), the modifier classes JS sets (`.where.expanded`, `.box.on`, `.arrow.on`, `.chip.on`, `section.step[aria-current="step"]`), and the tokens every later SVG uses.

- [ ] **Step 1: Write the template so the checker has something to reject**

`lessons/_template.html` is a complete lesson page about something real and small, so every snippet has a true `data-src`: "Template lesson: clear a target and read it back", walking `clear_color_reads_back` in `vulkan/harness-check/tests.jai` in five steps with ids `s1`..`s5` (create the target, transition the image, record the clear, submit and wait, read back), each with a short paragraph and a snippet whose `data-src` points at the real lines. The spine has the three lanes with these boxes: cpu `create_target`(s1) `transition_image`(s2) `vkCmdBeginRendering`(s3) → `submit_and_wait`(s4); driver `translate`(s4) → `kernel: submit`(s4); gpu `clear`(s4) → `copy`(s5) `readback`(s5). One sidebar on step 3 (`id="sb-clear"`, `data-term="Dynamic rendering"`, dt/dd for D3D12 `OMSetRenderTargets + ClearRenderTargetView` and Metal `MTLRenderPassDescriptor loadAction = clear`). One illustrative snippet in the sidebar (`data-illustrative="d3d12"`, two lines). Two endnotes. A sources section pointing at the Vulkan spec's dynamic rendering chapter. The exercise link points at `../../vulkan/harness-check/tests.jai`; the next link at `../../vulkan/harness-check/main.jai`; the deep-dive line links `deep-dives/README.md` (created in this task with one sentence: deep dives are added on demand, none yet). `data-track="template"`, `data-number="0"`. A `<noscript>` line says the panel does not follow the text without scripts. The head links `assets/lesson.css` and `assets/spine.js` (`defer`); the script does not exist yet, so the link rule will flag it. The step headings are long enough to wrap at 720 px, and lane `cpu` has a fourth box with a long label so the bar overflows at that width.

Run: `~/jai/jai/bin/jai-linux first.jai - check-lessons`
Expected: `1 pages checked, 1 findings`: `lessons/_template.html:<n>: link target does not exist: assets/spine.js`, exit 1. Any other finding is a template bug; fix it before going on.

- [ ] **Step 2: Write `lesson.css`**

Tokens on `:root`, dark values under `@media (prefers-color-scheme: dark)`:

| Token                                       | Light                                                                                                                       | Dark                            |
|---------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|---------------------------------|
| `--bg`, `--bg-2`, `--bg-3`                  | `#fff`, `#f5f6f8`, `#e9ebef`                                                                                                | `#121417`, `#1a1d22`, `#23272e` |
| `--fg`, `--fg-2`, `--fg-3`                  | `#1b1f24`, `#4b535e`, `#7a8290`                                                                                             | `#e6e8eb`, `#aab2bd`, `#767e8a` |
| `--line`                                    | `#d6dae0`                                                                                                                   | `#333a44`                       |
| `--accent`                                  | `#0a6cff`                                                                                                                   | `#4d9bff`                       |
| `--lane-cpu`, `--lane-driver`, `--lane-gpu` | `#2fb257`, `#f0930a`, `#0a84ff`                                                                                             | same hues, 10 % lighter         |
| `--sidebar`                                 | `#7c4dff`                                                                                                                   | `#a98bff`                       |
| `--mark`                                    | `rgba(10,108,255,.18)`                                                                                                      | `rgba(77,155,255,.28)`          |
| `--font`, `--mono`                          | `system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`; `ui-monospace, "JetBrains Mono", "Fira Code", Menlo, monospace` | same                            |

Layout rules the implementer writes from this list:
- `html { font-size: 17px }`; `body` colour and background from tokens; `p, li, dd { max-width: 70ch }`; `pre { overflow-x: auto; font: 0.88em/1.45 var(--mono) }`; `mark` uses `--mark` with no colour change.
- `.lesson { display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(300px, 1fr); gap: 2rem; padding: 0 1.25rem }` at `min-width: 1100px`; the header spans both columns; `.where { grid-column: 2; position: sticky; top: 1rem; align-self: start }`; `.strip { display: none }` at this width.
- Below 1100 px: one column; `.where { position: sticky; top: 0; z-index: 2; background: var(--bg); border-bottom: 1px solid var(--line) }`; `.strip` is a flex row of chips with the `strip-toggle` button at the end; `.spine { display: none }` and `.where.expanded .spine { display: block; max-height: 50vh; overflow: auto }`.
- `.lane { display: grid; grid-template-columns: 4.5rem 1fr; align-items: center }`; `.bar { display: flex; gap: .35rem; overflow-x: auto; padding: .3rem .5rem; border-radius: .4rem; background: color-mix(in srgb, var(--lane-colour) 12%, transparent) }` with `--lane-colour` set per `data-lane`; `.box` is a bordered pill button, `.box.on` takes the lane colour border and a tinted background, boxes that are not `.on` sit at 55 % opacity once any box is on (`.spine.live .box:not(.on)`); `.arrow.on` is the accent colour and bold.
- `.chip` mirrors `.box`; `.chip.on` shows its lane colour; `.chip .sub` is `--fg-3`.
- `.sidebar { border-left: 3px solid var(--sidebar); padding: .5rem .9rem; background: color-mix(in srgb, var(--sidebar) 8%, transparent) }`; `dl.elsewhere` renders inline: `dt` bold with a trailing colon, `dd` inline, pairs separated by " · ".
- `pre[data-illustrative]::before { content: "illustrative · " attr(data-illustrative) }` as a small uppercase tag in `--fg-3`.
- `.endnote { border: 1px dashed var(--line); border-radius: .4rem; padding: .4rem .8rem }`; `.endnote summary { cursor: pointer }`.
- `@media (prefers-reduced-motion: reduce) { * { transition: none !important } }`.
- An `.index` block for Task 4's landing page: `.tracks { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem }`, `.track` card, `.track.tbd { opacity: .55 }`, `.lrow` three-column rows (number, title, marks), `.pill` and `.pill.live`.

- [ ] **Step 3: Verify in Brave at both widths**

Use the chrome-devtools MCP (Brave on 9222): `new_page` with `file:///home/jim/projects/understaning-graphic-apis/lessons/_template.html`, `resize_page` to 1280×800, `take_screenshot`.
Expected: two columns; prose left, the three-lane panel right with "Where is this happening?" and nine boxes; the sidebar with a violet bar; two collapsed endnotes; no horizontal scrollbar.

`resize_page` to 720×900, `take_screenshot`, then `evaluate_script` returning `[getComputedStyle(document.querySelector('.strip')).display, getComputedStyle(document.querySelector('.spine')).display, document.documentElement.scrollWidth === document.documentElement.clientWidth, document.querySelector('.lane[data-lane=cpu] .bar').scrollWidth > document.querySelector('.lane[data-lane=cpu] .bar').clientWidth]`.
Expected: `["flex", "none", true, true]`: the strip row is visible (empty chips area plus the toggle until Task 3 fills it), the panel hidden, no page overflow, the cpu bar overflowing within itself.

Dark mode: raw CDP from Node (the recipe in `~/.claude/CLAUDE.md`), `Emulation.setEmulatedMedia` with `features: [{name: "prefers-color-scheme", value: "dark"}]`, then a screenshot.
Expected: dark background, tokens applied to the lanes and sidebar, text readable.

- [ ] **Step 4: Write `lessons/README.md`**

"Authoring a lesson": copy `_template.html`, the anatomy in page order, the markup contract table from this plan (aligned), where snippets come from and how `data-src` is written, the sidebar `dl` shape and why (it feeds the concept map), the three-endnote rule, the lane names and what a box and an arrow are, how to run `check-lessons`, and that `_template.html` is checked like any lesson but never linked from the index.

- [ ] **Step 5: Run the checker and commit**

Run: `~/jai/jai/bin/jai-linux first.jai - check-lessons`
Expected: still exactly the one `assets/spine.js` finding (Task 3 clears it).

```bash
git add lessons/assets/lesson.css lessons/_template.html lessons/README.md lessons/vulkan/deep-dives/README.md
git commit -m "Lesson shell: tokens, the spine layout and its narrow strip, a template lesson with real snippets, the authoring guide"
```

### Task 3: `spine.js` and its in-browser test page

**Files:**
- Create: `lessons/assets/spine.js`, `lessons/assets/spine-check.html`
- Test: `spine-check.html` (opened in Brave; `document.title` is the verdict), `check-lessons`

**Interfaces:**
- Consumes: the Task 2 class names and modifier classes.
- Produces `window.Spine`:

```js
Spine.pick(tops, line)          // pure: index of the last step whose top <= line, else 0; tops are numbers in document order
Spine.init(root = document)     // wires everything below; returns Spine.state; safe to call once per page
Spine.activate(stepId)          // .on on every .box/.arrow[data-step=stepId], .live on .spine, aria-current="step" on the section, chips updated, stagger animation unless reduced motion
Spine.setExpanded(bool)         // .expanded on .where, aria-expanded on the toggle button, toggle label "expand ▾" / "collapse ▴"
Spine.setMode("wide"|"narrow")  // records the mode and calls setExpanded(false)
Spine.state                     // { active: stepId|null, mode: "wide"|"narrow", expanded: bool }
```

Behaviour `init` installs: a scroll listener throttled with `requestAnimationFrame` that computes each step's `getBoundingClientRect().top` and calls `activate` with `pick(tops, line)` where `line = 0.4 * innerHeight + stripHeight` (strip height is 0 at wide); a `matchMedia("(min-width: 1100px)")` listener that calls `setMode`; a click handler on every `.box` that calls `history.replaceState(null, "", "#" + stepId)` and `scrollIntoView({block: "start"})` on the step; a click handler on the `.strip-toggle` button (created by `init` inside `.strip`, after the chips) that toggles expansion; chips: one `<span class="chip" data-lane="…">` per lane, text from `.lane-tag`, with `<span class="chip-arrow">→</span>` between chips; when a step is active, chips whose lane holds an `.on` box get `.on`, the first such chip gets a `<span class="sub"> · <first lit box label></span>`, and a chip-arrow between two `.on` chips gets `.on`. The stagger: for each lit box in document order, `box.animate([{opacity: .4}, {opacity: 1}], {duration: 180, delay: i * 120})`, skipped when `matchMedia("(prefers-reduced-motion: reduce)").matches`. The spec named `IntersectionObserver` for picking the step; a scroll listener over positions does the same job with a pure, testable core, which is why it is used here (my call, veto welcome).

- [ ] **Step 1: Write `spine-check.html`**

A page that links `lesson.css` and `spine.js`, contains a minimal lesson DOM (three steps `a`, `b`, `c`, each 900 px tall so the page scrolls; the `.where` with three lanes; boxes `a`→cpu, `b`→cpu and driver, `c`→gpu; one arrow for `b`; a wrapper `<div style="width: 420px">` around a second `.lane` copy whose bar has eight boxes, for the overflow test) and an inline test script that runs after `DOMContentLoaded`. Each test is `t(name, fn)`; a thrown error is a failure. Results go into `<pre id="results">` as `PASS name` / `FAIL name: message` lines; the summary `N passed, M failed` is the last line and `document.title` becomes `PASS` or `FAIL`. Tests:

| Test                                        | Asserts                                                                                                                                         |
|---------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| `pick chooses the last step above the line` | `pick([-500, -100, 300], 0) === 1`; `pick([50, 400, 900], 0) === 0`; `pick([], 0) === 0`                                                        |
| `activate lights boxes and arrows`          | after `activate("b")`: two `.box.on`, one `.arrow.on`, `.spine.live`, `section#b[aria-current=step]`, no other `.on`                            |
| `activate updates chips`                    | chips `cpu` and `driver` `.on`, chip-arrow between them `.on`, chip `gpu` not; first `.on` chip's `.sub` text ends with the first lit box label |
| `activate animates when motion is allowed`  | skip with PASS if reduced motion matches; else `document.querySelector(".box.on").getAnimations().length === 1`                                 |
| `box click jumps to its step`               | click the `c` box; `location.hash === "#c"`; `Spine.state.active` becomes `"c"` after one animation frame                                       |
| `toggle expands and collapses`              | `setExpanded(true)`: `.where.expanded`, button `aria-expanded="true"`, label contains "collapse"; `setExpanded(false)` reverses                 |
| `mode change resets expanded`               | `setExpanded(true); setMode("wide")` → `Spine.state.expanded === false` and no `.expanded`                                                      |
| `scrolling activates the step at the line`  | `window.scrollTo(0, 950)`; after two animation frames `Spine.state.active === "b"`                                                              |
| `lanes scroll, the page does not`           | the 420 px lane's bar `scrollWidth > clientWidth`; `document.documentElement.scrollWidth === document.documentElement.clientWidth`              |

- [ ] **Step 2: Open it to verify it fails**

chrome-devtools: `navigate_page` to `file:///home/jim/projects/understaning-graphic-apis/lessons/assets/spine-check.html`, `evaluate_script` returning `[document.title, document.getElementById("results").textContent]`.
Expected: title `FAIL`; every test fails with `Spine is not defined` (the script file does not exist).

- [ ] **Step 3: Implement `spine.js`**

An IIFE assigning `window.Spine`; `init` runs on `DOMContentLoaded` when a `.where` exists on the page (so `spine-check.html` can also call it on its fixture). No `fetch`, no `XMLHttpRequest`, no module syntax (file:// and `defer` are enough).

- [ ] **Step 4: Open the check page to verify it passes**

Reload and evaluate as in Step 2.
Expected: title `PASS`; results end with `9 passed, 0 failed`.

- [ ] **Step 5: Verify the template live, at both widths and without scripts**

`navigate_page` to the template; at 1280×800 `evaluate_script`: `window.scrollTo(0, document.getElementById("s4").offsetTop + 10); await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))); return [Spine.state.active, [...document.querySelectorAll(".box.on")].map(b => b.textContent)]`.
Expected: `["s4", ["submit_and_wait", "translate", "kernel: submit", "clear"]]`. `take_screenshot`: the four boxes lit across all three lanes, the rest dimmed.

At 720×900: `take_screenshot`.
Expected: the strip reads `cpu · submit_and_wait → driver → gpu` with all three chips lit and both chip-arrows lit, then the `expand ▾` button. `click` the button, `take_screenshot`.
Expected: the panel drops down under the strip; the text is still readable below it.

Scripts disabled: raw CDP `Emulation.setScriptExecutionDisabled {value: true}` then reload at 1280×800, `take_screenshot`.
Expected: two columns, the panel present with no box lit, the `<noscript>` line visible, endnotes open on click. Re-enable scripts afterwards.

- [ ] **Step 6: Checker, then commit**

Run: `~/jai/jai/bin/jai-linux first.jai - check-lessons`
Expected: `1 pages checked, 0 findings` (the template; `spine-check.html` sits under `lessons/assets/`, which `lesson_pages` skips, and `spine.js` now passes `check_js`).

```bash
git add lessons/assets/spine.js lessons/assets/spine-check.html
git commit -m "spine.js: active-step highlighting, lane chips and the narrow strip, with an in-browser test page"
```

### Task 4: The landing page and its checker rules

**Files:**
- Create: `index.html`
- Modify: `tools/lesson-check/check.jai` (`check_index`, `check_all`), `tools/lesson-check/tests.jai`, `README.md` (layout table row for `index.html`)

**Interfaces:**
- Consumes: `check_links`, `lesson_pages`, the `.index` CSS block from Task 2.
- Produces: `check_index :: (html: string, root: string, pages: [] string) -> [..] Finding` and `index.html` with this shape: `<header class="site-head">` (title "Understanding Graphics APIs", subtitle "Vulkan · DirectX · Metal, in Jai", links to `lessons/concept-map.html` and `lessons/vulkan/deep-dives/README.md`); `<section class="tracks">` with three `<article class="track" data-track="vulkan|directx|metal">` cards; the Vulkan card has one `<div class="lrow" data-number="N">` per lesson 0–9 with the titles from the spec's section 7 table, plus three `lrow` entries for `project-1` (after 4), `project-2` (after 7), `project-3` (after 9) carrying `data-project="1|2|3"`; each row holds a number cell, a title cell (an `<a>` to `lessons/vulkan/NN-slug.html` only when that file exists, plain text otherwise), and a marks cell with three `<span class="mark" data-state="todo|current|done">` named `lesson`, `exercise`, `tests`; the DirectX and Metal cards carry `class="track tbd"`, a `.pill` reading `TBD · Windows` / `TBD · macOS`, and link their `README.md`. A closing `<section class="howto">` shows the four verbs a reader needs (`build`, `run`, `test`, `capture`) in a `<pre>`.

Index rules, enforced by `check_index`:

| Rule                                                                                     | Message                                                       |
|------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| every page in `lesson_pages` under a track directory, except `_template.html`, is linked | `lesson page not linked from index: lessons/vulkan/03-….html` |
| `lrow[data-number]` values in each track card are ascending with no gaps from 0          | `track 'vulkan' rows are [..], want 0..N in order`            |
| a row whose `lesson` mark is `done` links to an existing page                            | `row 3 says the lesson is done but links nothing`             |
| the three track cards exist, in the order vulkan, directx, metal                         | `tracks are [..], want vulkan, directx, metal`                |
| links resolve (`check_links`)                                                            | as in Task 1                                                  |

- [ ] **Step 1: Add the index cases to the test table**

A second `#string` constant `GOOD_INDEX` with the shape above and rows 0..2, and cases: `index-good` (no findings, with `pages = ["lessons/vulkan/00-a.html"]` and a link to it in `GOOD_INDEX`, `fixtures/lessons/vulkan/00-a.html` present as a small file); `index-unlinked-page` (`pages` also names `lessons/vulkan/01-b.html` → `lesson page not linked from index: lessons/vulkan/01-b.html`); `index-rows-out-of-order` (swap two `data-number`s → `track 'vulkan' rows are [0, 2, 1], want 0..2 in order`); `index-done-without-link` (mark `done` on an unlinked row → `row 2 says the lesson is done but links nothing`); `index-tracks-out-of-order` (swap the metal and directx cards → `tracks are [vulkan, metal, directx], want vulkan, directx, metal`).

Run: `~/jai/jai/bin/jai-linux first.jai - test tools/lesson-check`
Expected: the five new cases FAIL (`check_index` undefined, or 0 findings), the rest PASS.

- [ ] **Step 2: Implement `check_index` and include `index.html` in `check_all`**

Run: `~/jai/jai/bin/jai-linux first.jai - test tools/lesson-check`
Expected: all PASS, `0 failed`.

- [ ] **Step 3: Write `index.html`**

Rows for lessons 0–9 and the three projects; no lesson links yet (no lesson pages exist), every mark `todo`. The `.index` block in `lesson.css` renders the mockup's three-card layout; the page is one column below 1100 px with the cards stacked.

Run: `~/jai/jai/bin/jai-linux first.jai - check-lessons`
Expected: `2 pages checked, 0 findings` (the template and `index.html`).

chrome-devtools: `navigate_page` to `file:///home/jim/projects/understaning-graphic-apis/index.html` at 1280×800 and at 720×900, `take_screenshot` each.
Expected: three cards side by side at 1280, stacked at 720; the DirectX and Metal cards dimmed with their pills; the Vulkan card listing 0–9 with the projects interleaved after 4, 7 and 9; no horizontal scrollbar.

- [ ] **Step 4: Commit**

```bash
git add index.html tools/lesson-check lessons/assets/lesson.css README.md
git commit -m "Landing page: three track cards, the Vulkan lesson list with hand-maintained marks, index rules in the checker"
```

### Task 5: The concept map, generated from the sidebars

**Files:**
- Create: `lessons/concept-map.html` (generated and committed)
- Modify: `tools/lesson-check/check.jai`, `tools/lesson-check/tests.jai`, `first.jai` (verb `concept-map`, staleness in `check_all`), `README.md` (verb row)

**Interfaces:**
- Consumes: the sidebar markup (`aside.sidebar[id][data-term]` with `dl.elsewhere`), the lesson header (`article[data-track][data-number]`, `h1`).
- Produces:

```jai
Sidebar_Entry :: struct { term: string; api: string; text: string; track: string; number: string; lesson_title: string; href: string; }   // href: "vulkan/03-shaders.html#sb-clear", relative to lessons/
collect_sidebars :: (root: string) -> [..] Sidebar_Entry;      // every lessons/<track>/[0-9][0-9]-*.html; never _template.html
concept_map_html :: (entries: [] Sidebar_Entry) -> string;     // the whole page
```

The page: the same head as a lesson (stylesheet, no spine), `<h1>Concept map</h1>`, one sentence saying it is generated by `first.jai - concept-map` from every sidebar, then `<table class="concept-map">` with columns Term, Lesson, D3D12, Metal; one row per distinct term, sorted case-insensitively; the Lesson cell links `href` with the text `<track> <number>: <lesson_title>`; an API cell holds that api's `dd` text or `—`; a term that appears in two lessons gets two rows. With no entries the table is replaced by `<p class="empty">No sidebars yet.</p>`.

- [ ] **Step 1: Add the generator cases**

Cases in `tests.jai`, sequential: `collect_sidebars` over a fixtures tree `fixtures/lessons/vulkan/00-a.html` (one sidebar, term "Queue", dt D3D12 / dd "command queue", dt Metal / dd "MTLCommandQueue") and `fixtures/lessons/vulkan/01-b.html` (two sidebars, terms "Fence" and "Queue") returns four entries, sorted by term then number, with `href` `vulkan/00-a.html#sb-queue` on the first; `concept_map_html` of those entries contains `<td><a href="vulkan/00-a.html#sb-queue">vulkan 0: A</a></td>` and three `<tr` rows in the body; `concept_map_html(.[])` contains `No sidebars yet.`; `_template.html` placed in the fixtures tree is ignored.

Run: `~/jai/jai/bin/jai-linux first.jai - test tools/lesson-check`
Expected: the new cases FAIL to compile or fail; the rest PASS.

- [ ] **Step 2: Implement, then make them pass**

Run: `~/jai/jai/bin/jai-linux first.jai - test tools/lesson-check`
Expected: all PASS.

- [ ] **Step 3: The verb and the staleness rule**

`first.jai`: VERBS row `concept-map                        regenerate lessons/concept-map.html from every lesson's sidebars`; the case writes `concept_map_html(collect_sidebars(ROOT))` to `lessons/concept-map.html` and prints the path and the entry count. `check_all` compares the committed file with a fresh generation and reports `lessons/concept-map.html is stale: run first.jai - concept-map` when they differ, or `lessons/concept-map.html is missing` when absent.

Run: `~/jai/jai/bin/jai-linux first.jai - check-lessons`
Expected: `… lessons/concept-map.html is missing`, exit 1.

Run: `~/jai/jai/bin/jai-linux first.jai - concept-map`
Expected: `concept-map: lessons/concept-map.html (0 entries)`.

Run: `~/jai/jai/bin/jai-linux first.jai - check-lessons`
Expected: `3 pages checked, 0 findings`, exit 0 (the template, `index.html`, the concept map). Then `~/jai/jai/bin/jai-linux first.jai - test-all`: `2 targets, 0 failed`.

- [ ] **Step 4: Look at it, then commit**

chrome-devtools: `navigate_page` to the concept map at 1280×800, `take_screenshot`.
Expected: the heading, the sentence, "No sidebars yet." in the lesson typography, dark or light per the system.

```bash
git add lessons/concept-map.html tools/lesson-check first.jai README.md
git commit -m "concept-map verb: assemble the cross-API glossary from every sidebar; check-lessons flags a stale map"
```

---

## Self-review notes

- Spec coverage: layout item 1 (files) → Tasks 2–5; item 6 (anatomy) → the contract and Task 2; item 7 (SVG, WAAPI, spine.js) → Tasks 2–3, with the IntersectionObserver choice revised to a scroll listener and said so; item 3's `data-src` → Task 1; item 10 (illustrative code) → Task 1 and the template; section 3 Web and Screen → Global Constraints, Task 2; section 10 expansion pack → the track-agnostic rules in Tasks 1 and 4. Deep-dive pages themselves are plan 3 content; this plan only gives them a directory and a link target.
- Not in this plan, on purpose: snippet drift auditing beyond existence and line range (the spec defers it); syntax highlighting (hand-authored `<mark>` is enough for "this line"); a search box; printing styles.
