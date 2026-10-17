# Understanding Graphics APIs — design

Date: 2026-10-16. Status: draft for Jim's approval.

## 1. Intent

A learning repo, not a reference. Jim wants a deep-ish, accurate mental model of
how a modern graphics API actually moves work from the CPU to the GPU: what the
setup boilerplate is really doing, where each thing happens (application code,
loader and driver, kernel, GPU), and how the main loop (pipelines, command
buffers, submission, synchronization) carries data and work across that boundary.
Three API tracks: **Vulkan** (Linux/X11), **DirectX 11 and 12** (Windows), **Metal**
(macOS). Everything is coded in **Jai**. The motivation is `~/projects/game-bootstrap`,
whose rules (runtime `dlopen` of everything, Wayland support, Slang shaders) do
**not** apply here.

Two deliverables, tightly linked:

- **Lessons**: rendered HTML, an illustrated guide that ties code snippets to
  where things happen, with diagrams and animation.
- **Exercises**: per-lesson Jai code under `<api>/exercise-N/` with tests Jim
  must pass. Jim will not cheat; the tests exist to confirm understanding.

Jim's starting mental model, which the lessons must take apart precisely rather
than dismiss: "a command buffer is bytecode plus data that somehow reaches the
GPU, whose firmware interprets it." The corrections live at specific layers, and
showing which half of that picture is right is the point of lesson 3.

## 2. Goals, non-goals, anti-goals

**Goals**

- An accurate picture of CPU / driver / kernel / GPU responsibilities for every
  step of setup and of the frame loop, grounded in code that runs.
- Lessons that teach one mechanism each, deeply, with the "where is this
  happening" picture always in view.
- Cross-API sidebars from day one ("in Vulkan this is X; D3D12 calls it Y; Metal
  calls it Z"), so Vulkan knowledge transfers when the other tracks unlock.
- Exercises that prove understanding by producing correct pixels and zero
  validation errors, headlessly.
- Self-contained units: a lesson and its exercise can be done without the rest
  of the repo in your head.

**Non-goals**

- A reference manual or exhaustive flag coverage (the endnotes point at the
  three flag setups that show up in practice; the spec covers the rest).
- Wayland, dynamic loading, multi-display-manager support, Slang.
- Engine architecture, asset pipelines, performance tuning beyond what the
  mental model needs. Not in this plan; asset pipelines and performance tuning
  are the first candidates for the **expansion pack** noted in section 10.
- DirectX and Metal **content** now. Their directories and index entries exist;
  nothing inside them is written until this repo runs on Windows and macOS.

**Anti-goals** (failure even if it technically works)

- Lessons that read like the specification.
- A page layout that fights a half-screen laptop window at 1.25x–1.33x scaling.
- Tests passable by copying a listing rather than understanding it.
- Hand-waving at the exact spot where the mechanism matters (what submit does,
  what a barrier is, what the driver compiles).
- Hiding the driver's role; it is a first-class actor in every diagram.

## 3. Constraints

- **Language and toolchain.** Jai beta 0.2.030 (`~/jai/jai/bin/jai-linux`). The
  distribution's modules are used wherever they work: `X11`, `Window_Creation`,
  `Basic`, `Math`, `File`. The shipped `Vulkan` module is **regenerated** (section 6).
- **Platform now.** Linux, X11 only (native X11 on the desktop; XWayland is
  acceptable). Desktop: AMD RX 7900 GRE on Mesa RADV 26.2, Vulkan 1.4 loader,
  Khronos validation layer installed. Laptop: NVIDIA/Intel hybrid, 1.25x–1.33x
  display scaling. **No vendor assumptions anywhere**: prefer a discrete GPU, fall
  back to whatever is first; AMD-specific material is confined to optional deep
  dives.
- **Platforms later.** Windows (D3D11/12) and macOS (Metal) tracks are gated on
  running this repo there.
- **Shaders.** Native, first-class languages only: GLSL compiled to SPIR-V with
  `glslc` for Vulkan; HLSL for DirectX; MSL for Metal. No Slang.
- **Web.** No npm/node, no build step. Hand-authored HTML; vendored JS only if a
  concrete need appears; pages must work from `file://` (so no `fetch` of local
  files) and from any static server.
- **Screen real estate.** Base text 17 px, prose measure about 70 characters,
  code blocks scroll sideways rather than shrink. Two-column spine at or above
  about 1100 CSS px; a one-line pinned strip below that.
- **Repo conventions.** Default branch `master`. Markdown tables aligned in the
  source. `.claude/settings.local.json`, `.superpowers/`, `.build/` and built
  binaries are git-ignored.

## 4. Decisions Jim made

1. **Three tracks, Vulkan first and alone for now.** DirectX and Metal are
   placeholders until the repo runs on those OSes.
2. **Depth over coverage.** A lesson that gets the real flow of one mechanism
   right beats one that lists every flag.
3. **Endnotes, at most three per lesson, collapsed by default.** Each names one
   common alternative flag setup in the shape "a common alternative is X, which
   enables Y; useful for Z; the cost is setting up A and B at initialization."
   Enough to know the detail exists, not the detail itself.
4. **Depth floor.** API-and-driver boundary in detail. Kernel and GPU internals
   as illustrations and brief text. Per-topic **deep dives** are added only when
   a topic grabs Jim, as separate pages linked from the lesson.
5. **Cross-API sidebars everywhere**, conceptual, written now from knowledge,
   verified later when the other tracks unlock.
6. **Tests.** Headless: no window; render into an offscreen image. First
   assertion is always zero validation errors, recorded by a callback on the
   validation layer (the error-recorder pattern from Jim's logging rules). Second
   is pixel readback checked against what the exercise asked for. Pure CPU-side
   pieces get ordinary table-driven tests. The windowed build exists to look at,
   not to grade.
7. **Lesson page layout: the spine.** Prose and code on the left; a pinned
   "where is this happening?" panel on the right with CPU, driver and GPU lanes;
   the box for the current step lights up as you read; sidebars inline where the
   concept appears. Below about 1100 px the panel folds into a one-line pinned
   strip of lane chips that expands on tap.
8. **Vulkan 1.3 baseline** via regenerated bindings (spike proven, section 6):
   dynamic rendering instead of render-pass objects, the synchronization2 calls,
   with the older forms covered in sidebars since D3D12 and Metal have their own
   takes on both.
9. **Vulkan lesson sequence** (section 7), in this order.
10. **Two kinds of exercise, and what a lesson may show.** Lesson N may show the
    real calls for its new mechanism, taken as fragments from the reference
    solution, because seeing which call does what, where, is the point. Then:
    - **Reinforcement exercises (one per lesson).** "If you understand the
      concept, you should be able to extend it to the typical variations that
      would show up." The README asks for something concretely different from
      the lesson (sizes, formats, counts, an added requirement, a variant of
      already-covered material), the tests check that contract, and the tests
      are deterministic.
    - **Mini-projects (a few, placed after clusters of lessons).** Base-level
      boilerplate is provided; the rest is comments. They force Jim to look
      things up and choose for himself, synthesising several lessons. Example:
      instancing where each instance needs its own orientation, which means
      working out how per-instance data reaches the shader. A deterministic
      test may be impossible, so each project ships a **scoring rubric** written
      when the project is formulated, and grading is a session where Claude
      captures the result and judges it against the rubric ("N objects clearly
      visible, each with a different orientation").

## 5. Decisions I made (my calls; veto while reading)

1. **Repository layout.**

   ```
   index.html                          landing page: three tracks, lesson list, links
   lessons/
     assets/lesson.css                 tokens, layout, spine, strip, sidebar, endnotes
     assets/spine.js                   step highlighting, strip collapse, endnote toggles
     assets/vendor/                    only if a library becomes necessary (none planned)
     concept-map.html                  cross-API glossary aggregated from every sidebar
     vulkan/00-three-layers.html … 09-capstone.html
     vulkan/deep-dives/<topic>.html    added on demand
   vulkan/exercise-0 … exercise-9/     reinforcement exercises, see item 3
   vulkan/project-1 … project-3/       mini-projects with rubrics, see item 12
   directx/README.md                   gate note only; track unlocks on Windows
   metal/README.md                     gate note only; track unlocks on macOS
   modules/Vulkan/                     regenerated bindings (section 6)
   modules/Gfx_Test/                   shared headless test harness (item 4)
   solutions/vulkan/exercise-N/        reference solutions (item 5)
   first.jai                           the build program (item 2)
   docs/superpowers/specs/             this document and successors
   ```

2. **Build.** One `first.jai` at the root, in the style of game-bootstrap but
   smaller: `jai first.jai - <verb> [args]`. Verbs: `build <api>/exercise-N`,
   `run <api>/exercise-N` (windowed), `test <api>/exercise-N` (headless, exit
   code is the result), `test-all`, `shaders <api>/exercise-N` (runs `glslc` on
   `shaders/*.vert|*.frag` into `.build/`), `capture <api>/<exercise-or-project>
   [frames]` (renders headlessly and writes `.build/<name>.png`, for grading and
   for lesson figures), `regen-vulkan-bindings`. Shaders are compiled by the
   build, not committed as SPIR-V.
3. **Exercise directory.** Each `vulkan/exercise-N/` is self-contained:
   - `README.md`: one paragraph brief, the contract (what `exercise.jai` must
     provide), and a link to the lesson.
   - `given.jai`: finished code from earlier lessons that this exercise builds
     on, to be read as a library, not edited.
   - `exercise.jai`: the TODO stubs Jim fills in, with the signatures fixed.
   - `tests.jai`: the gate; built and run by `test`.
   - `main.jai`: the windowed runner for looking at the result.
   - `shaders/`: GLSL sources, when the exercise needs them.
   Snippets shown in a lesson are copied from compiling code in the repo
   (`given.jai` or the reference solution) and carry a `data-src="path:line"`
   attribute so drift can be audited; automation of that audit is deferred.
   The README's contract is what makes the exercise more than a retype of the
   lesson: it names the concrete variation, and `tests.jai` checks that
   variation, not the lesson's numbers.
4. **Test harness: `modules/Gfx_Test`.** Creates a headless instance and device
   with the validation layer and a debug-utils messenger whose callback records
   errors and warnings into an `Error_Recorder`; prefers a discrete GPU; creates
   offscreen colour (and, from lesson 8, depth) targets; submits and waits;
   reads pixels back; offers `expect_pixel`, `expect_region_solid`, and a
   tolerance-based image compare against a committed golden PNG where a single
   pixel is not enough; prints one line per case and exits non-zero on any
   failure. Every test's first assertion is `recorder.errors == 0`, and the
   harness fails the run if validation reports leaked objects at teardown.
5. **Reference solutions** live under `solutions/vulkan/exercise-N/`. I need
   them to prove the tests are passable and to source lesson snippets; Jim is on
   his honour not to open them. They are not hidden or git-ignored, because the
   laptop needs them too.
6. **Lesson page anatomy.** Header (track, number, title, exercise link); three
   bullets "after this you can explain…"; numbered steps, each prose plus a
   snippet plus, where it applies, a sidebar; the spine panel; endnotes (at most
   three, collapsed); deep-dive links; "now do exercise N". Dark and light via
   `prefers-color-scheme`. Index status marks are hand-maintained.
7. **Diagrams and animation.** Inline SVG for every diagram, styled by the same
   CSS tokens so they theme. Motion through CSS transitions and the Web
   Animations API driven by `spine.js` (IntersectionObserver picks the active
   step; the panel animates the hand-off arrow for that step). No animation
   library unless a specific lesson needs one, and then it is vendored.
8. **First deep dive candidate.** "What RADV emits for `vkCmdDraw`": dumping the
   driver's command stream on the desktop. AMD-only and optional, linked from
   lesson 3.
9. **Evidence standard for "where" claims (after the builder check).** The
   generic statement comes first and is what the spine panel shows ("the driver
   translates the command buffer into its own command stream"); a named vendor
   may follow inline as a concrete example ("on RADV that is PM4 packets; NVIDIA's
   driver has its own format") wherever it makes the mechanism less abstract.
   Load-bearing mechanism claims that are not simply the specification's words
   carry a pointer to a primary source: a spec section, a Mesa or Vulkan-loader
   source path, a kernel DRM document. Each lesson ends with a short "Sources"
   list rather than per-sentence citations. This follows Jim's standing rule that
   anything that matters lands on a primary source; it is not source-grounding of
   every sentence.
10. **Sidebar and endnote code is illustrative.** Code for other APIs (D3D12,
    Metal) and for legacy forms (render-pass objects, the pre-synchronization2
    barriers) cannot compile in this repo today, so it is exempt from the
    "copied from compiling code" rule, carries no `data-src`, and is visibly
    marked as illustrative. When a track unlocks, its sidebar code is revisited.
11. **Bindings regeneration is a verb, and the generated file is committed.**
   Committing keeps the laptop's build independent of its system header version;
   the verb exists so a newer header can be pulled in deliberately.
12. **Mini-projects: placement, shape, grading.** Three for the Vulkan track,
    each after the cluster of lessons it synthesises:

    | Project   | After lesson | Brief (first draft; the README is the contract)                                                                                     |
    |-----------|--------------|-------------------------------------------------------------------------------------------------------------------------------------|
    | project-1 | 4            | Several distinct things drawn from more than one command buffer, submitted in an order the picture must reveal.                     |
    | project-2 | 7            | Instancing: N copies of one mesh, each with its own orientation and position, so per-instance data has to reach the shader somehow. |
    | project-3 | 9            | A capstone extension of Jim's choosing from a short menu (a second camera, a second material, a simple post-process).               |

    A project directory holds `README.md` (brief, what to look up, the menu of
    choices), `given.jai` (boilerplate), `project.jai` (stubs and comments),
    `main.jai` (windowed), `RUBRIC.md`, and `tests.jai` for whatever is
    deterministic (it builds, it renders something, zero validation errors).
    `RUBRIC.md` is written when the project is formulated, before Jim starts,
    and lists must-have criteria a viewer can judge from the captured image
    ("at least 8 instances visible", "no two share an orientation", "depth
    ordering is correct"), plus stretch items. Grading: Claude runs
    `capture`, reads the PNG, judges each criterion, and reports pass or fail
    with reasons; a live window screenshot (workspace 1) is the fallback when
    the criterion is about motion or presentation rather than a still frame.

## 6. Vulkan bindings (spike result, 2026-10-16)

The distribution's `modules/Vulkan` is generated from Vulkan header **85**
(1.1 era): no 1.2/1.3/1.4 symbols, no dynamic rendering, no synchronization2,
no X11 surface call (the shipped example's Linux surface path is an assert
marked to-do). The module ships its own generator, which the spike ran against
the system's `vulkan.h` (header **363**, Vulkan 1.4). What it took and what it
proved:

- **Generator patches**, both small: (a) omit every top-level declaration whose
  name contains `Video`, because those reference `StdVideo*` types from
  `vk_video/*.h` that the generator does not emit, and nothing here needs the
  video-codec API; (b) add `VkPhysicalDeviceVulkan13/14Features/Properties` to
  the generator's sType exception table so those structs get their default
  `sType` like everything else. Nine exotic feature structs with digits in their
  names still get no default; they are irrelevant and simply need `sType` set by
  hand if ever used.
- **`linux_extras.jai`**, hand-written and `#load`ed from `module.jai`'s Linux
  branch: `VK_API_VERSION_1_3`/`_1_4`, and `VK_KHR_xlib_surface`
  (`VkXlibSurfaceCreateInfoKHR`, `vkCreateXlibSurfaceKHR`,
  `vkGetPhysicalDeviceXlibPresentationSupportKHR`) declared `#foreign libvulkan`,
  which works because the loader exports the Xlib, Xcb and Wayland surface entry
  points directly. Non-core extension functions such as
  `vkCreateDebugUtilsMessengerEXT` are not exported and are fetched with
  `vkGetInstanceProcAddr`; the generated file already has their `PFN_` types.
- **Result**: 25,190 lines, 261 functions, 1,280 structs. A probe program built
  in 0.6 s and ran clean on the desktop: Vulkan 1.3 device with
  `dynamicRendering` and `synchronization2` enabled, barrier2 → dynamic-rendering
  clear → barrier2 → copy to a host buffer → exact pixel readback, an Xlib
  surface with present support, teardown with **zero** validation errors or
  warnings.
- **Quirks to carry into the lessons**: the generator renames a C member that
  collides with a Jai type by prefixing an underscore, so `VkClearColorValue`'s
  `float32` is `_float32`; the 64-bit `*FlagBits2` values are plain constants
  (`VK_PIPELINE_STAGE_2_TRANSFER_BIT : VkPipelineStageFlagBits2 : 4096`), not
  `enum_flags`, so they are combined with `|` on `u64` rather than `.NAME`
  syntax; `-import_dir` makes the repo's `modules/Vulkan` shadow the
  distribution's.

The builder recreates this in `modules/Vulkan/`: copy the distribution module,
apply the two generator patches, add `linux_extras.jai`, run
`regen-vulkan-bindings`, commit the output. The spike directory itself is
throwaway and is not copied.

## 7. Vulkan lesson sequence

Each lesson teaches one mechanism, has a "where is this happening" story the
spine panel animates, and ends in an exercise with a headless test. The
"where" column is what the panel must show; the sidebar column is the minimum
cross-API content.

| #   | Lesson                             | Mechanism and the "where" story                                                                                                                                 | Exercise and test                                                                                                            | Sidebar seeds (D3D12 / Metal)                                                                                        |
|-----|------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| 0   | The three layers                   | App / loader+ICD / kernel+GPU. Takes the bytecode model apart: shader bytecode, the command buffer, and the driver's command stream are three different things. | Enumerate layers, extensions, devices; print which layer answered each query. Table-driven test on the parsing/printing.     | DXGI + D3D12 runtime vs ICD / Metal framework + IOKit; validation layer vs D3D12 debug layer vs Metal API validation |
| 1   | Instance, device, queues           | What the loader is, what the ICD is, what a queue is underneath (a kernel-scheduled submission channel).                                                        | Create a device; choose the right queue family. Test: family index correct for the harness's device, zero validation errors. | `ID3D12Device` + command queues / `MTLDevice` + `MTLCommandQueue`                                                    |
| 2   | Surface and swapchain under X11    | Where pixels go, who owns swapchain images, present modes and vsync, the compositor.                                                                            | Clear the window. Test: clear an offscreen image to a given colour and read it back.                                         | DXGI swap chain / `CAMetalLayer` + drawables                                                                         |
| 3   | Shaders and pipelines              | SPIR-V is real bytecode the driver compiles to GPU instructions at pipeline creation; the pipeline is baked GPU state.                                          | A triangle from hard-coded vertices. Test: specific pixels inside and outside the triangle.                                  | DXIL + PSO / MSL + `MTLRenderPipelineState`; where each API compiles                                                 |
| 4   | Command buffers and submission     | Recording appends to driver-owned CPU memory; submit is where translation and the kernel hand-off happen; what actually crosses to the GPU.                     | Several draws in one buffer, plus a second buffer. Test: pixel readback distinguishes draw order.                            | Command list + allocator / command buffer + encoders                                                                 |
| 5   | Synchronization and the frame loop | Fences (GPU to CPU), semaphores (GPU to GPU), barriers and image layouts (inside the GPU), frames in flight.                                                    | A correct multi-frame loop with N frames in flight. Test: a hazard the harness can detect under validation is absent.        | `ID3D12Fence` everywhere / `MTLEvent`, `MTLFence`, mostly implicit                                                   |
| 6   | Memory and buffers                 | Heaps and types, host-visible vs device-local, mapping, staging uploads, vertex and index buffers.                                                              | Upload geometry through a staging buffer; indexed draw. Test: readback plus a table test on memory-type selection.           | Heap types / `MTLStorageMode`, unified memory on Apple silicon                                                       |
| 7   | Descriptors and push constants     | Binding data to shaders; descriptor sets, layouts, pools; push constants.                                                                                       | A uniform buffer drives a transform. Test: pixels move as the transform says.                                                | Root signature + descriptor heaps / argument buffers, `setBytes`                                                     |
| 8   | Images, samplers, textures, depth  | Image layouts, sampling, depth testing.                                                                                                                         | A textured, depth-tested quad. Test: sampled colour at known coordinates; depth occludes correctly.                          | Resource states / explicit layouts absent in Metal                                                                   |
| 9   | Capstone and the toolkit           | A small scene with a camera, and the debugging toolkit: validation, RenderDoc, GPU timestamps.                                                                  | The scene renders; timestamps read. Test: golden image within tolerance.                                                     | PIX / Xcode GPU capture                                                                                              |

Lesson 0 deserves one note: it is the lesson that sets up the lanes every later
panel uses, so its diagrams are the template for the rest.

## 8. Test harness contract

- `test <api>/exercise-N` builds `tests.jai` with `exercise.jai` and `given.jai`
  and runs it; exit code 0 means pass.
- Every test case begins by resetting the recorder and ends by asserting
  `errors == 0`; a positive test with unexpected validation errors fails even if
  the pixels are right.
- Pixel assertions use a per-channel tolerance of 1 by default; golden-image
  compares state their tolerance.
- The harness must run on the laptop: no AMD-only calls, no assumptions about
  queue family numbering, no assumptions about which GPU is first.
- Tests do not open a window.
- Mini-projects: `tests.jai` covers only the deterministic floor (builds,
  renders a frame headlessly, zero validation errors); the rubric covers the
  rest and is graded by Claude from the captured image.
- **Validation configuration (my call, after the builder check).** Core
  validation (`VK_LAYER_KHRONOS_validation`) is always on. Synchronization
  validation (`VK_EXT_validation_features`, `SYNCHRONIZATION_VALIDATION`) is
  switched on from exercise 5 onward, the lesson where barriers and hazards are
  taught; before that, exercises 2–4 get the image-layout transitions they need
  as helper code in `given.jai`, with the lesson saying in one line that this is
  a barrier and that lesson 5 opens it up. Best-practices and GPU-assisted
  validation stay off. Errors are fatal; warnings are counted and printed, never
  fatal by default, and a test may opt into warnings-fatal. The `test` verb runs
  the binary with `VK_LOADER_LAYERS_DISABLE=~implicit~` so implicit layers on the
  desktop (overlays, device-select) cannot write into the recorder; that is the
  loader's own interface, set by the runner, not read by our code.

## 9. What is left to the builder

- The exact SVG for each lesson's diagrams and how the hand-off arrows animate.
- Snippet selection and the wording of sidebars and endnotes, within the rules
  above (at most three endnotes; sidebars conceptual).
- TODO granularity in each `exercise.jai`, golden-image tolerances, and how much
  of a lesson's code lands in `given.jai`.
- `first.jai` internals, CSS details, the exact `spine.js` behaviour at the
  1100 px breakpoint.
- The concept-map page's structure, as long as it is assembled from the sidebars.

## 10. Open items

- DirectX and Metal tracks: everything, gated on the OS.
- Laptop verification of the harness and bindings under NVIDIA/Intel hybrid
  graphics, including whether PRIME offload needs a note in lesson 1.
- Whether any lesson should reference game-bootstrap's code. Default: no; this
  repo stands alone.
- RenderDoc 1.46 was installed on the desktop on 2026-10-16 from the Arch repos
  (`renderdoc`, rung 1 of Jim's install policy): `qrenderdoc`, `renderdoccmd` and
  `librenderdoc.so` are present, so lesson 9 can use it. The laptop still needs it.
- **Expansion pack (Jim, 2026-10-16): an "advanced topics" section, later.** Not
  part of this lesson plan, but a known future addition once the core tracks
  exist. At least: asset pipelines (how models, textures and shaders get from
  disk into the formats the API wants, and what that costs where) and
  performance tuning (measuring before guessing: GPU timestamps, overlap,
  barriers that stall, upload strategies). Same lesson shape and same spine
  panel; the "where" story is the point there too. Nothing in the current
  layout should make adding `lessons/advanced/` awkward.
