# Vulkan Content, Part 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lessons 0 to 4 of the Vulkan track as rendered pages, each with a reinforcement exercise whose headless tests a reference solution passes, plus project 1 with its rubric, and the deep-dive page rule that later parts need.

**Architecture:** Each lesson pairs a page under `lessons/vulkan/` with a target under `vulkan/exercise-N/` whose `tests.jai` is the gate, and a solution under `solutions/vulkan/exercise-N/` that proves the gate passable and sources the page's snippets. The test cases live in one file, `cases.jai`, that two three-line entry files assemble, one with the stubs and one with the solution, so the same tests run against both. Pages follow the plan 2 markup contract unchanged; the checker gains one light contract for deep-dive pages. Lesson 0 fixes the diagram style every later lesson copies: one inline SVG per lesson drawn with the lane tokens.

**Tech Stack:** Jai beta 0.2.030; the regenerated `modules/Vulkan` (header 363); `modules/Gfx_Test`; GLSL through `glslc --target-env=vulkan1.3`; X11 through the distribution's `Window_Creation` and `Input` modules; hand-authored HTML on `lessons/assets/lesson.css` and `spine.js`; Brave over the chrome-devtools MCP for page checks.

**Spec:** `docs/superpowers/specs/2026-10-16-graphics-api-learning-design.md` (sections 1, 2; 4 items 2, 3, 4, 6, 8, 10; 5 items 3, 4, 5, 6, 7, 8, 9, 10, 12; 7 rows 0 to 4; 8; 10). Plan 3 of the series, part 1 of 3; plan 1 is `2026-10-16-foundation.md`, plan 2 is `2026-10-16-lesson-web-shell.md`. Parts 2 and 3 cover lessons 5 to 7 with project 2 and lessons 8 to 9 with project 3.

## Global Constraints

- Toolchain: "Jai beta 0.2.030 (`~/jai/jai/bin/jai-linux`). The distribution's modules are used wherever they work: `X11`, `Window_Creation`, `Basic`, `Math`, `File`." Everything runs through `~/jai/jai/bin/jai-linux first.jai - <verb>` from the repo root.
- Platform: "Linux, X11 only ... **No vendor assumptions anywhere**: prefer a discrete GPU, fall back to whatever is first; AMD-specific material is confined to optional deep dives." Spec 5.9 allows a named vendor inline as a concrete example after the generic statement; the harness and every test must run on the laptop's NVIDIA/Intel hybrid.
- Shaders: "Native, first-class languages only: GLSL compiled to SPIR-V with `glslc` for Vulkan ... No Slang." "Shaders are compiled by the build, not committed as SPIR-V."
- Tests: "Headless: no window; render into an offscreen image. First assertion is always zero validation errors ... Second is pixel readback checked against what the exercise asked for. Pure CPU-side pieces get ordinary table-driven tests." "Pixel assertions use a per-channel tolerance of 1 by default." A `needs_display` case may open a window, as `harness-check` does, and is SKIPped without `DISPLAY`.
- Validation: "Synchronization validation ... is switched on from exercise 5 onward ... before that, exercises 2–4 get the image-layout transitions they need as helper code in `given.jai`, with the lesson saying in one line that this is a barrier and that lesson 5 opens it up."
- Exercise shape, spec 5.3: `README.md`, `given.jai` ("to be read as a library, not edited"), `exercise.jai` ("the TODO stubs Jim fills in, with the signatures fixed"), `tests.jai`, `main.jai`, `shaders/`. "The README's contract ... names the concrete variation, and `tests.jai` checks that variation, not the lesson's numbers."
- Lesson rule, spec 4.10: "Lesson N may show the real calls for its new mechanism, taken as fragments from the reference solution." "Snippets shown in a lesson are copied from compiling code in the repo (`given.jai` or the reference solution) and carry a `data-src="path:line"` attribute."
- Endnotes: "at most three per lesson, collapsed by default", each "a common alternative is X, which enables Y; useful for Z; the cost is setting up A and B at initialization." Sidebars: conceptual, `dt` spelled exactly `D3D12` or `Metal`; other-API and legacy code carries `data-illustrative` and no `data-src`.
- Evidence, spec 5.9: "Load-bearing mechanism claims that are not simply the specification's words carry a pointer to a primary source ... Each lesson ends with a short 'Sources' list." Every path or URL in a Sources list is opened and read before it is cited, per Jim's standing rule that anything that matters lands on a primary source; a path that does not exist is not cited.
- Pages: the plan 2 markup contract (`lessons/README.md`), 17 px base, 70ch measure, 1100 px breakpoint, works from `file://`, no `fetch`, American spelling in reader-facing text, Vulkan identifiers quoted as they are.
- Repo: branch `master`; Markdown tables aligned in the source; every commit ends with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`; `print` for first-class output, `log_error` for failures, never a silent failure.

## Plan-level decisions

Rulings made while planning; the executor inherits them and ledgers any deviation.

1. **Lesson 4's "where" story follows the driver source, not the spec's wording.** Spec 7 says "submit is where translation and the kernel hand-off happen". On RADV every `vkCmd*` call appends the hardware's own packets (PM4) to a buffer in GPU-visible memory while recording; `vkQueueSubmit2` builds a `DRM_IOCTL_AMDGPU_CS` ioctl naming those buffers and the sync objects, and the GPU's command processor fetches the packets from memory. Nothing is translated at submit. Spec 2 names hand-waving at "what submit does" as an anti-goal, so accuracy wins. The template's step-4 prose repeats the spec's wording and is corrected in Task 11.
2. **Solutions are build targets.** `solutions/vulkan/exercise-N/` holds the complete `exercise.jai`, three-line `tests.jai` and `main.jai` assembly files, and its own `shaders/` when the learner writes shaders. `test-all` scans `solutions/`; building a `solutions/<api>/<name>` target also compiles `<api>/<name>/shaders/`, because `given.jai` loads its SPIR-V relative to its own `#filepath` (Task 2).
3. **Deep-dive pages get a light contract and are exempt from the index rule** (Task 1). No deep dive is written in this part: spec 4.4 adds them on demand. Lesson 3 links `deep-dives/README.md`, which already names the RADV candidate.
4. **Test cases live in `cases.jai`**; the two `tests.jai` files only `#load`. Imports are file-scoped in Jai (`how_to/040`), so every file carries its own `#import` lines.
5. **The windowed loop is written once**, in exercise 2's `given.jai`, with a record callback that appends finished command buffers; exercises 3 and 4 and project 1 copy it forward unchanged as spec 5.3's "finished code from earlier lessons". One frame in flight; frames in flight are lesson 5.
6. **The desktop's RADV reports one queue family** (graphics, compute, transfer and sparse together, one queue; `vulkaninfo`, Mesa 26.2.4). Lesson 1 says so; the exercise 1 tables carry the layouts other drivers report, and the live cases adapt to whatever device runs them.
7. **`p.next` of lesson N links exercise N's README**; Task 13 appends a "then lesson N+1" link once every page exists, since the checker refuses a link to a page that does not exist yet.
8. **Exercise 0 is pure CPU work plus one live inventory**, as spec 7 row 0 says; its "which layer answered" column is printed by `given.jai` and taught by the page, while the tests pin the parsing and the extension bookkeeping.

## Review Focus

1. **A learner's stub target must build and fail at the tests, never fail to compile.** Every `exercise.jai` stub and shader stub compiles as shipped; pinned by step 2 of every exercise task (`test vulkan/exercise-N` builds, cases FAIL, exit 1).
2. **A device without a transfer-only family, or a surface with an undefined `currentExtent`.** The laptop's Intel GPU reports one family; a surface may report `0xFFFFFFFF` (Wayland does, X11 reports the window size), and the code must not divide by it. Pinned by `families_single_family` (Task 4) and `extent_clamps_when_undefined` (Task 6), and every live case reads the real properties instead of assuming them.
3. **Winding and culling decided by luck.** A triangle that shows because culling was never on proves nothing. Pinned by `triangle_culled_when_front_face_is_clockwise` and `triangle_shows_when_cull_is_none` (Task 8).
4. **Two render instances on one image without a barrier.** Synchronization validation is off until lesson 5, so the tests cannot catch a missing write-after-write barrier. Pinned by the tests supplying `prepare_target` and `attachment_barrier` around the learner's buffers (Task 10) and the README naming the rule; the reviewer checks that `present_loop` (Task 6), exercise 4 and project 1 carry the barrier wherever two render instances touch one image.
5. **Long box labels at 720 px.** Lesson spines carry labels such as `vkEnumerateInstanceExtensionProperties`; the lane bar must scroll and the page must not. Pinned by the 720 px `scrollWidth` check in every lesson page task.

---

## Shapes shared by the exercise tasks

### Directory

| File                                       | Holds                                                                                                                          |
|--------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| `vulkan/exercise-N/README.md`              | Brief; "What's different from the lesson"; "The contract" (the signatures, and what each test pins); "Run"; the lesson link    |
| `vulkan/exercise-N/given.jai`              | Finished code from earlier lessons plus the helpers this exercise's tests and window need; never edited by the learner         |
| `vulkan/exercise-N/exercise.jai`           | The stubs: every contract procedure with its fixed signature, a `// TODO` naming the lesson step, a body returning zero values |
| `vulkan/exercise-N/cases.jai`              | The test cases, `CASES`, and `main :: () { exit(run_tests(CASES, get_command_line_arguments())); }`; no `#load` of its own     |
| `vulkan/exercise-N/tests.jai`              | `#load "given.jai"; #load "exercise.jai"; #load "cases.jai";` and nothing else                                                 |
| `vulkan/exercise-N/windowed.jai`           | `main :: ()` for the windowed program                                                                                          |
| `vulkan/exercise-N/main.jai`               | `#load "given.jai"; #load "exercise.jai"; #load "windowed.jai";`                                                               |
| `vulkan/exercise-N/shaders/`               | GLSL; stubs that compile when the learner writes them, finished sources when `given.jai` owns them                             |
| `solutions/vulkan/exercise-N/exercise.jai` | The reference solution, same signatures                                                                                        |
| `solutions/vulkan/exercise-N/tests.jai`    | `#load "../../../vulkan/exercise-N/given.jai"; #load "exercise.jai"; #load "../../../vulkan/exercise-N/cases.jai";`            |
| `solutions/vulkan/exercise-N/main.jai`     | `#load "../../../vulkan/exercise-N/given.jai"; #load "exercise.jai"; #load "../../../vulkan/exercise-N/windowed.jai";`         |
| `solutions/vulkan/exercise-N/shaders/`     | The solution's GLSL, only when the learner writes shaders (exercises 3 and project 1)                                          |

Stub bodies: `return .{}, false;`, `return 0;`, `return "";`, an empty body for a `void` procedure. Shader stubs: `#version 450` with `void main() { gl_Position = vec4(0.0); }` and `void main() { outColor = vec4(0.0); }` so `glslc` accepts them. `load_spirv` calls live in the file that owns the shader (`exercise.jai` when the learner writes it, `given.jai` otherwise), because `#filepath` is that file's directory.

### The cycle every exercise task follows

The task lists only what differs: the contract, the cases, what the window shows.

1. Write `README.md`, `given.jai`, the stubs, `cases.jai`, the assembly files, `windowed.jai`, shader stubs, and the solution's assembly files.
2. Run `~/jai/jai/bin/jai-linux first.jai - test vulkan/exercise-N`. Expected: the target builds; every case the task marks "stub FAILs" prints `FAIL`, the others `PASS`; the summary counts match; exit code 1. This is the learner's gate, watched RED.
3. Write `solutions/vulkan/exercise-N/exercise.jai` and the solution's shaders.
4. Run `~/jai/jai/bin/jai-linux first.jai - test solutions/vulkan/exercise-N`. Expected: `<cases> passed, 0 failed, <skips> skipped`, no warning counts on any PASS line.
5. Run `~/jai/jai/bin/jai-linux first.jai - run solutions/vulkan/exercise-N`. Expected: the window the task describes, for 300 frames or until closed, exit 0. A screenshot from workspace 1 is allowed. Then `first.jai - test-all`: every target `ok`.
6. Commit with the message the task gives.

### Lesson page tasks: the common steps

1. Copy `lessons/_template.html` to the page, fix the relative paths as `lessons/README.md` says, and write the page from the task's outline. Every page has one `<figure class="diagram">` holding an inline `<svg viewBox="…" role="img">` with a `<figcaption>`, styled by Task 3's rules.
2. Run `~/jai/jai/bin/jai-linux first.jai - check-lessons` before touching the index. Expected: exactly one finding, `index.html:0: lesson page not linked from index: lessons/vulkan/NN-<slug>.html`. Then link the page from its index row (the title becomes the link, the three marks become `done`) and run again. Expected: `N pages checked, 0 findings`.
3. Run `~/jai/jai/bin/jai-linux first.jai - concept-map`. Expected: the entry count grows by the page's sidebars; `check-lessons` stays clean.
4. In Brave over the chrome-devtools MCP, on the one `file://` tab this plan opens (never `resize_page`; `select_page` with `bringToFront` first): `emulate` viewport 1280×900, `colorScheme` light, screenshot; `emulate` 720×900, dark, screenshot; `evaluate_script` returning `document.documentElement.scrollWidth <= window.innerWidth` (Expected: `true`) and, after `document.querySelector('#s3 h2').scrollIntoView()` and one animation frame, `document.querySelector('.box.on').dataset.step` (Expected: `"s3"`). Clear the emulation.
5. Commit.

Snippets: `data-src` is the source path and the line where the copied text starts, verified with `sed -n '<line>p'`; wrap the line the step is about in `<mark>`; escape `<`, `>`, `&`. Illustrative snippets stay under six lines.

---

### Task 1: Deep-dive pages in the checker

**Files:**
- Modify: `tools/lesson-check/check.jai` (`check_all` dispatch, `check_index`, a `check_snippets` helper extracted from `check_lesson`), `tools/lesson-check/tests.jai`, `lessons/README.md` (a "Deep dives" section), `lessons/assets/lesson.css` (`.deep-dive` joins the `.page` selectors)
- Create: `tools/lesson-check/fixtures/lessons/vulkan/deep-dives/sample-dive.html`

**Interfaces:**
- Consumes: `check_lesson`, `check_links`, `collect`, `attr`, `inner`, `resolve_relative`, `lesson_pages`, `Finding` as they exist.
- Produces: `is_deep_dive :: (page_path: string) -> bool` (true when the path contains `/deep-dives/`); `check_deep_dive :: (html: string, page_path: string, root: string) -> [..] Finding`; `check_all` sends deep-dive pages to it instead of `check_lesson`; `check_index` never requires a deep-dive page to be linked. `collect_sidebars` is unchanged: it already skips every page that is not `lessons/<track>/NN-*.html`.

The deep-dive contract:

| Element                                                                               | Required                     | Message                                                                                         |
|---------------------------------------------------------------------------------------|------------------------------|-------------------------------------------------------------------------------------------------|
| `<article class="deep-dive page" data-track="…" data-lesson="N">`                     | exactly one; both attributes | `no <article class="deep-dive">` / `deep-dive lacks data-track` / `deep-dive lacks data-lesson` |
| `<p class="crumbs">` with an `<a>` whose href resolves to `lessons/<track>/NN-*.html` | present                      | `deep dive has no crumb link to its lesson`                                                     |
| `<h1>`                                                                                | one                          | `deep dive has no h1`                                                                           |
| snippets, sidebars, endnotes, sources, links and fragments                            | the lesson rules, unchanged  | the lesson messages                                                                             |

Not required: outcomes, steps, `.where`, `<noscript>`, the exercise link, the next link.

- [ ] **Step 1: Write the failing tests**

Add to `tests.jai` a `GOOD_DIVE` `#string` fixture: `<article class="deep-dive page" data-track="vulkan" data-lesson="0">`, a `p.crumbs` whose link has `href="../00-a.html"` (the page path passed is `lessons/vulkan/deep-dives/radv-draw.html`, so that resolves to `lessons/vulkan/00-a.html`, a fixture page that exists), one `<h1>`, one snippet `data-src="src/sample.jai:3"`, and a sources section with one `<li>`. Cases run `check_deep_dive` through the same mutate-and-expect loop as `CASES`:

```jai
DIVE_CASES :: Case.[
    .{"dive-good",                 "", "", .[]},
    .{"dive-no-article",           "<article class=\"deep-dive page\"", "<article class=\"page\"", .["no <article class=\"deep-dive\">"]},
    .{"dive-no-lesson",            " data-lesson=\"0\"", "", .["deep-dive lacks data-lesson"]},
    .{"dive-crumb-not-a-lesson",   "href=\"../00-a.html\"", "href=\"neighbour.html\"", .["deep dive has no crumb link to its lesson"]},
    .{"dive-snippet-missing-file", "src/sample.jai:3", "src/missing.jai:1", .["snippet 'src/missing.jai:1': no such file"]},
    .{"dive-no-sources",           "<section class=\"sources\">", "<section class=\"refs\">", .["no sources section"]},
];
```

Two more: `INDEX_CASES` gains `.{"index-ignores-deep-dives", "", "", .["lessons/vulkan/00-a.html", "lessons/vulkan/deep-dives/radv-draw.html"], .[]}`; and a sequential check `check_all_routes_deep_dives`: with `fixtures/lessons/vulkan/deep-dives/sample-dive.html` holding `GOOD_DIVE`'s text (crumb `../00-a.html`), `check_all(fixtures)` returns no finding whose `path` is that page.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `~/jai/jai/bin/jai-linux first.jai - test tools/lesson-check`
Expected: build failure, `check_deep_dive` undeclared. Add the two signatures with empty bodies and run again. Expected: `dive-good` and `index-ignores-deep-dives` PASS; the other dive cases FAIL with `0 findings, want 1`; `check_all_routes_deep_dives` FAILs because the dive page is held to the lesson contract (`no <article class="lesson">`); exit 1.

- [ ] **Step 3: Implement**

Extract the snippet rule of `check_lesson` into `check_snippets :: (html: string, page_path: string, root: string, findings: *[..] Finding)` and call it from both checkers. `check_deep_dive` applies the table above; the crumb rule resolves each `<a>` inside `p.crumbs` with `resolve_relative` and accepts one whose result has three segments, a track directory, and a file name beginning with two digits and a dash. `check_all`: `if is_deep_dive(it)  check_deep_dive(...) else check_lesson(...)`. `check_index`: `if is_deep_dive(page)  continue;` beside the template skip. CSS: `.page, .deep-dive { … }` for the existing `.page` block. `lessons/README.md`: a "Deep dives" section with the table above and the sentence that a deep dive lives at `lessons/<track>/deep-dives/<slug>.html`, is linked from its lesson's `p.deep-dive`, and is not listed on the index.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `~/jai/jai/bin/jai-linux first.jai - test tools/lesson-check`
Expected: `51 passed, 0 failed` (43 existing plus 6 dive cases, 1 index case, 1 routing check); then `first.jai - check-lessons` → `3 pages checked, 0 findings` (the fixture dive page lives under `tools/`, so the count does not change).

- [ ] **Step 5: Commit**

```bash
git add tools/lesson-check lessons/README.md lessons/assets/lesson.css
git commit -m "Checker: a light contract for deep-dive pages, exempt from the index rule"
```

### Task 2: `first.jai` solution targets and exercise 0 (the three layers)

**Files:**
- Modify: `first.jai` (`build_target`, `test_all`, `VERBS`), `README.md` (verb table row for `test-all`, layout rows for `solutions/` and `cases.jai`)
- Create: `vulkan/exercise-0/{README.md,given.jai,exercise.jai,cases.jai,tests.jai,windowed.jai,main.jai}`, `solutions/vulkan/exercise-0/{exercise.jai,tests.jai,main.jai}`

**Interfaces:**
- Consumes: `Gfx_Test`'s `run_tests`, `Test_Case`, `Gfx_Context` (unused by the pure cases, present because the runner creates one per case).
- Produces, in `first.jai`: `exercise_of :: (target: string) -> string` (`"solutions/vulkan/exercise-4"` → `"vulkan/exercise-4"`, else `""`); `build_target` compiles `exercise_of(target)`'s shaders when it is not empty, before the target's own; `test_all` scans `string.["vulkan", "directx", "metal", "tools", "solutions"]`.
- Produces, in `given.jai`:

```jai
Layer_Info  :: struct { name: string; spec_version: u32; implementation_version: u32; description: string; extensions: [] string; }   // extensions: vkEnumerateInstanceExtensionProperties(name)
Device_Info :: struct { name: string; device_type: VkPhysicalDeviceType; api_version: u32; driver_version: u32; vendor_id: u32; device_extension_count: int; }
Inventory   :: struct { instance_version: u32; layers: [] Layer_Info; base_extensions: [] string; devices: [] Device_Info; }   // base_extensions: the pLayerName == null query

collect_inventory :: () -> (inv: Inventory, ok: bool)   // vkEnumerateInstanceVersion, vkEnumerateInstanceLayerProperties, the extension query once with null and once per layer, then a throwaway instance with no layers and no extensions for vkEnumeratePhysicalDevices, vkGetPhysicalDeviceProperties and vkEnumerateDeviceExtensionProperties; destroyed before returning; log_error and false on any VkResult != .SUCCESS
print_inventory   :: (inv: Inventory)                   // the report below, through print
```

- Produces, in `exercise.jai` (the contract):

```jai
api_version_string    :: (v: u32) -> string                    // "1.4.354"; when VK_API_VERSION_VARIANT(v) != 0, "1.0.0 (variant 1)"
driver_version_string :: (vendor_id: u32, v: u32) -> string    // vendor 0x10DE: the four-field split "major.minor.patch.rest" from bits 31..22, 21..14, 13..6, 5..0; any other vendor: the Vulkan packing, "26.2.4"
extension_sources     :: (inv: Inventory, extension: string) -> [] string   // "base" first when base_extensions holds it, then every layer name whose extensions hold it, in inventory order; empty when nobody offers it
```

The report `print_inventory` writes, one block per query, each headed by who answered it (the lesson's three layers): `instance version <api_version_string>   answered by: the loader`; `layers (N)   answered by: the loader, from the manifests` with one line per layer (`name`, `spec`, `impl`, `description`) and an indented `offers:` line listing its extensions; `extensions (N)   answered by: the loader, the drivers and any enabled implicit layer, merged` with one line per base extension followed by `from: ` and `extension_sources` joined with `, `; `devices (N)   answered by: each driver (ICD), from the kernel` with one line per device (`name`, `device_type`, `api <api_version_string>`, `driver <driver_version_string>`, `vendor 0x…`, `device extensions N`).

- [ ] **Step 1: The build program**

Add `exercise_of`, the shader rule in `build_target`, and `solutions` to `test_all`; update the `test-all` row in `VERBS` and `README.md`, and add layout rows `solutions/vulkan/exercise-N/` ("reference solutions; `test solutions/vulkan/exercise-N` runs the exercise's cases against them") and a note that an exercise's cases live in `cases.jai`.

Run: `~/jai/jai/bin/jai-linux first.jai - test-all`
Expected: `2 targets, 0 failed` (nothing under `solutions/` yet; `test_all` already skips a root that does not exist).

- [ ] **Step 2: Write exercise 0's files and watch the stub fail**

Cases in `cases.jai`, each a `Test_Case` proc taking the unused context. `extension_sources_table` builds a synthetic `Inventory`: base extensions `VK_KHR_surface`, `VK_KHR_xlib_surface`, `VK_EXT_debug_utils`; layer `VK_LAYER_KHRONOS_validation` offering `VK_EXT_debug_utils`, `VK_EXT_validation_features`, `VK_EXT_layer_settings`; layer `VK_LAYER_FAKE_overlay` offering `VK_EXT_debug_utils`.

| Case                                      | Setup                                                                                                        | Asserts                                                                                                                                                                                                     | Stub  |
|-------------------------------------------|--------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------|
| `api_version_table`                       | `VK_MAKE_API_VERSION(0,1,4,354)`, `(0,1,3,0)`, `(1,1,0,0)`                                                   | `"1.4.354"`, `"1.3.0"`, `"1.0.0 (variant 1)"`                                                                                                                                                               | FAILs |
| `driver_version_table`                    | `(0x10DE, (580<<22) \| (95<<14) \| (5<<6))`, `(0x1002, VK_MAKE_API_VERSION(0,26,2,4))`, `(0x8086, the same)` | `"580.95.5.0"`, `"26.2.4"`, `"26.2.4"`                                                                                                                                                                      | FAILs |
| `extension_sources_table`                 | the synthetic inventory, queried four times                                                                  | `VK_EXT_debug_utils` → `[base, VK_LAYER_KHRONOS_validation, VK_LAYER_FAKE_overlay]`; `VK_EXT_validation_features` → `[VK_LAYER_KHRONOS_validation]`; `VK_KHR_surface` → `[base]`; `VK_KHR_nope` → `[]`      | FAILs |
| `live_inventory_has_the_validation_layer` | `collect_inventory()`                                                                                        | `ok`; `instance_version >= VK_API_VERSION_1_3`; a layer named `VK_LAYER_KHRONOS_validation`; `extension_sources(inv, "VK_EXT_validation_features")` holds that layer and not `"base"`; `devices.count >= 1` | FAILs |

`windowed.jai`: `main` calls `collect_inventory` and `print_inventory`, exits 1 when `ok` is false. README "What's different from the lesson": the lesson shows the five calls and one layer's extension list; the exercise owns the two version packings (`driverVersion` is the driver's to define: NVIDIA's split differs from the Vulkan packing Mesa uses) and the bookkeeping of who offers an extension.

Run: `~/jai/jai/bin/jai-linux first.jai - test vulkan/exercise-0`
Expected: builds; `0 passed, 4 failed, 0 skipped`; exit 1.

- [ ] **Step 3: Write the solution**

`solutions/vulkan/exercise-0/exercise.jai` plus the two assembly files.

- [ ] **Step 4: Run the solution's tests**

Run: `~/jai/jai/bin/jai-linux first.jai - test solutions/vulkan/exercise-0`
Expected: `4 passed, 0 failed, 0 skipped`.

- [ ] **Step 5: Run the windowed program and the whole suite**

Run: `~/jai/jai/bin/jai-linux first.jai - run solutions/vulkan/exercise-0`
Expected: the report, with `VK_LAYER_KHRONOS_validation` and `VK_LAYER_RENDERDOC_Capture` among the layers, `VK_EXT_validation_features` sourced only from the validation layer, and the RX 7900 GRE at `api 1.4.354`, `driver 26.2.4`. Then `first.jai - test-all` → `4 targets, 1 failed`, the failure being `vulkan/exercise-0: FAILED`.

> Ruling to carry: `test-all` reports every stub target as `FAILED`, because the stubs are the learner's unfinished work. That is right for the learner and noise for the laptop check. Task 13 gives `test-all` a `-solutions-only` form; until then every expected summary counts the stubs as failed.

- [ ] **Step 6: Commit**

```bash
git add first.jai README.md vulkan/exercise-0 solutions/vulkan/exercise-0
git commit -m "Exercise 0: enumerate layers, extensions and devices; solution targets in first.jai"
```

### Task 3: Lesson 0, "The three layers"

**Files:**
- Create: `lessons/vulkan/00-three-layers.html`
- Modify: `lessons/assets/lesson.css` (diagram rules), `lessons/README.md` ("Diagrams" section), `index.html` (row 0), `lessons/concept-map.html` (regenerated)

**Interfaces:**
- Consumes: `vulkan/exercise-0/given.jai` and `solutions/vulkan/exercise-0/exercise.jai` as snippet sources; `modules/Gfx_Test/device.jai`.
- Produces: the diagram convention every later page copies: `figure.diagram` with `svg { width: 100%; height: auto; max-width: 70ch; display: block; font: .78rem var(--font); }`, `text { fill: var(--fg); }`, bands `.band-cpu`, `.band-driver`, `.band-gpu` (`rect` filled with `color-mix(in srgb, var(--lane-color) 14%, transparent)` and stroked with `var(--lane-color)`, the lane color coming from a `data-lane` attribute on the `<g>`), `.token rect { fill: var(--bg); stroke: var(--line); }`, `figcaption { font-size: .85rem; color: var(--fg-2); }`. Documented in `lessons/README.md`.

Page outline. Exercise link and `p.next`: `../../vulkan/exercise-0/README.md`. Lead: what sits between a call in your program and the pixel. Outcomes: name the three layers and say which one answers each of the five enumeration calls; tell apart shader bytecode, a command buffer and the driver's command stream, and say which of them the GPU's firmware reads; say what a Vulkan layer is and where it sits in the chain.

| Step | `h2`                                                          | Boxes (cpu / driver / gpu)                                                                                                    | Snippet                                       |
|------|---------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------|
| `s1` | Your call lands in the loader                                 | `vkEnumerateInstanceLayerProperties` / `loader: read the manifests` / none                                                    | `given.jai`, the layer enumeration            |
| `s2` | Extensions: what the loader, the layers and the drivers offer | `vkEnumerateInstanceExtensionProperties` / `loader + layers: merge the lists` / none                                          | `given.jai`, the per-layer query              |
| `s3` | `vkCreateInstance` opens the drivers                          | `vkCreateInstance` / `loader: dlopen each ICD` → `ICD: negotiate the interface` / none                                        | `given.jai`, the throwaway instance           |
| `s4` | Physical devices: the driver asks the kernel                  | `vkEnumeratePhysicalDevices` / `ICD: open the render node` / `kernel: describe the hardware`                                  | `given.jai`, properties and device extensions |
| `s5` | Three things that are not one thing                           | `SPIR-V words in your process` / `ICD: compile (lesson 3), record (lesson 4)` / `command processor firmware reads the stream` | the diagram, no snippet                       |

Prose anchors: `s1` names `/usr/share/vulkan/explicit_layer.d` and that no driver is loaded yet; `s2` says the null-layer list is a merge the loader does not label, which is why exercise 0 asks per layer; `s3` names the ICD manifests under `/usr/share/vulkan/icd.d` and the dispatch chain (trampoline, layers, terminator, ICD); `s4` says the generic thing first (the ICD opens the kernel's render node and asks it to describe the device) and RADV inline as the example (`/dev/dri/renderD*`, `DRM_AMDGPU_INFO`); `s5` takes Jim's model apart: SPIR-V is compiled by the ICD into native instructions the shader cores run (not interpreted); the command buffer is driver-owned memory holding the driver's own packet stream, written while you record; the command processor's firmware does parse that stream, so the "firmware interprets it" half is right for packets and wrong for shaders. Lesson 0 also says what the three lanes mean from here on: cpu is your program and the bindings, driver is the loader, the layers and the ICD, gpu is the kernel driver and the hardware.

Diagram: three horizontal bands (cpu, driver, gpu) with the boxes `your Jai program` and `Vulkan bindings`; `libvulkan.so.1`, `VK_LAYER_KHRONOS_validation`, `libvulkan_radeon.so (ICD)`; `amdgpu (kernel)`, `command processor`, `shader cores`; and three tokens placed where they live: `SPIR-V` in the cpu band with an arrow into the ICD, `command buffer` in the driver band, `command stream` spanning driver and gpu.

Sidebars: `sb-layer` ("Validation layer": D3D12 `ID3D12Debug::EnableDebugLayer`, a runtime component rather than a library the loader interposes; Metal API validation, switched on in the Xcode scheme or with `MTL_DEBUG_LAYER=1`); `sb-loader` ("Loader": D3D12 `d3d12.dll` plus DXGI, which loads the user-mode driver DLL the adapter names; Metal the framework itself, the driver is a plug-in under IOKit); `sb-icd` ("ICD": D3D12 the user-mode driver per adapter, enumerated through `IDXGIFactory::EnumAdapters`; Metal `MTLCreateSystemDefaultDevice` and `MTLCopyAllDevices`, no manifests).

Endnotes: `VK_LOADER_DEBUG=all` (enables the loader's own trace; useful for seeing which manifests and drivers it touched; cost: a lot of stderr and no code change); `VK_DRIVER_FILES` (pins one ICD manifest; useful on the hybrid laptop; cost: a per-run environment variable and the other GPU vanishes); `VK_INSTANCE_LAYERS` (enables a layer without a code change; useful for trying RenderDoc's layer; cost: the environment variable and a layer the program did not ask for).

Sources (opened before citing): Vulkan-Loader `docs/LoaderInterfaceArchitecture.md` and `docs/LoaderLayerInterface.md` (github.com/KhronosGroup/Vulkan-Loader); the Vulkan specification's "Layers" and "Extensions" sections; Mesa `src/amd/vulkan/radv_physical_device.c`; Linux `Documentation/gpu/amdgpu/driver-core.rst` for the command processor firmware (PFP, ME, MEC) and `include/uapi/drm/amdgpu_drm.h` for `DRM_AMDGPU_INFO`; Vulkan-Tools `vulkaninfo` for the NVIDIA version split; `vulkan/exercise-0/given.jai`.

- [ ] **Step 1: CSS and guide**

Add the diagram rules to `lesson.css` and the "Diagrams" section to `lessons/README.md` (the figure shape, the `data-lane` bands, the token class, `viewBox` for scaling, no external images).

- [ ] **Step 2: Write the page**, then the common steps 2 to 5.

Expected after the index link: `4 pages checked, 0 findings`; `concept-map: lessons/concept-map.html (3 entries)`. Browser: open the tab with `new_page` on `file:///home/jim/projects/understaning-graphic-apis/lessons/vulkan/00-three-layers.html`; keep it for the later pages.

- [ ] **Step 3: Commit**

```bash
git add lessons/vulkan/00-three-layers.html lessons/assets/lesson.css lessons/README.md index.html lessons/concept-map.html
git commit -m "Lesson 0: the three layers, with the diagram convention"
```

### Task 4: Exercise 1 (instance, device, queues)

**Files:**
- Create: `vulkan/exercise-1/{README.md,given.jai,exercise.jai,cases.jai,tests.jai,windowed.jai,main.jai}`, `solutions/vulkan/exercise-1/{exercise.jai,tests.jai,main.jai}`

**Interfaces:**
- Produces, in `given.jai`:

```jai
Queue_Choice :: struct { graphics_family: u32; transfer_family: u32; }   // equal when the device has no transfer-only family
queue_family_properties :: (physical: VkPhysicalDevice) -> [] VkQueueFamilyProperties   // the two-call enumeration, heap allocated
```

- Produces, in `exercise.jai`:

```jai
choose_queue_families :: (families: [] VkQueueFamilyProperties) -> (choice: Queue_Choice, ok: bool)
    // graphics_family: the first family with GRAPHICS_BIT; ok is false when none has it
    // transfer_family: the first family with TRANSFER_BIT and neither GRAPHICS_BIT nor COMPUTE_BIT; the graphics family when there is none
create_device :: (physical: VkPhysicalDevice, choice: Queue_Choice) -> (device: VkDevice, graphics: VkQueue, transfer: VkQueue)
    // one VkDeviceQueueCreateInfo per distinct family, one queue each, priority 1.0;
    // VkPhysicalDeviceVulkan13Features with dynamicRendering and synchronization2 chained through VkPhysicalDeviceFeatures2 in pNext;
    // no device extensions; null device after a log_error when vkCreateDevice fails
```

Cases (a family is written as its flags and count):

| Case                                    | Families                                                          | Asserts                                                                                                                                                                        | Stub                                                              |
|-----------------------------------------|-------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------|
| `families_one_of_each`                  | `[G\|C\|T ×1, C\|T ×4, T ×2]`                                     | `ok`, graphics 0, transfer 2                                                                                                                                                   | FAILs                                                             |
| `families_single_family`                | `[G\|C\|T ×1]`                                                    | `ok`, graphics 0, transfer 0                                                                                                                                                   | FAILs                                                             |
| `families_transfer_before_compute`      | `[G\|C\|T ×16, T ×2, C\|T ×8]`                                    | graphics 0, transfer 1                                                                                                                                                         | FAILs                                                             |
| `families_compute_is_not_transfer_only` | `[G\|C\|T ×1, C\|T ×2]`                                           | `ok`, transfer 0 (a compute family is not a dedicated transfer engine)                                                                                                         | FAILs                                                             |
| `families_none_graphics`                | `[C\|T ×1, T ×1]`                                                 | `ok` is false                                                                                                                                                                  | PASSes on the stub, which returns false; it pins the failure path |
| `live_choice_matches_the_harness`       | `queue_family_properties(ctx.physical_device)`                    | `ok`; `graphics_family == ctx.queue_family`; the transfer family's flags include `TRANSFER_BIT`; when it differs from graphics its flags lack `GRAPHICS_BIT` and `COMPUTE_BIT` | FAILs                                                             |
| `live_device_creates_and_destroys`      | `create_device(ctx.physical_device, choice)` from the live choice | `device != null`; both queues non-null; `graphics == transfer` iff the families are equal; `vkDestroyDevice`; zero validation errors (the harness messenger is instance-wide)  | FAILs                                                             |

`windowed.jai`: prints `ctx.device_name`, every family's flags and count, the choice, creates and destroys the device through the contract. README "What's different": the lesson and the harness take the first graphics family and one queue; the exercise adds the dedicated transfer family, the two-family create info, and the features chain.

- [ ] **Steps 1 to 6: the common cycle.**

Step 2 Expected: builds; `1 passed, 6 failed` (`families_none_graphics` passes on the stub); exit 1. Step 4 Expected: `7 passed, 0 failed`. Step 5 Expected: the printout names one family on the desktop (`GRAPHICS | COMPUTE | TRANSFER | SPARSE_BINDING ×1`), choice `0 / 0`, `device created, destroyed`. Commit: `"Exercise 1: queue families and device creation"`.

### Task 5: Lesson 1, "Instance, device, queues"

**Files:**
- Create: `lessons/vulkan/01-instance-device-queues.html`
- Modify: `index.html` (row 1), `lessons/concept-map.html`

**Interfaces:**
- Consumes: `modules/Gfx_Test/device.jai` (instance creation, `choose_physical_device`), `solutions/vulkan/exercise-1/exercise.jai`, `vulkan/exercise-1/given.jai`.

Outcomes: trace one `vkCreateDevice` call from your code through the loader's trampoline, the validation layer and into the ICD; say what a queue family is, what a queue is in the ICD, and what it is in the kernel; choose families for graphics and transfer on a device you have never seen and defend the choice.

| Step | `h2`                                              | Boxes (cpu / driver / gpu)                                                                                          | Snippet                                             |
|------|---------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------|
| `s1` | The instance is the loader's object               | `vkCreateInstance` / `loader: trampoline → layer → terminator → ICD` / none                                         | `device.jai`, `VkInstanceCreateInfo` with the layer |
| `s2` | Choosing a physical device                        | `vkEnumeratePhysicalDevices` / `loader: ask every ICD` / none                                                       | `device.jai`, `choose_physical_device`              |
| `s3` | Queue families: what the hardware exposes         | `vkGetPhysicalDeviceQueueFamilyProperties` / `ICD: one family per kind of engine` / `rings: graphics, compute, DMA` | solution, `choose_queue_families`                   |
| `s4` | `vkCreateDevice`: the ICD opens a kernel context  | `vkCreateDevice` / `ICD: create the context` / `kernel: a context, a scheduler entity per queue`                    | solution, `create_device`                           |
| `s5` | A queue underneath: a scheduled channel to a ring | `vkGetDeviceQueue` / `ICD: queue object` / `kernel: drm_sched entity → ring`                                        | `given.jai`, `queue_family_properties`              |

Prose anchors: `s1` explains dispatchable handles (the first word of an instance or device handle points at a dispatch table the loader fills); `s2` says the desktop has one ICD and the laptop two, and that `choose_physical_device` prefers discrete; `s3` states the generic rule (a family is a set of queues with the same capabilities, backed by one kind of hardware engine), then RADV inline: graphics, compute and DMA engines, and that this desktop's RADV currently reports a single family carrying all three flags (one queue); `s4` the generic rule (a device is a kernel context plus per-queue scheduling state) with amdgpu's `DRM_AMDGPU_CTX` inline; `s5` that submission order is per queue and the kernel's scheduler arbitrates queues onto rings. Diagram: `VkQueue` → ICD queue → kernel scheduler entity → hardware ring, three rings drawn.

Sidebars: `sb-instance` ("Instance": D3D12 none, `IDXGIFactory` enumerates adapters and `D3D12CreateDevice` takes one; Metal none, the framework is always present); `sb-queue-family` ("Queue family": D3D12 `D3D12_COMMAND_LIST_TYPE` DIRECT, COMPUTE, COPY, chosen when the queue is created rather than enumerated; Metal one kind of `MTLCommandQueue`, the driver routes to engines itself); `sb-queue` ("Queue": D3D12 `ID3D12CommandQueue`; Metal `MTLCommandQueue` from `makeCommandQueue()`).

Endnotes: `MESA_VK_DEVICE_SELECT` (picks the GPU on a hybrid laptop without code; useful when the integrated GPU comes first; cost: an environment variable and the device-select layer); a second queue from a compute-only family (enables compute overlapping graphics; useful for async compute; cost: semaphores between queues and queue-family ownership transfers); `queueCount` greater than one from one family (enables submitting from several threads without a lock; useful once recording is parallel; cost: the family must report that many and ordering between queues is by sync objects only).

Sources: Vulkan-Loader `docs/LoaderInterfaceArchitecture.md` (dispatch tables, trampolines, terminators); Vulkan specification "Devices and Queues"; Mesa `src/amd/vulkan/radv_device.c`, `src/amd/vulkan/radv_queue.c`, `src/amd/vulkan/winsys/amdgpu/radv_amdgpu_winsys.c`; Linux `drivers/gpu/drm/amd/amdgpu/amdgpu_ctx.c`, `drivers/gpu/drm/scheduler/sched_main.c`, `Documentation/gpu/drm-mm.rst` (the scheduler section); `solutions/vulkan/exercise-1/exercise.jai`.

- [ ] **Steps 1 to 5: the common lesson steps.** Expected: `5 pages checked, 0 findings`; `concept-map … (6 entries)`. Commit: `"Lesson 1: instance, device, queues"`.

### Task 6: Exercise 2 (surface and swapchain under X11)

**Files:**
- Create: `vulkan/exercise-2/{README.md,given.jai,exercise.jai,cases.jai,tests.jai,windowed.jai,main.jai}`, `solutions/vulkan/exercise-2/{exercise.jai,tests.jai,main.jai}`

**Interfaces:**
- Consumes: `Gfx_Test`'s `create_target`, `transition_image`, `begin_commands`, `submit_and_wait`, `readback`, `expect_region_solid`, `expect_pixel`; `Window_Creation.create_window`, `X11.x_global_display`, `Input.update_window_events` and `events_this_frame`.
- Produces, in `given.jai` (carried forward verbatim by exercises 3, 4 and project 1):

```jai
Swapchain :: struct { handle: VkSwapchainKHR; format: VkFormat; extent: VkExtent2D; images: [] VkImage; views: [] VkImageView; }
Record_Proc :: #type (ctx: *Gfx_Context, image: VkImage, view: VkImageView, extent: VkExtent2D, frame: int, cbs: *[..] VkCommandBuffer);

create_surface    :: (ctx: *Gfx_Context, window: Window) -> (surface: VkSurfaceKHR, ok: bool)   // vkCreateXlibSurfaceKHR; false after log_error when ctx.queue_family cannot present to it
create_swapchain  :: (ctx: *Gfx_Context, surface: VkSurfaceKHR, window_w: u32, window_h: u32, vsync: bool) -> (sc: Swapchain, ok: bool)
    // capabilities, formats and present modes queried; the four choosers below decide; usage COLOR_ATTACHMENT_BIT, EXCLUSIVE, currentTransform, OPAQUE, clipped; images and views made
destroy_swapchain :: (ctx: *Gfx_Context, sc: *Swapchain)
present_loop      :: (ctx: *Gfx_Context, sc: *Swapchain, frames: int, record: Record_Proc)
    // per frame: wait and reset the frame fence; acquire with a semaphore; a first buffer transitions the image UNDEFINED → COLOR_ATTACHMENT_OPTIMAL;
    // record appends its finished buffers; a last buffer transitions COLOR_ATTACHMENT_OPTIMAL → PRESENT_SRC_KHR; one vkQueueSubmit2 of all of them
    // waiting on the acquire semaphore at COLOR_ATTACHMENT_OUTPUT and signalling a done semaphore; vkQueuePresentKHR waits on it;
    // stops after frames frames, on a QUIT event, or after log_error on ERROR_OUT_OF_DATE_KHR; frees every buffer after the fence; vkDeviceWaitIdle at the end
```

- Produces, in `exercise.jai`:

```jai
choose_surface_format :: (formats: [] VkSurfaceFormatKHR) -> VkSurfaceFormatKHR          // B8G8R8A8_SRGB with COLOR_SPACE_SRGB_NONLINEAR_KHR when offered, else formats[0]
choose_present_mode   :: (modes: [] VkPresentModeKHR, vsync: bool) -> VkPresentModeKHR    // vsync: FIFO_KHR; otherwise MAILBOX_KHR if offered, else IMMEDIATE_KHR if offered, else FIFO_KHR
choose_extent         :: (caps: VkSurfaceCapabilitiesKHR, window_w: u32, window_h: u32) -> VkExtent2D   // caps.currentExtent unless its width is 0xFFFFFFFF, then the window size clamped to [minImageExtent, maxImageExtent]
choose_image_count    :: (caps: VkSurfaceCapabilitiesKHR) -> u32                           // minImageCount + 1, clamped to maxImageCount when maxImageCount != 0
record_clear          :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, color: [4] float)
    // one dynamic-rendering instance over the whole extent whose only effect is loadOp CLEAR with color and storeOp STORE, on an image already in COLOR_ATTACHMENT_OPTIMAL
```

Cases:

| Case                                 | Setup                                                                                                                                                 | Asserts                                                                                                                                                     | Stub  |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|-------|
| `surface_format_prefers_bgra_srgb`   | `[R8G8B8A8_UNORM/SRGB_NONLINEAR, B8G8R8A8_SRGB/SRGB_NONLINEAR]`                                                                                       | the second                                                                                                                                                  | FAILs |
| `surface_format_falls_back_to_first` | `[R8G8B8A8_UNORM/SRGB_NONLINEAR, B8G8R8A8_UNORM/SRGB_NONLINEAR]`                                                                                      | the first                                                                                                                                                   | FAILs |
| `present_mode_table`                 | `(true, [IMMEDIATE, MAILBOX, FIFO])`, `(false, same)`, `(false, [IMMEDIATE, FIFO])`, `(false, [FIFO])`                                                | `FIFO`, `MAILBOX`, `IMMEDIATE`, `FIFO`                                                                                                                      | FAILs |
| `extent_uses_current_when_set`       | `currentExtent {800, 600}`, window `(1, 1)`                                                                                                           | `{800, 600}`                                                                                                                                                | FAILs |
| `extent_clamps_when_undefined`       | `currentExtent.width 0xFFFFFFFF`, min `{1, 1}`, max `{4096, 4096}`, window `(5000, 10)`                                                               | `{4096, 10}`                                                                                                                                                | FAILs |
| `image_count_table`                  | `(min 2, max 0)`, `(2, 3)`, `(3, 3)`, `(2, 8)`                                                                                                        | `3`, `3`, `3`, `3`                                                                                                                                          | FAILs |
| `clear_reads_back`                   | target 96×64; `transition_image` UNDEFINED → COLOR_ATTACHMENT_OPTIMAL; `record_clear(cb, t.view, .{96, 64}, .[0.8, 0.2, 0.4, 1.0])`; submit; readback | `expect_region_solid(p, 0, 0, 96, 64, 204, 51, 102, 255)`                                                                                                   | FAILs |
| `swapchain_from_real_surface`        | `needs_display`; `create_window(320, 200, "exercise-2")`, `create_surface`, `create_swapchain(vsync = true)`                                          | `ok`; `images.count >= caps.minImageCount`; `extent == {320, 200}`; `format == choose_surface_format(real formats).format`; destroy; zero validation errors | FAILs |

`windowed.jai`: 640×480 window, swapchain with vsync, `present_loop` for 300 frames whose record proc begins one buffer with `begin_commands`, calls `record_clear` with `.[0.1, 0.1, 0.3, 1.0]`, ends it and appends it. README "What's different": the lesson shows a 64×64 clear and one hard-coded swapchain; the exercise owns the four decisions a swapchain rests on (and their traps: `maxImageCount` zero, the undefined extent, FIFO always offered) and a clear of a given color on a 96×64 target.

- [ ] **Steps 1 to 6: the common cycle.**

Step 2 Expected: builds; `0 passed, 8 failed` (`swapchain_from_real_surface` FAILs under DISPLAY, SKIPs without). Step 4 Expected: `8 passed, 0 failed, 0 skipped` on the desktop. Step 5 Expected: a dark blue window for about five seconds. Commit: `"Exercise 2: surface, swapchain choices, and a clear"`.

### Task 7: Lesson 2, "Surface and swapchain under X11"

**Files:**
- Create: `lessons/vulkan/02-surface-swapchain.html`
- Modify: `index.html` (row 2), `lessons/concept-map.html`

Outcomes: say who owns a swapchain image at each moment and what acquire and present hand over; explain FIFO, MAILBOX and IMMEDIATE in terms of the vertical blank and the compositor; create a swapchain whose format, extent and image count come from the surface's capabilities rather than assumptions.

| Step | `h2`                                               | Boxes (cpu / driver / gpu)                                                                                                                                     | Snippet                                            |
|------|----------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------|
| `s1` | A surface is the loader's handle to a window       | `vkCreateXlibSurfaceKHR` / `loader: VkIcdSurfaceXlib` / none                                                                                                   | `given.jai`, `create_surface`                      |
| `s2` | Ask the surface what it can do                     | `vkGetPhysicalDeviceSurfaceCapabilitiesKHR` / `WSI: ask the X server (DRI3, Present)` / none                                                                   | solution, `choose_extent` and `choose_image_count` |
| `s3` | The swapchain: images the presentation engine owns | `vkCreateSwapchainKHR` / `WSI: allocate images, share them as DMA-BUFs` / `X server: pixmaps`                                                                  | `given.jai`, `create_swapchain`                    |
| `s4` | Acquire, clear, present: the ownership round trip  | `vkAcquireNextImageKHR` → `vkQueuePresentKHR` / `WSI: wait for a free image` → `WSI: PresentPixmap` / `GPU: clear` → `X server, compositor: scanout at vblank` | `given.jai`, the frame body of `present_loop`      |
| `s5` | Headless: the same clear without a window          | `record_clear` / none / `GPU: clear → readback`                                                                                                                | solution, `record_clear`                           |

Prose anchors: `s1` says the surface object is created by the loader, not the driver (the `VkIcdSurfaceXlib` struct in `vk_icd.h`), and carries the display and window id; `s2` names the three queries and the four choices with their traps; `s3` the generic rule (the presentation engine owns the images; you borrow one at a time) and Mesa's X11 WSI inline (images shared with the X server through DRI3 as pixmaps); `s4` the semaphores on both ends of the GPU work, present modes against the vertical blank, and that under a compositor the compositor, not the application, hits the screen; `s5` that the harness target stands in for a swapchain image and that the two layout transitions around the clear are barriers lesson 5 opens up. Diagram: the swapchain ring of three images with arrows `acquire` (engine → you) and `present` (you → engine), the X server and compositor box, and the vblank tick.

Sidebars: `sb-surface` ("Surface": D3D12 the `HWND` given to `CreateSwapChainForHwnd`; Metal a `CAMetalLayer` on an `NSView`); `sb-swapchain` ("Swapchain": D3D12 `IDXGISwapChain3` with `GetBuffer` and `Present`, flip model `DXGI_SWAP_EFFECT_FLIP_DISCARD`; Metal `CAMetalLayer.nextDrawable()`, three drawables by default); `sb-present-mode` ("Present mode": D3D12 `Present(syncInterval, flags)`, 1 is FIFO, 0 with `DXGI_PRESENT_ALLOW_TEARING` is immediate; Metal `CAMetalLayer.displaySyncEnabled` and `maximumDrawableCount`).

Endnotes: `VK_EXT_swapchain_maintenance1` (a fence per present; useful for recycling per-present semaphores; cost: the extension and a `VkSwapchainPresentFenceInfoEXT` per present); `VK_KHR_xcb_surface` (XCB instead of Xlib, which is what Mesa's WSI speaks underneath; useful when the window code is XCB; cost: a second surface path and `xcb_connection_t` plumbing); `imageUsage` with `TRANSFER_DST_BIT` (blit a rendered image into the swapchain instead of rendering into it; useful when the render format differs; cost: a blit and two more transitions per frame).

Sources: Vulkan specification "Window System Integration (WSI)" and `VkPresentModeKHR`; Vulkan-Loader `docs/LoaderDriverInterface.md` (surface objects) and the `VkIcdSurfaceXlib` struct in its `vk_icd.h` header, cited at the path the repository actually has; Mesa `src/vulkan/wsi/wsi_common_x11.c`; xorgproto `presentproto.txt` and `dri3proto.txt` (gitlab.freedesktop.org/xorg/proto/xorgproto); `vulkan/exercise-2/given.jai`.

- [ ] **Steps 1 to 5: the common lesson steps.** Expected: `6 pages checked, 0 findings`; `concept-map … (9 entries)`. Commit: `"Lesson 2: surface and swapchain under X11"`.

### Task 8: Exercise 3 (shaders and pipelines)

**Files:**
- Create: `vulkan/exercise-3/{README.md,given.jai,exercise.jai,cases.jai,tests.jai,windowed.jai,main.jai}`, `vulkan/exercise-3/shaders/{tri.vert,tri.frag}` (stubs), `solutions/vulkan/exercise-3/{exercise.jai,tests.jai,main.jai}`, `solutions/vulkan/exercise-3/shaders/{tri.vert,tri.frag}`

**Interfaces:**
- Consumes: exercise 2's solution `given.jai` and choosers (copied into this `given.jai` as finished code), `Gfx_Test.load_spirv`.
- Produces, in `given.jai`:

```jai
Pipeline :: struct { layout: VkPipelineLayout; handle: VkPipeline; }
destroy_pipeline :: (ctx: *Gfx_Context, p: *Pipeline)
draw_to_target   :: (ctx: *Gfx_Context, t: *Gfx_Target, p: Pipeline, viewport: VkViewport) -> Pixels
    // transition UNDEFINED → COLOR_ATTACHMENT_OPTIMAL, begin_commands, record_triangle with clear black, submit_and_wait, readback
```

- Produces, in `exercise.jai`:

```jai
TRI_VERT :: #run load_spirv(tprint("%.build/spv/tri.vert.spv", #filepath));
TRI_FRAG :: #run load_spirv(tprint("%.build/spv/tri.frag.spv", #filepath));

create_pipeline :: (ctx: *Gfx_Context, color_format: VkFormat, front_face: VkFrontFace, cull: VkCullModeFlags) -> (p: Pipeline, ok: bool)
    // two stages from modules made from TRI_VERT and TRI_FRAG and destroyed after creation; no vertex input; TRIANGLE_LIST; dynamic VIEWPORT and SCISSOR, one each;
    // polygon FILL, cull and front_face as given, lineWidth 1; one sample; one color attachment with blending off and write mask RGBA; an empty layout;
    // VkPipelineRenderingCreateInfo naming color_format in pNext; renderPass null; false after log_error on failure
record_triangle :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, p: Pipeline, viewport: VkViewport, clear: [4] float)
    // begin rendering over extent with loadOp CLEAR (clear) and storeOp STORE; bind p; set viewport; scissor = the whole extent; vkCmdDraw(cb, 3, 1, 0, 0); end rendering
```

Shaders the learner writes: `tri.vert` puts the corners `(-0.8, 0.8)`, `(0.8, 0.8)`, `(0.0, -0.8)` in a `const vec2[3]` indexed by `gl_VertexIndex`, in an order that is front-facing under `VK_FRONT_FACE_COUNTER_CLOCKWISE` by the specification's rule (signed area in framebuffer coordinates, where y points down); `tri.frag` writes solid `vec4(0.0, 1.0, 0.0, 1.0)`.

Cases, target 128×128, clear black; the full viewport is `{0, 0, 128, 128, 0, 1}`:

| Case                                           | Pipeline        | Viewport                 | Asserts                                                                                                    | Stub                                       |
|------------------------------------------------|-----------------|--------------------------|------------------------------------------------------------------------------------------------------------|--------------------------------------------|
| `triangle_shows_with_ccw_and_back_cull`        | CCW, `BACK_BIT` | full                     | `(64, 64)` and `(64, 100)` are `(0, 255, 0, 255)`; `(5, 5)`, `(10, 60)`, `(120, 120)` are `(0, 0, 0, 255)` | FAILs                                      |
| `triangle_culled_when_front_face_is_clockwise` | CW, `BACK_BIT`  | full                     | `expect_region_solid(p, 0, 0, 128, 128, 0, 0, 0, 255)`                                                     | FAILs (stub create_pipeline returns false) |
| `triangle_shows_when_cull_is_none`             | CW, `NONE`      | full                     | `(64, 64)` green                                                                                           | FAILs                                      |
| `viewport_moves_the_triangle`                  | CCW, `BACK_BIT` | `{64, 0, 64, 128, 0, 1}` | `expect_region_solid(p, 0, 0, 64, 128, 0, 0, 0, 255)`; `(96, 64)` and `(96, 100)` green                    | FAILs                                      |

Each case destroys its pipeline; zero validation errors throughout. `windowed.jai`: window, swapchain, `create_pipeline(sc.format, COUNTER_CLOCKWISE, BACK_BIT)`, `present_loop` whose record proc begins one buffer, calls `record_triangle` with the full viewport and a dark clear, ends and appends it. README "What's different": the lesson shows one pipeline (CCW, back-face culling) and one full-size viewport; the exercise makes the winding and the cull mode parameters and asks for the half-width viewport, so that the pipeline's baked state and the dynamic state are seen to be different things, and the corners must be ordered by Vulkan's rule, not OpenGL's.

- [ ] **Steps 1 to 6: the common cycle.**

Step 2 Expected: `shaders: tri.vert -> …` lines, the build succeeds, `0 passed, 4 failed`. Step 4 Expected: `4 passed, 0 failed`. Step 5 Expected: a green triangle pointing up on a dark window; also run the solution binary once with `RADV_DEBUG=shaders` and keep the vertex shader's disassembly block for lesson 3's figure (if the variable prints nothing on this Mesa, record that and use `VK_KHR_pipeline_executable_properties` in a scratch probe instead; the lesson's figure says which). Commit: `"Exercise 3: a triangle, the pipeline, winding and dynamic viewport"`.

### Task 9: Lesson 3, "Shaders and pipelines"

**Files:**
- Create: `lessons/vulkan/03-shaders-pipelines.html`
- Modify: `index.html` (row 3), `lessons/concept-map.html`

Outcomes: say what `glslc` produces, what `vkCreateShaderModule` does with it (a copy), and when the driver compiles it to GPU instructions; list what a graphics pipeline bakes, why changing any of it means another pipeline, and which pieces dynamic state leaves out; get a triangle's winding right in Vulkan's y-down clip space with back-face culling on.

| Step | `h2`                                                    | Boxes (cpu / driver / gpu)                                                                                | Snippet                                                                                                                                                            |
|------|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `s1` | GLSL to SPIR-V on your machine, before the program runs | `glslc: GLSL → SPIR-V (build time)` → `SPIR-V words in the binary` / none / none                          | `solutions/vulkan/exercise-3/shaders/tri.vert:1`; `first.jai`, `compile_shaders`; `module.jai`, `load_spirv`                                                       |
| `s2` | `vkCreateShaderModule` copies words                     | `vkCreateShaderModule` / `ICD: keep the words` / none                                                     | solution, the module creation inside `create_pipeline`                                                                                                             |
| `s3` | `vkCreateGraphicsPipelines`: the driver compiles        | `vkCreateGraphicsPipelines` / `ICD: SPIR-V → NIR → ACO → ISA` / `ISA and state words sit in VRAM`         | solution, `VkGraphicsPipelineCreateInfo` with `VkPipelineRenderingCreateInfo`; a `<pre class="output">` figure with the real vertex shader disassembly from Task 8 |
| `s4` | Dynamic state: set per command buffer, not baked        | `vkCmdSetViewport, vkCmdSetScissor` / `ICD: registers written at draw` / none                             | solution, `record_triangle`                                                                                                                                        |
| `s5` | The draw and the winding                                | `vkCmdDraw` / `ICD: a draw packet into the command stream` / `CP → shader cores run the ISA → rasterizer` | solution, the `vkCmdDraw` line; `cases.jai`, `triangle_culled_when_front_face_is_clockwise`                                                                        |

Prose anchors: `s1` the magic number `0x07230203` and that SPIR-V is a word stream with no GPU in it; `s2` that on RADV the module holds the words and nothing is compiled, which is why the call is cheap; `s3` the generic statement (the driver compiles at pipeline creation, so the pipeline holds machine code plus register values for every fixed-function stage you named) with RADV's compilers inline (NIR, then ACO), and the figure showing instructions such as `s_endpgm` to make "native" concrete; `s4` which state is dynamic here and why one pipeline then serves any target size; `s5` the front-facing rule quoted from the specification, the y-down diagram, and that `gl_VertexIndex` is what indexes the constant array. Diagram: clip space with y pointing down, the three corners labelled in draw order, the signed-area arrow, and the viewport rectangle.

Sidebars: `sb-shader-module` ("Shader module": D3D12 DXIL from `dxc`, `D3D12_SHADER_BYTECODE` straight into the PSO description, no module object; Metal MSL compiled by Xcode into a `.metallib` or at run time by `makeLibrary(source:)`, then `MTLFunction`); `sb-pipeline` ("Graphics pipeline": D3D12 `ID3D12PipelineState` from `D3D12_GRAPHICS_PIPELINE_STATE_DESC`, the same bake at the same moment; Metal `MTLRenderPipelineState`, with depth-stencil and viewport set on the encoder instead); `sb-dynamic-state` ("Dynamic state": D3D12 `RSSetViewports` and `RSSetScissorRects` on the command list, always dynamic; Metal `setViewport` on the render command encoder).

Endnotes: `VkPipelineCache` saved to a file (skips the compile on later runs; useful once there are dozens of pipelines; cost: saving and loading the blob and checking its header); `VK_EXT_extended_dynamic_state` and the Vulkan 1.3 dynamic states (cull mode, front face and topology per draw; useful when one pipeline must serve both windings; cost: more `vkCmdSet*` calls before every draw); `VK_KHR_pipeline_executable_properties` (reads the ISA and statistics back through the API; useful for seeing what the driver made without an environment variable; cost: enabling the feature and `CAPTURE_INTERNAL_REPRESENTATIONS_BIT_KHR` on the pipeline).

Deep dive: `deep-dives/README.md`, which names "What RADV emits for `vkCmdDraw`".

Sources: Vulkan specification "Shader Modules", "Graphics Pipelines", "Basic Polygon Rasterization" (the front-facing rule); SPIR-V specification "Magic Number" and "Physical Layout of a SPIR-V Module"; Mesa `src/amd/vulkan/radv_pipeline_graphics.c`, `src/amd/compiler/README.md`, `docs/envvars.rst` (`RADV_DEBUG=shaders`); shaderc's `glslc` README; `solutions/vulkan/exercise-3/exercise.jai`.

- [ ] **Steps 1 to 5: the common lesson steps.** Expected: `7 pages checked, 0 findings`; `concept-map … (12 entries)`. Commit: `"Lesson 3: shaders and pipelines"`.

### Task 10: Exercise 4 (command buffers and submission)

**Files:**
- Create: `vulkan/exercise-4/{README.md,given.jai,exercise.jai,cases.jai,tests.jai,windowed.jai,main.jai}`, `vulkan/exercise-4/shaders/{table.vert,table.frag}` (finished, owned by `given.jai`), `solutions/vulkan/exercise-4/{exercise.jai,tests.jai,main.jai}`

**Interfaces:**
- Consumes: exercise 3's solution `create_pipeline` (copied into `given.jai` as `create_table_pipeline`, cull `NONE`), exercise 2's `present_loop`.
- Produces, in `given.jai`:

```jai
TABLE_VERT :: #run load_spirv(tprint("%.build/spv/table.vert.spv", #filepath));   // vulkan/exercise-4/.build/spv, hence first.jai's shader rule for the solution target
TABLE_FRAG :: #run load_spirv(tprint("%.build/spv/table.frag.spv", #filepath));
create_table_pipeline :: (ctx: *Gfx_Context, color_format: VkFormat) -> (p: Pipeline, ok: bool)
prepare_target     :: (cb: VkCommandBuffer, image: VkImage)   // UNDEFINED → COLOR_ATTACHMENT_OPTIMAL; "a barrier; lesson 5"
attachment_barrier :: (cb: VkCommandBuffer, image: VkImage)   // COLOR_ATTACHMENT_OPTIMAL → same, COLOR_ATTACHMENT_OUTPUT write → COLOR_ATTACHMENT_OUTPUT write|read: orders two render instances on one image
```

`table.vert` holds four triangles, twelve `vec2` corners and four colors, indexed by `gl_VertexIndex / 3` and `gl_VertexIndex % 3`, so `vkCmdDraw(cb, 3, 1, 3 * k, 0)` draws triangle `k`. All four cover clip-space `(0, 0)`; each also covers one point no other does:

| k   | Color              | Corners                                   | Point only it covers | Pixel on 128×128 |
|-----|--------------------|-------------------------------------------|----------------------|------------------|
| 0   | red `(1, 0, 0)`    | `(-0.9, -0.9)`, `(0.9, -0.9)`, `(0, 0.3)` | `(0, -0.8)`          | `(64, 12)`       |
| 1   | green `(0, 1, 0)`  | `(0.9, -0.9)`, `(0.9, 0.9)`, `(-0.3, 0)`  | `(0.8, 0)`           | `(115, 64)`      |
| 2   | blue `(0, 0, 1)`   | `(0.9, 0.9)`, `(-0.9, 0.9)`, `(0, -0.3)`  | `(0, 0.8)`           | `(64, 115)`      |
| 3   | yellow `(1, 1, 0)` | `(-0.9, 0.9)`, `(-0.9, -0.9)`, `(0.3, 0)` | `(-0.8, 0)`          | `(12, 64)`       |

- Produces, in `exercise.jai`:

```jai
begin_buffer   :: (ctx: *Gfx_Context) -> VkCommandBuffer
    // allocate one PRIMARY buffer from ctx.command_pool and begin it with ONE_TIME_SUBMIT_BIT
record_scene   :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, p: Pipeline, draws: [] int, clear: bool)
    // begin rendering over extent with loadOp CLEAR to black when clear, LOAD otherwise, storeOp STORE; bind p; full viewport and scissor;
    // one vkCmdDraw(cb, 3, 1, 3 * draws[i], 0) per entry in order; end rendering; vkEndCommandBuffer
submit_ordered :: (ctx: *Gfx_Context, cbs: [] VkCommandBuffer)
    // one vkQueueSubmit2 carrying every buffer in order through VkCommandBufferSubmitInfo entries, with a fence; vkWaitForFences; destroy the fence; free the buffers
```

Cases, target 128×128 (`t`), pipeline from `create_table_pipeline`; the test puts the barriers around the learner's buffers: `prepare_target` is recorded into a clearing buffer right after `begin_buffer`, `attachment_barrier` into a loading one:

| Case                                   | Buffers                                                                         | Submission       | Asserts                                                                                                   | Stub  |
|----------------------------------------|---------------------------------------------------------------------------------|------------------|-----------------------------------------------------------------------------------------------------------|-------|
| `draw_order_within_one_buffer`         | `a`: prepare, `[0, 1, 2, 3]`, clear                                             | `[a]`            | `(64, 64)` yellow; `(64, 12)` red; `(115, 64)` green; `(64, 115)` blue; `(12, 64)` yellow; `(2, 2)` black | FAILs |
| `second_buffer_draws_over_the_first`   | `a`: prepare, `[0, 1]`, clear; `b`: barrier, `[2]`, load                        | `[a, b]`         | `(64, 64)` blue; `(64, 12)` red; `(115, 64)` green                                                        | FAILs |
| `submission_order_not_recording_order` | `b` recorded first: barrier, `[3]`, load; then `a`: prepare, `[0, 1, 2]`, clear | `[a, b]`         | `(64, 64)` yellow (recording order would have given blue)                                                 | FAILs |
| `two_submits_in_sequence`              | `a`: prepare, `[0]`, clear; `b`: barrier, `[1]`, load                           | `[a]` then `[b]` | `(64, 64)` green; `(64, 12)` red                                                                          | FAILs |
| `empty_draw_list_only_clears`          | `a`: prepare, `[]`, clear                                                       | `[a]`            | `expect_region_solid(p, 0, 0, 128, 128, 0, 0, 0, 255)`                                                    | FAILs |

`windowed.jai`: window, swapchain, the table pipeline; the record proc appends two buffers per frame: `[0, 1, 2, 3]` clearing, then `[(frame / 60) % 4]` loading after `attachment_barrier`, so the triangle on top changes every second. README "What's different": the harness records one buffer and frees it; the exercise owns allocation, begin, the draw list, end, a multi-buffer submit, and the fence, and the tests read the submission order off the pixels.

- [ ] **Steps 1 to 6: the common cycle.**

Step 2 Expected: builds; `0 passed, 5 failed`. Step 4: first `rm -rf vulkan/exercise-4/.build solutions/vulkan/exercise-4/.build`, then `test solutions/vulkan/exercise-4`. Expected: `shaders: table.vert -> …/vulkan/exercise-4/.build/spv/table.vert.spv` printed by the shader rule, then `5 passed, 0 failed`. Step 5 Expected: four overlapping triangles whose top one cycles red, green, blue, yellow once a second. Commit: `"Exercise 4: command buffers, draw order and ordered submission"`.

### Task 11: Lesson 4, "Command buffers and submission", and the template's submit prose

**Files:**
- Create: `lessons/vulkan/04-command-buffers.html`
- Modify: `lessons/_template.html` (step 4 prose and the driver lane's `translate` box), `index.html` (row 4), `lessons/concept-map.html`

Outcomes: say what memory a `vkCmd*` call writes, who owns it, and in what format; say exactly what `vkQueueSubmit2` does and does not do; predict which draw wins at an overlapping pixel from the submission order across two command buffers.

| Step | `h2`                                                     | Boxes (cpu / driver / gpu)                                                                                                                                                     | Snippet                                                  |
|------|----------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------|
| `s1` | The pool, the buffer, and what begin does                | `vkAllocateCommandBuffers, vkBeginCommandBuffer` / `ICD: a packet buffer in GPU-visible memory` / none                                                                         | `device.jai`, the command pool; solution, `begin_buffer` |
| `s2` | Recording: your calls become the hardware's packets, now | `vkCmdBeginRendering, vkCmdDraw` / `ICD: append draw packets` / none                                                                                                           | solution, `record_scene`                                 |
| `s3` | `vkEndCommandBuffer`: the stream is complete             | `vkEndCommandBuffer` / `ICD: pad and close the buffer` / none                                                                                                                  | solution, the end line of `record_scene`                 |
| `s4` | Submit: an ioctl, not a translation                      | `vkQueueSubmit2` → `vkWaitForFences` / `ICD: build the submission` → `kernel: DRM_AMDGPU_CS → scheduler` / `ring → CP fetches your packets` → `shader cores` → `fence signals` | solution, `submit_ordered`                               |
| `s5` | Order: within a buffer, across buffers, across submits   | `submit [a, b]` / none / `a's draws, then b's`                                                                                                                                 | `cases.jai`, `second_buffer_draws_over_the_first`        |

Prose anchors: `s1` generic first (the driver allocates memory the GPU can read and the CPU can write, and `begin` resets it), RADV inline (`radeon_cmdbuf` in GTT); `s2` generic (recording appends the driver's own representation of each command) then RADV inline: PM4 packets, `PKT3_DRAW_INDEX_AUTO` for a draw, the same bytes the command processor will read, so this is Jim's "bytecode" being written by the CPU inside the driver; `s3` that end is where the driver finalizes and validation checks state; `s4` the correction that matters: submit builds an ioctl naming the buffers, the memory they reference and the sync objects; the kernel's scheduler queues a job; the command processor fetches the packets from your buffer through an indirect-buffer packet in the ring; nothing is translated here; the fence is the kernel's signal back; `s5` the specification's rules (rasterization order within a render instance, submission order within a queue) and that visibility of writes between two render instances on one image still needs the barrier `given.jai` supplies, which lesson 5 opens. Diagram: CPU memory holding the command buffer, the ioctl arrow into the kernel's ring buffer whose `INDIRECT_BUFFER` packet points back at the command buffer, the command processor, the shader cores, and the fence arrow back to the CPU.

Sidebars: `sb-command-buffer` ("Command buffer": D3D12 `ID3D12GraphicsCommandList` recording into an `ID3D12CommandAllocator`, `Close()` ends it; Metal `MTLCommandBuffer` with encoders, `endEncoding()`); `sb-submit` ("Queue submit": D3D12 `ExecuteCommandLists` with `Signal` on the queue as the fence; Metal `commit()`, completion through `waitUntilCompleted` or `addCompletedHandler`); `sb-submission-order` ("Submission order": D3D12 lists in one `ExecuteCommandLists` call run in order, as do successive calls on one queue; Metal buffers on one queue run in `commit` order, `enqueue()` reserves a slot early).

Endnotes: secondary command buffers with `vkCmdExecuteCommands` (record in parallel and reuse; useful for static scenery; cost: `SECONDARY` level and inheritance info); `vkResetCommandPool` with a pool per frame (recycles every buffer at once; useful once there are many per frame; cost: one pool per frame in flight); `SIMULTANEOUS_USE_BIT` (submit one buffer while it is still pending; useful for a buffer re-submitted every frame; cost: the driver may copy or patch, and the lesson 5 fences still apply).

Template fix: step 4's prose becomes "Submit hands the recorded commands, already in the driver's own format, to the kernel driver, which schedules them on the GPU's queue", and the driver lane's `translate` box becomes `build the submission`.

Sources: Vulkan specification "Command Buffers", "Queue Operation" (submission order), "Rasterization Order"; Mesa `src/amd/vulkan/radv_cmd_buffer.c`, `src/amd/vulkan/radv_queue.c`, `src/amd/vulkan/winsys/amdgpu/radv_amdgpu_cs.c`, `src/amd/common/sid.h` (packet opcodes); Linux `drivers/gpu/drm/amd/amdgpu/amdgpu_cs.c`, `include/uapi/drm/amdgpu_drm.h` (`DRM_AMDGPU_CS`), `Documentation/gpu/amdgpu/driver-core.rst`; `solutions/vulkan/exercise-4/exercise.jai`.

- [ ] **Steps 1 to 5: the common lesson steps**, with the template edit in step 1. Expected: `8 pages checked, 0 findings`; `concept-map … (15 entries)`. Commit: `"Lesson 4: command buffers and submission; the template says what submit does"`.

### Task 12: Project 1

**Files:**
- Create: `vulkan/project-1/{README.md,RUBRIC.md,given.jai,project.jai,cases.jai,tests.jai,windowed.jai,main.jai}`, `vulkan/project-1/shaders/{shapes.vert,shapes.frag}` (stubs with comments)

**Interfaces:**
- Consumes: exercise 2's `present_loop`, exercise 3's pipeline creation, exercise 4's barriers and ordered submit, all copied into `given.jai` as finished code.
- Produces, in `given.jai`:

```jai
create_shape_pipeline :: (ctx: *Gfx_Context, color_format: VkFormat, vert: [] u32, frag: [] u32) -> (p: Pipeline, ok: bool)   // cull NONE, dynamic viewport and scissor, otherwise exercise 3's pipeline
prepare_target        :: (cb: VkCommandBuffer, image: VkImage)
attachment_barrier    :: (cb: VkCommandBuffer, image: VkImage)
submit_and_wait_all   :: (ctx: *Gfx_Context, cbs: [] VkCommandBuffer)   // exercise 4's submit without the free: the project owns its buffers' lifetimes
distinct_colors       :: (p: Pixels) -> int                              // distinct RGBA values, counting stops at 64
pixels_differ         :: (a: Pixels, b: Pixels) -> bool
```

- Produces, in `project.jai` (stubs and comments; the learner fills them):

```jai
SHAPES_VERT :: #run load_spirv(tprint("%.build/spv/shapes.vert.spv", #filepath));
SHAPES_FRAG :: #run load_spirv(tprint("%.build/spv/shapes.frag.spv", #filepath));

Scene :: struct { pipeline: Pipeline; static_cb: VkCommandBuffer; dynamic_cb: VkCommandBuffer; /* the learner adds what else it needs */ }
scene_init    :: (ctx: *Gfx_Context, color_format: VkFormat) -> (scene: Scene, ok: bool)
scene_record  :: (ctx: *Gfx_Context, scene: *Scene, image: VkImage, view: VkImageView, extent: VkExtent2D, frame: int, cbs: *[..] VkCommandBuffer)
    // appends at least two finished buffers: the static one, recorded once in scene_init or on first use, and the per-frame one, re-recorded for this frame
scene_destroy :: (ctx: *Gfx_Context, scene: *Scene)
```

README (the contract): at least six distinct shapes (different sizes, positions and colors; at least two triangles and at least two quads) drawn from at least two command buffers: a static buffer recorded once and re-submitted every frame, and a per-frame buffer re-recorded each frame with at least one shape that moves. At least three overlaps; every per-frame shape lies over every static shape it overlaps, and within each buffer later draws cover earlier ones in the order the README's "Layout" section declares (the learner writes that list). The first buffer clears; the second loads. The windowed program runs at the swapchain's size, not a hard-coded one. "What to look up": `gl_VertexIndex` and `firstVertex` for a table of shapes and colors without vertex buffers; `vkCmdSetViewport` and `vkCmdSetScissor` for placement and clipping; `loadOp`; `vkResetCommandBuffer` with the pool's reset flag; what `SIMULTANEOUS_USE_BIT` means, and why `present_loop`'s one-frame-in-flight fence makes it unnecessary here. Grading: `first.jai - capture vulkan/project-1` writes `build/vulkan-project-1.png`, frame 30; Claude judges it against `RUBRIC.md`.

`RUBRIC.md`: must-haves, each judged from the capture (at least six shapes visible; at least two triangles and two quads; at least three overlaps; at every overlap the color on top matches the declared layout; the moving shape sits over the static ones; nothing clipped unintentionally; the tests pass, which covers zero validation errors) and the windowed run (fills the window at its size). Stretch: a scissor-clipped shape; a second moving shape at a different speed; a comment in `project.jai` explaining why the static buffer is safe to re-submit.

Cases (`cases.jai`), target 256×256; each transitions the target with `prepare_target` in a `begin_commands` buffer submitted by `submit_and_wait` first:

| Case                         | Setup                                                                                 | Asserts                                                 | Stub  |
|------------------------------|---------------------------------------------------------------------------------------|---------------------------------------------------------|-------|
| `renders_a_frame_headlessly` | `scene_init`; `scene_record(frame 0)`; `submit_and_wait_all`; readback                | `ok`; `distinct_colors(p) >= 6`; zero validation errors | FAILs |
| `two_buffers_per_frame`      | as above                                                                              | `cbs.count >= 2`                                        | FAILs |
| `frames_differ`              | readback at frame 0, then `attachment_barrier` and `scene_record(frame 30)`, readback | `pixels_differ`                                         | FAILs |

`windowed.jai`: window, swapchain, `scene_init(sc.format)`, `present_loop` for 600 frames with `scene_record` as the record proc, `scene_destroy`. No reference solution: a project is graded, not solved; the floor is proven by the executor's own throwaway fill of the stubs in a scratch copy, never committed.

- [ ] **Step 1: Write the project files.**

- [ ] **Step 2: Watch the stubs fail**

Run: `~/jai/jai/bin/jai-linux first.jai - test vulkan/project-1`
Expected: builds; `0 passed, 3 failed`; exit 1.

- [ ] **Step 3: Prove the floor is passable**

Copy `vulkan/project-1/` to `vulkan/project-1-scratch/` (a target must live under the repo root), fill its `project.jai` and shaders minimally (six shapes, one moving, two buffers), run `first.jai - test vulkan/project-1-scratch` and `first.jai - capture vulkan/project-1-scratch`, read the PNG, then delete the directory before committing.
Expected: `3 passed, 0 failed`; the PNG shows shapes; `git status` shows nothing from the scratch copy.

- [ ] **Step 4: Index row and commit**

Row `p1`: brief links `vulkan/project-1/README.md`, rubric links `vulkan/project-1/RUBRIC.md`, both `done`; tests `done`.

```bash
git add vulkan/project-1 index.html
git commit -m "Project 1: several shapes from more than one command buffer, with its rubric"
```

### Task 13: Wrap-up: next-lesson links, `test-all` for the laptop, READMEs, final checks

**Files:**
- Modify: `lessons/vulkan/0{0,1,2,3}-*.html` (`p.next` gains "then lesson N+1"), `lessons/vulkan/04-command-buffers.html` (`p.next` gains "then project 1"), `first.jai` (`test-all` takes `-solutions-only`), `README.md`, `lessons/README.md`, `index.html` (Vulkan rows' marks are consistent; `howto` mentions `test solutions/…`), `docs/superpowers/specs/…` (open item: laptop verification now includes the solution targets)

**Interfaces:**
- Produces: `test-all -solutions-only` skips every `<api>/<name>` target for which `solutions/<api>/<name>/tests.jai` exists, and every `<api>/project-*` target, so the laptop check reports only targets expected to pass.

- [ ] **Step 1: `test-all -solutions-only`**

Add the flag to `test_all :: (solutions_only: bool)`, the `VERBS` row and the README row.
Run: `~/jai/jai/bin/jai-linux first.jai - test-all -solutions-only`
Expected: `7 targets, 0 failed` (`tools/lesson-check`, `vulkan/harness-check`, the five solutions). Then plain `test-all`: `13 targets, 6 failed`, the failures being the five stub exercises and `vulkan/project-1`.

- [ ] **Step 2: Next links and docs**

Append the "then" links; `check-lessons` → `8 pages checked, 0 findings`. Root README: the solutions row, the `-solutions-only` row. `lessons/README.md`: nothing new unless a convention changed during the tasks.

- [ ] **Step 3: Final page pass**

On the test tab, for each of the five pages: 1280 light and 720 dark screenshots, the `scrollWidth` check. Close the tab with `close_page`.

- [ ] **Step 4: Commit**

```bash
git add -A lessons index.html README.md first.jai docs/superpowers/specs
git commit -m "Vulkan content part 1: next links, test-all -solutions-only, docs"
```
