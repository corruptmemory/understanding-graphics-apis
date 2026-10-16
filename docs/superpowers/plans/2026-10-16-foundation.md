# Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up everything the Vulkan lessons will build on: regenerated Vulkan 1.4 bindings as a repo module, the `first.jai` build program with its verbs, and the `Gfx_Test` headless harness, proven by a self-check target that renders, reads back, and reports zero validation errors.

**Architecture:** A single root metaprogram (`first.jai`) builds any `<api>/<name>/` target directory into `build/`, compiling that target's GLSL first. `modules/Vulkan` is the distribution's module regenerated from header 363 with two generator patches and a hand-written Linux extras file. `modules/Gfx_Test` owns the headless device, the validation recorder, offscreen targets, readback, pixel assertions, PNG capture and the test runner; every later exercise's `tests.jai` is a thin list of cases over it.

**Tech Stack:** Jai beta 0.2.030 (`~/jai/jai/bin/jai-linux`), distribution modules `Compiler`, `Process`, `File`, `File_Utilities`, `String`, `stb_image_write`, `Window_Creation`, `X11`; Vulkan loader 1.4.363 with `VK_LAYER_KHRONOS_validation`; `glslc`.

**Spec:** `docs/superpowers/specs/2026-10-16-graphics-api-learning-design.md` (sections 3, 5, 6, 8 are the ones this plan implements).

**Plan series.** The spec spans three subsystems that each produce testable software on their own. This is plan 1 of 3:

1. **Foundation** (this plan): bindings, build program, harness, self-check.
2. **Lesson web shell**: `index.html`, `lessons/assets/lesson.css`, `lessons/assets/spine.js`, the lesson template, the concept-map skeleton, verified at desktop and narrow widths.
3. **Vulkan content**, in three parts following the lesson clusters: lessons 0–4 and project-1; lessons 5–7 and project-2; lessons 8–9 and project-3.

## Global Constraints

- Compiler: `~/jai/jai/bin/jai-linux`, beta 0.2.030. Invoke the build program as `~/jai/jai/bin/jai-linux first.jai - <verb> [args]`; run it from the repo root.
- Platform: Linux, X11 only. No vendor assumptions anywhere: prefer a `DISCRETE_GPU`, fall back to the first device that reports API 1.3 or newer.
- Vulkan: bindings regenerated from header **363**; `VK_API_VERSION_1_3` requested; device features `dynamicRendering` and `synchronization2` required; the video-codec API is omitted from the bindings.
- Validation: `VK_LAYER_KHRONOS_validation` always on in the harness; errors fatal; warnings counted and printed, not fatal unless a case opts in; synchronization validation off unless a case opts in.
- Test runs get the environment `VK_LOADER_LAYERS_DISABLE=~implicit~` from the runner; our code never reads environment variables except `DISPLAY` to decide whether an X11 case can run.
- Shaders: GLSL compiled by `glslc --target-env=vulkan1.3`; SPIR-V is never committed; it lands in `<target>/.build/spv/`.
- Outputs: binaries in `build/` as `<api>-<name>` and `<api>-<name>-tests`; both `build/` and every `.build/` are git-ignored.
- Repo: branch `master`; Markdown tables aligned in the source; every commit ends with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Output discipline: `print` for a tool's first-class output (test results, verb usage), `log_error` for failures, never a silent failure.

## Review Focus

1. **The validation layer is missing** (fresh machine, or a layer path problem): `gfx_init` must return null after a `log_error` naming the layer, not crash inside `vkCreateInstance`. Pinned by `missing_layer_is_reported` in Task 3.
2. **Hybrid laptop with the integrated GPU enumerated first**: the discrete device must be chosen; with no discrete device, the first 1.3-capable one; with none, a clear failure. Pinned by the `choose_physical_device` table in Task 3.
3. **A broken GLSL file**: the build must stop with glslc's message and never run a binary against a stale `.spv`. Pinned by the broken-shader verification in Task 5.
4. **Implicit layers on the desktop** (MangoHud, device-select) writing into the recorder as warnings: the `test` verb's environment must keep them out. Pinned by the `MANGOHUD=1` verification in Task 2.
5. **`-capture` to a path whose directory does not exist**: the harness must create the directory or fail with the path in the message. Pinned by `capture_creates_parent_directory` in Task 4.

---

### Task 1: Vulkan bindings module (Linux, header 363)

**Files:**
- Create: `modules/Vulkan/module.jai`, `modules/Vulkan/generate.jai`, `modules/Vulkan/linux_extras.jai`, `modules/Vulkan/source/vulkan.h`, `modules/Vulkan/source/vulkan_core.h`, `modules/Vulkan/source/vk_platform.h`, `modules/Vulkan/generated_linux.jai`, `modules/Vulkan/smoke.jai`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: the distribution module at `~/jai/jai/modules/Vulkan/`, the system headers at `/usr/include/vulkan/`.
- Produces: `#import "Vulkan"` (with import path `modules`) exposing the full 1.4 core API minus video, plus `VK_API_VERSION_1_3`, `VK_API_VERSION_1_4`, `VkXlibSurfaceCreateInfoKHR`, `vkCreateXlibSurfaceKHR`, `vkGetPhysicalDeviceXlibPresentationSupportKHR`, `VK_KHR_XLIB_SURFACE_EXTENSION_NAME`. Every `Vk*CreateInfo`-style struct carries its `sType` default except the nine digit-named feature structs the generator cannot derive.

- [ ] **Step 1: Copy the distribution module and strip what this repo does not use**

Run from the repo root:

```bash
cp -r ~/jai/jai/modules/Vulkan modules/Vulkan
rm -rf modules/Vulkan/win modules/Vulkan/examples modules/Vulkan/source
rm -f modules/Vulkan/generated_windows.jai modules/Vulkan/windows_extras.jai modules/Vulkan/generated_linux.jai
mkdir modules/Vulkan/source
cp /usr/include/vulkan/vulkan.h /usr/include/vulkan/vulkan_core.h /usr/include/vulkan/vk_platform.h modules/Vulkan/source/
grep -m1 'define VK_HEADER_VERSION ' modules/Vulkan/source/vulkan_core.h
```

Expected: the last line prints `#define VK_HEADER_VERSION 363`.

- [ ] **Step 2: Write the smoke check that must fail until the module is regenerated**

Create `modules/Vulkan/smoke.jai`:

```jai
// Compile-only proof that the regenerated bindings are the ones in use.
#import "Basic";
#import "Vulkan";

#assert VK_HEADER_VERSION == 363;

main :: () {
    v := VK_API_VERSION_1_3;                               // from linux_extras.jai
    f := vkCmdBeginRendering;                              // 1.3 core, exported by the loader
    x := vkCreateXlibSurfaceKHR;                           // from linux_extras.jai
    b: VkImageMemoryBarrier2;                              // synchronization2 struct
    assert(b.sType == .IMAGE_MEMORY_BARRIER_2);
    f13: VkPhysicalDeviceVulkan13Features;
    assert(f13.sType == .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES);
    print("Vulkan bindings OK: header %, api 1.3 = %\n", VK_HEADER_VERSION, v);
}
```

`vkCreateXlibSurfaceKHR` is declared in `linux_extras.jai` (Step 4).

- [ ] **Step 3: Run the smoke check to verify it fails**

Run: `~/jai/jai/bin/jai-linux modules/Vulkan/smoke.jai -import_dir "$PWD/modules"`
Expected: FAIL (no `generated_linux.jai` yet, so `module.jai` cannot `#load` it). The import directory must be absolute: a relative `-import_dir` is resolved against the main source file's directory, not the working directory, and would silently fall through to the distribution's module.

- [ ] **Step 4: Write `modules/Vulkan/linux_extras.jai`**

Exact content (this is the interface later tasks use):

```jai
// Hand-written additions for Linux. The generator skips platform-surface
// extensions (vulkan_xlib.h is only pulled in under VK_USE_PLATFORM_XLIB_KHR),
// and the shipped module only knows version constants up to 1.2.

VK_API_VERSION_1_3 :: #run VK_MAKE_API_VERSION(0, 1, 3, 0);
VK_API_VERSION_1_4 :: #run VK_MAKE_API_VERSION(0, 1, 4, 0);

// VK_KHR_xlib_surface. The loader (libvulkan.so.1) exports these directly.
VK_KHR_XLIB_SURFACE_SPEC_VERSION   :: 6;
VK_KHR_XLIB_SURFACE_EXTENSION_NAME :: "VK_KHR_xlib_surface";

VkXlibSurfaceCreateFlagsKHR :: VkFlags;

VkXlibSurfaceCreateInfoKHR :: struct {
    sType:  VkStructureType = .XLIB_SURFACE_CREATE_INFO_KHR;
    pNext:  *void;
    flags:  VkXlibSurfaceCreateFlagsKHR;
    dpy:    *void;   // *X11.Display
    window: u64;     // X11.Window (an XID)
}

PFN_vkCreateXlibSurfaceKHR :: #type (instance: VkInstance, pCreateInfo: *VkXlibSurfaceCreateInfoKHR, pAllocator: *VkAllocationCallbacks, pSurface: *VkSurfaceKHR) -> VkResult #c_call;

vkCreateXlibSurfaceKHR :: (instance: VkInstance, pCreateInfo: *VkXlibSurfaceCreateInfoKHR, pAllocator: *VkAllocationCallbacks, pSurface: *VkSurfaceKHR) -> VkResult #foreign libvulkan;
vkGetPhysicalDeviceXlibPresentationSupportKHR :: (physicalDevice: VkPhysicalDevice, queueFamilyIndex: u32, dpy: *void, visualID: u64) -> VkBool32 #foreign libvulkan;
```

- [ ] **Step 5: Patch `modules/Vulkan/generate.jai`**

Two insertions, exactly these:

(a) In `vulkan_visitor`, immediately before the `// Omit our OMIT_LIST` block:

```jai
    // Omit the whole video-codec API: its structs reference StdVideo* types from
    // vk_video/*.h, which this generator does not emit, and nothing here needs it.
    if !parent_decl && contains(decl.name, "Video") {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }
```

(b) In `STRUCT_NAME_TO_STYPE_EXCEPTIONS`, after the `VkPhysicalDeviceVulkan12Properties` row:

```jai
        .{"VkPhysicalDeviceVulkan13Features",                     "PHYSICAL_DEVICE_VULKAN_1_3_FEATURES"},
        .{"VkPhysicalDeviceVulkan13Properties",                   "PHYSICAL_DEVICE_VULKAN_1_3_PROPERTIES"},
        .{"VkPhysicalDeviceVulkan14Features",                     "PHYSICAL_DEVICE_VULKAN_1_4_FEATURES"},
        .{"VkPhysicalDeviceVulkan14Properties",                   "PHYSICAL_DEVICE_VULKAN_1_4_PROPERTIES"},
```

Also change the comment at the top of the file to say it is run via `first.jai - regen-vulkan-bindings` and reads `source/vulkan.h` (header 363 snapshot).

- [ ] **Step 6: Rewrite the OS branch of `modules/Vulkan/module.jai`**

Replace the whole `#if OS == .WINDOWS { ... } else #if ... { ... } else { ... }` block at the bottom with:

```jai
#if OS == .LINUX {
    #load "generated_linux.jai";
    #load "linux_extras.jai";
    libvulkan :: #library,system "libvulkan";
} else {
    #assert false "modules/Vulkan in this repo is Linux-only; the DirectX and Metal tracks do not use it.";
}
```

Replace the header comment block with: what this module is (the distribution's Vulkan module regenerated from header 363), that it is Linux-only, how to regenerate (`first.jai - regen-vulkan-bindings`), and the two quirks from the spec (section 6): members colliding with Jai type names get a leading underscore (`VkClearColorValue._float32`), and the 64-bit `*FlagBits2` values are plain constants combined with `|`, not `enum_flags`.

- [ ] **Step 7: Run the generator**

Run: `cd modules/Vulkan && ~/jai/jai/bin/jai-linux generate.jai; cd ../..`
Expected: ends with `OK! generated 'generated_linux.jai'`; exactly 9 `Could not find VkStructType enum value` lines, every one naming a `VkPhysicalDevice*Features*` struct; `generated_linux.jai` contains `VK_HEADER_VERSION :: 363;` and `grep -c StdVideo modules/Vulkan/generated_linux.jai` prints `0`.

- [ ] **Step 8: Run the smoke check to verify it passes**

Run: `~/jai/jai/bin/jai-linux modules/Vulkan/smoke.jai -import_dir "$PWD/modules" && modules/Vulkan/smoke && rm -f modules/Vulkan/smoke && rm -rf modules/Vulkan/.build`
(The binary and the `.build/` intermediates land next to the main source file.)
Expected: prints `Vulkan bindings OK: header 363, api 1.3 = 4206592`.

- [ ] **Step 9: Ignore build artefacts and commit**

Append to `.gitignore`:

```
build/
.build/
```

```bash
git add .gitignore modules/Vulkan
git commit -m "Add the Vulkan module regenerated from header 363 (Linux-only)" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: The build program `first.jai`

**Files:**
- Create: `first.jai`, `README.md`, `vulkan/harness-check/tests.jai` (placeholder, replaced in Task 3), `vulkan/harness-check/main.jai` (placeholder)

**Interfaces:**
- Consumes: Task 1's module; the distribution's `Compiler`, `Process`, `File`, `File_Utilities`, `String`.
- Produces: the CLI contract every later task and plan uses:

  | Verb                          | Does                                                                                                                                                                                                                                                                      |
  |-------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
  | `help`                        | prints the table below and exits 0; also the response to no verb or an unknown verb (exit 1 for unknown)                                                                                                                                                                  |
  | `build <api>/<name>`          | compiles `<api>/<name>/main.jai` to `build/<api>-<name>`; runs `shaders` first when `<api>/<name>/shaders/` exists                                                                                                                                                        |
  | `run <api>/<name> [args…]`    | `build`, then runs the binary with `args`; exit code propagated                                                                                                                                                                                                           |
  | `test <api>/<name> [args…]`   | compiles `<api>/<name>/tests.jai` to `build/<api>-<name>-tests` (shaders first, as above), runs it as `env VK_LOADER_LAYERS_DISABLE=~implicit~ build/<api>-<name>-tests args…`; exit code propagated                                                                      |
  | `shaders <api>/<name>`        | for each `<api>/<name>/shaders/*.vert`, `*.frag`, `*.comp`: `glslc --target-env=vulkan1.3 -o <api>/<name>/.build/spv/<file>.spv <file>`; stops at the first failure, printing glslc's output, exit 1; prints nothing on success beyond one line per compiled file         |
  | `regen-vulkan-bindings`       | copies the three headers from `/usr/include/vulkan/` into `modules/Vulkan/source/`, runs `<jai>/bin/jai-linux generate.jai` in `modules/Vulkan` (jai path from `compiler_get_base_path()`), then compiles and runs `modules/Vulkan/smoke.jai`; exit code of the last step |
  | `test-all`                    | Task 5                                                                                                                                                                                                                                                                    |
  | `capture <api>/<name> [path]` | Task 4                                                                                                                                                                                                                                                                    |

  Target workspaces get `import_path = ["modules"] + defaults`, `set_optimization(.DEBUG)`, `arithmetic_overflow_check = .FATAL`, `output_path = "build"`, `intermediate_path = "<api>/<name>/.build"` (both directories created with `make_directory_if_it_does_not_exist` before the build), `output_executable_name` as in the table. A target's files reference each other with `#load`, so the target directory is not an import path. `regen-vulkan-bindings` compiles `modules/Vulkan/smoke.jai` through the same workspace routine (output `build/vulkan-bindings-smoke`) and runs it.

- [ ] **Step 1: Create the placeholder target that the verbs are tested against**

`vulkan/harness-check/tests.jai`:

```jai
#import "Basic";
main :: () { print("placeholder tests\n"); exit(0); }
```

`vulkan/harness-check/main.jai`:

```jai
#import "Basic";
main :: () { print("placeholder main\n"); }
```

- [ ] **Step 2: Verify the verbs fail before `first.jai` exists**

Run: `~/jai/jai/bin/jai-linux first.jai - help`
Expected: compiler error, file not found.

- [ ] **Step 3: Write `first.jai`**

Structure, following `~/projects/game-bootstrap/first.jai` (its `build_and_run` is the reference for the workspace idiom):

- `#run` entry: `set_build_options_dc(.{do_output = false})`; read `get_build_options().compile_time_command_line`; the first argument is the verb, the rest its arguments; dispatch with `if verb == { case "help"; … }`.
- `build_target :: (target: string, entry: string, suffix: string) -> bool` creates a workspace, applies `copy_commonly_propagated_fields(get_build_options(), *opts)`, sets the options listed in Interfaces, `compiler_begin_intercept`, `add_build_file`, loops on `compiler_wait_for_message` until `.COMPLETE`, returns false if `error_code != .NONE`, `compiler_end_intercept`.
- `compile_shaders :: (target: string) -> bool` using `file_list` on `<target>/shaders` and `run_command("glslc", "--target-env=vulkan1.3", "-o", out, src, capture_and_return_output = true)`; on a non-zero exit, `log_error` with the captured output and return false. Creates `<target>/.build/spv` with `make_directory_if_it_does_not_exist(…, recursive = true)`.
- `run_binary :: (path: string, args: [] string, env_prefix: [] string) -> s32` wrapping `run_command("env", …env_prefix, path, …args)` and returning `exit_code`.
- `regen_vulkan_bindings :: () -> bool` as in the Interfaces table.
- Every failure path prints what failed and the command that failed before `exit(1)`.
- `print_usage :: ()` prints the verb table.

Also write `README.md`: one paragraph on what the repo is, the exact `jai first.jai - <verb>` invocation, the verb table, and "see docs/superpowers/specs/ for the design".

- [ ] **Step 4: Verify each verb on the placeholder target**

Run and expect:

| Command                                                           | Expected                                                                                                                                                                          |
|-------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `~/jai/jai/bin/jai-linux first.jai - help`                        | verb table, exit 0                                                                                                                                                                |
| `~/jai/jai/bin/jai-linux first.jai - bogus`                       | `Unknown verb 'bogus'` plus the table, exit 1                                                                                                                                     |
| `~/jai/jai/bin/jai-linux first.jai - build vulkan/harness-check`  | `build/vulkan-harness-check` exists, exit 0                                                                                                                                       |
| `~/jai/jai/bin/jai-linux first.jai - run vulkan/harness-check`    | prints `placeholder main`, exit 0                                                                                                                                                 |
| `~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`   | prints `placeholder tests`, exit 0; `ls build/` shows `vulkan-harness-check-tests`                                                                                                |
| `~/jai/jai/bin/jai-linux first.jai - build vulkan/does-not-exist` | error naming `vulkan/does-not-exist/main.jai`, exit 1                                                                                                                             |
| `~/jai/jai/bin/jai-linux first.jai - regen-vulkan-bindings`       | generator output ending in `OK!`, then `Vulkan bindings OK: header 363, api 1.3 = 4206592`, exit 0; `git status` shows `modules/Vulkan` unchanged (regeneration is deterministic) |
| `ls vulkan/harness-check/.build`                                  | exists (intermediate path honoured)                                                                                                                                               |

- [ ] **Step 5: Verify the implicit-layer guard (Review Focus 4)**

Run: `MANGOHUD=1 ~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`
Expected: identical output to the plain `test` run, no MangoHud banner or layer messages. (The placeholder has no Vulkan yet; this verifies the `env` prefix is wired. Task 3 repeats the check with a real instance.)

- [ ] **Step 6: Commit**

```bash
git add first.jai README.md vulkan/harness-check
git commit -m "Add first.jai: build, run, test, shaders, regen-vulkan-bindings verbs" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `Gfx_Test` part 1: context, recorder, device selection, runner

**Files:**
- Create: `modules/Gfx_Test/module.jai`, `modules/Gfx_Test/device.jai`, `modules/Gfx_Test/runner.jai`
- Modify: `vulkan/harness-check/tests.jai` (replace the placeholder)

**Interfaces:**
- Consumes: Task 1's bindings; Task 2's `test` verb.
- Produces (all in `#import "Gfx_Test"`):

```jai
Error_Recorder :: struct { errors: int; warnings: int; messages: [..] string; }

Gfx_Context :: struct {
    instance:          VkInstance;
    messenger:         VkDebugUtilsMessengerEXT;
    destroy_messenger: PFN_vkDestroyDebugUtilsMessengerEXT;
    physical_device:   VkPhysicalDevice;
    device:            VkDevice;
    queue:             VkQueue;
    queue_family:      u32;
    command_pool:      VkCommandPool;
    recorder:          Error_Recorder;
    device_name:       string;
}

Gfx_Init_Options :: struct {
    sync_validation := false;
    layer_name      := "VK_LAYER_KHRONOS_validation";
}

gfx_init     :: (options := Gfx_Init_Options.{}) -> *Gfx_Context;   // null after log_error on any failure
gfx_shutdown :: (ctx: *Gfx_Context);                                 // destroys everything, then frees ctx

Device_Candidate :: struct { index: int; device_type: VkPhysicalDeviceType; api_version: u32; name: string; }
choose_physical_device :: (candidates: [] Device_Candidate) -> int;  // -1 when none reports API >= 1.3
find_memory_type :: (props: VkPhysicalDeviceMemoryProperties, type_bits: u32, wanted: VkMemoryPropertyFlags) -> (index: u32, ok: bool);

Test_Case :: struct {
    name:                     string;
    proc:                     (ctx: *Gfx_Context) -> bool;
    expect_validation_errors := 0;      // a negative test says how many it expects
    warnings_fatal           := false;
    sync_validation          := false;
    needs_display            := false;  // SKIP when DISPLAY is unset
}
run_tests :: (cases: [] Test_Case, args: [] string) -> int;         // exit code
```

`run_tests` creates a fresh context per case (so leaks are attributed), prints exactly one line per case, `PASS <name>`, `FAIL <name>: <reason>` or `SKIP <name>: <reason>`, then `<p> passed, <f> failed, <s> skipped`, and returns 1 if any failed. After `proc` returns, the runner itself checks `recorder.errors == expect_validation_errors` and, when `warnings_fatal`, `recorder.warnings == 0`; a mismatch is a FAIL even when `proc` returned true. It parses `-verbose` (print every recorded message) and `-capture <path>` (stored in the module global `capture_path: string`, used in Task 4). `DISPLAY` is read with a one-line `getenv :: (name: *u8) -> *u8 #foreign libc;` plus `libc :: #library,system "libc";` in `runner.jai`.

Device selection: `gfx_init` enumerates devices into `Device_Candidate`s and calls `choose_physical_device`; the chosen device must offer a queue family with `GRAPHICS_BIT`; `vkGetPhysicalDeviceFeatures2` with a chained `VkPhysicalDeviceVulkan13Features` must report `dynamicRendering` and `synchronization2`, and the device is created with exactly those two enabled through the same chain. Instance extensions: `VK_KHR_surface`, `VK_KHR_xlib_surface`, `VK_EXT_debug_utils`; device extensions: `VK_KHR_swapchain`. The debug messenger is chained into `VkInstanceCreateInfo.pNext` as well as created afterwards, with the callback recording `ERROR_BIT_EXT` into `errors` and `WARNING_BIT_EXT` into `warnings`, appending the message text to `messages` in both cases. When `sync_validation` is set, chain a `VkValidationFeaturesEXT` enabling `SYNCHRONIZATION_VALIDATION_EXT`.

- [ ] **Step 1: Write the failing tests**

Replace `vulkan/harness-check/tests.jai` with a file that `#import "Gfx_Test"` and `#import "Vulkan"` and defines:

```jai
choose_discrete_over_integrated :: (ctx: *Gfx_Context) -> bool {
    c := Device_Candidate.[
        .{0, .INTEGRATED_GPU, VK_API_VERSION_1_3, "igpu"},
        .{1, .DISCRETE_GPU,   VK_API_VERSION_1_3, "dgpu"},
    ];
    return choose_physical_device(c) == 1;
}
choose_first_capable_without_discrete :: (ctx: *Gfx_Context) -> bool {
    c := Device_Candidate.[
        .{0, .INTEGRATED_GPU, VK_API_VERSION_1_2, "old"},
        .{1, .INTEGRATED_GPU, VK_API_VERSION_1_3, "new"},
        .{2, .CPU,            VK_API_VERSION_1_4, "llvmpipe"},
    ];
    return choose_physical_device(c) == 1;
}
choose_none_when_nothing_is_1_3 :: (ctx: *Gfx_Context) -> bool {
    c := Device_Candidate.[ .{0, .DISCRETE_GPU, VK_API_VERSION_1_2, "old"} ];
    return choose_physical_device(c) == -1;
}
memory_type_table :: (ctx: *Gfx_Context) -> bool {
    props: VkPhysicalDeviceMemoryProperties;
    props.memoryTypeCount = 3;
    props.memoryTypes[0].propertyFlags = .DEVICE_LOCAL_BIT;
    props.memoryTypes[1].propertyFlags = .HOST_VISIBLE_BIT;
    props.memoryTypes[2].propertyFlags = .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT;
    i, ok := find_memory_type(props, 0b111, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT);
    if !(ok && i == 2) return false;
    i, ok = find_memory_type(props, 0b001, .HOST_VISIBLE_BIT);     // bit mask excludes the matches
    if ok return false;
    i, ok = find_memory_type(props, 0b110, .HOST_VISIBLE_BIT);     // first match wins
    return ok && i == 1;
}
device_comes_up_with_1_3_features :: (ctx: *Gfx_Context) -> bool {
    f13: VkPhysicalDeviceVulkan13Features;
    f2:  VkPhysicalDeviceFeatures2;
    f2.pNext = *f13;
    vkGetPhysicalDeviceFeatures2(ctx.physical_device, *f2);
    return f13.dynamicRendering != 0 && f13.synchronization2 != 0 && ctx.queue != null && ctx.device_name.count > 0;
}
validation_error_is_recorded :: (ctx: *Gfx_Context) -> bool {
    // vkEndCommandBuffer on a buffer that was never begun is a validation error.
    ai: VkCommandBufferAllocateInfo;
    ai.commandPool = ctx.command_pool; ai.level = .PRIMARY; ai.commandBufferCount = 1;
    cb: VkCommandBuffer;
    vkAllocateCommandBuffers(ctx.device, *ai, *cb);
    vkEndCommandBuffer(cb);
    return ctx.recorder.errors == 1 && ctx.recorder.messages.count >= 1;
}
missing_layer_is_reported :: (ctx: *Gfx_Context) -> bool {
    other := gfx_init(.{layer_name = "VK_LAYER_DOES_NOT_EXIST"});
    return other == null;   // and the run shows a log_error naming VK_LAYER_DOES_NOT_EXIST
}

CASES :: Test_Case.[
    .{name = "choose_discrete_over_integrated",       proc = choose_discrete_over_integrated},
    .{name = "choose_first_capable_without_discrete", proc = choose_first_capable_without_discrete},
    .{name = "choose_none_when_nothing_is_1_3",       proc = choose_none_when_nothing_is_1_3},
    .{name = "memory_type_table",                     proc = memory_type_table},
    .{name = "device_comes_up_with_1_3_features",     proc = device_comes_up_with_1_3_features},
    .{name = "validation_error_is_recorded",          proc = validation_error_is_recorded, expect_validation_errors = 1},
    .{name = "missing_layer_is_reported",             proc = missing_layer_is_reported},
];

main :: () { exit(run_tests(CASES, get_command_line_arguments())); }
```

- [ ] **Step 2: Run to verify it fails**

Run: `~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`
Expected: compile error, `Gfx_Test` module not found.

- [ ] **Step 3: Implement `modules/Gfx_Test`**

`module.jai` holds the structs above and `#load`s `device.jai` and `runner.jai`; `device.jai` holds `gfx_init`, `gfx_shutdown`, `choose_physical_device`, `find_memory_type`, the debug callback (`#c_call`, `push_context`, cast `pUserData` to `*Error_Recorder`); `runner.jai` holds `Test_Case`, `run_tests`, argument parsing, `capture_path`, `getenv`. The spike at the scratchpad path named in the spec is a correct reference for the instance and device sequence, but the scratchpad is session-scoped; do not depend on it existing.

- [ ] **Step 4: Run to verify it passes**

Run: `~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`
Expected: seven `PASS` lines, `7 passed, 0 failed, 0 skipped`, exit 0; one `log_error` line during `missing_layer_is_reported` naming `VK_LAYER_DOES_NOT_EXIST`.

- [ ] **Step 5: Repeat the implicit-layer guard with a real instance**

Run: `MANGOHUD=1 ~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check -verbose`
Expected: same seven PASS lines; the verbose message dump contains no messages from layers other than `VK_LAYER_KHRONOS_validation`.

- [ ] **Step 6: Commit**

```bash
git add modules/Gfx_Test vulkan/harness-check/tests.jai
git commit -m "Add Gfx_Test: headless context, validation recorder, device selection, runner" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: `Gfx_Test` part 2: offscreen target, readback, pixel assertions, PNG capture

**Files:**
- Create: `modules/Gfx_Test/target.jai`
- Modify: `modules/Gfx_Test/module.jai` (add `#load "target.jai"`, `#import "stb_image_write"`), `vulkan/harness-check/tests.jai`, `first.jai` (add `capture`)

**Interfaces:**
- Consumes: Task 3's `Gfx_Context`, `find_memory_type`, `capture_path`.
- Produces:

```jai
Gfx_Target :: struct {
    width, height:   u32;
    format:          VkFormat;
    image:           VkImage;
    memory:          VkDeviceMemory;
    view:            VkImageView;
    readback_buffer: VkBuffer;
    readback_memory: VkDeviceMemory;
}
create_target  :: (ctx: *Gfx_Context, width: u32, height: u32, format := VkFormat.R8G8B8A8_UNORM) -> Gfx_Target;  // usage COLOR_ATTACHMENT | TRANSFER_SRC, DEVICE_LOCAL; readback buffer HOST_VISIBLE | HOST_COHERENT
destroy_target :: (ctx: *Gfx_Context, target: *Gfx_Target);

begin_commands  :: (ctx: *Gfx_Context) -> VkCommandBuffer;      // allocate from ctx.command_pool, begin ONE_TIME_SUBMIT
submit_and_wait :: (ctx: *Gfx_Context, cb: VkCommandBuffer);    // end, vkQueueSubmit2, fence wait, free the buffer and fence

transition_image :: (cb: VkCommandBuffer, image: VkImage,
                     old_layout: VkImageLayout, new_layout: VkImageLayout,
                     src_stage: VkPipelineStageFlags2, src_access: VkAccessFlags2,
                     dst_stage: VkPipelineStageFlags2, dst_access: VkAccessFlags2);   // one VkImageMemoryBarrier2, colour aspect, all mips and layers

Pixels :: struct { width, height: int; rgba: [] u8; }   // tightly packed, row-major, top-left first
readback :: (ctx: *Gfx_Context, target: *Gfx_Target, current_layout: VkImageLayout) -> Pixels;
    // transitions current_layout -> TRANSFER_SRC_OPTIMAL, copies to readback_buffer, maps and copies out;
    // when capture_path is non-empty, also calls save_png(pixels, capture_path)

pixel_at            :: (p: Pixels, x: int, y: int) -> (r: u8, g: u8, b: u8, a: u8, ok: bool);   // ok false when out of range
expect_pixel        :: (p: Pixels, x: int, y: int, r: u8, g: u8, b: u8, a: u8, tolerance := 1, loc := #caller_location) -> bool;
expect_region_solid :: (p: Pixels, x0: int, y0: int, x1: int, y1: int, r: u8, g: u8, b: u8, a: u8, tolerance := 1, loc := #caller_location) -> bool;  // inclusive-exclusive box
save_png            :: (p: Pixels, path: string) -> bool;   // creates the parent directory; stbi_write_png with stride width*4
```

`expect_*` print `expect failed at <file>:<line>: pixel (x,y) = (r,g,b,a), wanted (…) ±t` on failure and return false; out-of-range coordinates fail the same way with `out of range` in the message.

The `capture` verb: `capture <api>/<name> [path]` = `test <api>/<name> -capture <path>`, default path `build/<api>-<name>.png`.

- [ ] **Step 1: Write the failing tests**

Append to `vulkan/harness-check/tests.jai` and add to `CASES`:

```jai
clear_color_reads_back :: (ctx: *Gfx_Context) -> bool {
    t := create_target(ctx, 64, 64);
    defer destroy_target(ctx, *t);
    cb := begin_commands(ctx);
    transition_image(cb, t.image, .UNDEFINED, .COLOR_ATTACHMENT_OPTIMAL,
                     VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                     VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT);
    att: VkRenderingAttachmentInfo;
    att.imageView = t.view; att.imageLayout = .COLOR_ATTACHMENT_OPTIMAL;
    att.loadOp = .CLEAR; att.storeOp = .STORE;
    att.clearValue.color._float32 = .[0.25, 0.5, 0.75, 1.0];
    ri: VkRenderingInfo;
    ri.renderArea = .{.{0, 0}, .{64, 64}}; ri.layerCount = 1;
    ri.colorAttachmentCount = 1; ri.pColorAttachments = *att;
    vkCmdBeginRendering(cb, *ri);
    vkCmdEndRendering(cb);
    submit_and_wait(ctx, cb);
    p := readback(ctx, *t, .COLOR_ATTACHMENT_OPTIMAL);
    return expect_pixel(p, 32, 32, 64, 128, 191, 255) && expect_region_solid(p, 0, 0, 64, 64, 64, 128, 191, 255);
}
expect_pixel_out_of_range_fails_cleanly :: (ctx: *Gfx_Context) -> bool {
    p: Pixels; p.width = 2; p.height = 2; p.rgba = NewArray(16, u8);
    r, g, b, a, ok := pixel_at(p, 2, 0);
    return !ok && !expect_pixel(p, 2, 0, 0, 0, 0, 0);
}
capture_creates_parent_directory :: (ctx: *Gfx_Context) -> bool {
    p: Pixels; p.width = 2; p.height = 2; p.rgba = NewArray(16, u8);
    path := "build/capture-check/nested/out.png";
    return save_png(p, path) && file_exists(path);
}
```

(`file_exists` from `File_Utilities`; the test file gains `#import "File_Utilities";`.) The clear test is the spike's proof restated as a harness test; the expected bytes are `0.25*255`, `0.5*255`, `0.75*255` rounded, with tolerance 1.

- [ ] **Step 2: Run to verify it fails**

Run: `~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`
Expected: compile error, `create_target` undeclared.

- [ ] **Step 3: Implement `target.jai` and the `capture` verb**

`readback` uses `vkCmdCopyImageToBuffer` with `bufferRowLength = 0` (tight packing) and a `VkBufferImageCopy` covering the whole image. `save_png` calls `make_directory_if_it_does_not_exist(path_strip_filename(path), recursive = true)` first and returns false with a `log_error` naming the path when `stbi_write_png` returns 0.

- [ ] **Step 4: Run to verify it passes**

Run: `~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`
Expected: ten PASS lines, `10 passed, 0 failed, 0 skipped`, exit 0.

- [ ] **Step 5: Verify capture end to end**

Run: `~/jai/jai/bin/jai-linux first.jai - capture vulkan/harness-check && file build/vulkan-harness-check.png`
Expected: `PNG image data, 64 x 64, 8-bit/color RGBA`. Open the file with the Read tool and confirm it is a uniform blue-ish square (the clear colour 64,128,191).

- [ ] **Step 6: Commit**

```bash
git add modules/Gfx_Test first.jai vulkan/harness-check/tests.jai
git commit -m "Add Gfx_Test targets, readback, pixel assertions and PNG capture" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Shader path, X11 surface check, `test-all`, track stubs

**Files:**
- Create: `vulkan/harness-check/shaders/check.vert`, `directx/README.md`, `metal/README.md`
- Modify: `vulkan/harness-check/tests.jai`, `vulkan/harness-check/main.jai`, `first.jai` (add `test-all`), `README.md`, `modules/Gfx_Test/module.jai` (add `load_spirv`)

**Interfaces:**
- Consumes: Task 2's `shaders` verb; Task 1's Xlib declarations; `Window_Creation` from the distribution.
- Produces: `load_spirv :: (path: string) -> [] u32` in `Gfx_Test` (reads a `.spv` file; asserts the size is a multiple of 4 and the first word is `0x07230203`), for use at compile time as `CODE :: #run load_spirv(tprint("%.build/spv/<file>.spv", #filepath));`. `test-all` verb: runs `test` for every `<api>/<name>/tests.jai` found under `vulkan/`, `directx/`, `metal/` in sorted order, prints one summary line per target and a final `<n> targets, <f> failed`, exit 1 if any failed.

- [ ] **Step 1: Write the GLSL file and the failing tests**

`vulkan/harness-check/shaders/check.vert`:

```glsl
#version 450
void main() { gl_Position = vec4(0.0, 0.0, 0.0, 1.0); }
```

Append to `vulkan/harness-check/tests.jai` and `CASES`:

```jai
CHECK_VERT :: #run load_spirv(tprint("%.build/spv/check.vert.spv", #filepath));

shader_module_from_glslc_output :: (ctx: *Gfx_Context) -> bool {
    ci: VkShaderModuleCreateInfo;
    ci.codeSize = xx (CHECK_VERT.count * 4);
    ci.pCode    = CHECK_VERT.data;
    m: VkShaderModule;
    if vkCreateShaderModule(ctx.device, *ci, null, *m) != .SUCCESS return false;
    vkDestroyShaderModule(ctx.device, m, null);
    return CHECK_VERT[0] == 0x07230203;
}
xlib_surface_is_presentable :: (ctx: *Gfx_Context) -> bool {
    win := create_window(160, 120, "harness-check");
    sci: VkXlibSurfaceCreateInfoKHR;
    sci.dpy = x_global_display; sci.window = xx win;
    surface: VkSurfaceKHR;
    if vkCreateXlibSurfaceKHR(ctx.instance, *sci, null, *surface) != .SUCCESS return false;
    defer vkDestroySurfaceKHR(ctx.instance, surface, null);
    ok: VkBool32;
    vkGetPhysicalDeviceSurfaceSupportKHR(ctx.physical_device, ctx.queue_family, surface, *ok);
    return ok != 0;
}
```

with `.{name = "xlib_surface_is_presentable", proc = xlib_surface_is_presentable, needs_display = true}`. The file now also needs `#import "Window_Creation"; #import "X11";`.

Replace `vulkan/harness-check/main.jai` with a program that calls `gfx_init`, prints `ctx.device_name`, and `gfx_shutdown`s: the windowed runner for this target is just that, since there is nothing to show yet.

- [ ] **Step 2: Run to verify it fails**

Run: `~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`
Expected: compile error, `load_spirv` undeclared (the `shaders` step itself must already have produced `vulkan/harness-check/.build/spv/check.vert.spv`; confirm with `ls`).

- [ ] **Step 3: Implement `load_spirv`, `test-all`, the stubs**

`directx/README.md` and `metal/README.md`: three lines each: the track is gated on running this repo on Windows / macOS; nothing here yet; the Vulkan sidebars seed the mapping. Add `test-all` to the verb table in `README.md` and `print_usage`.

- [ ] **Step 4: Run to verify it passes**

Run: `~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`
Expected: `12 passed, 0 failed, 0 skipped`, exit 0, and a 160×120 window flashes briefly during the X11 case.

Run: `DISPLAY= ~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`
Expected: `SKIP xlib_surface_is_presentable: DISPLAY not set`, `11 passed, 0 failed, 1 skipped`, exit 0.

Run: `~/jai/jai/bin/jai-linux first.jai - test-all`
Expected: one line for `vulkan/harness-check`, then `1 targets, 0 failed`, exit 0.

- [ ] **Step 5: Verify a broken shader stops the build (Review Focus 3)**

Append `this is not glsl` to `vulkan/harness-check/shaders/check.vert`, then run `~/jai/jai/bin/jai-linux first.jai - test vulkan/harness-check`.
Expected: glslc's error text naming `check.vert`, no test output, exit 1, and `vulkan/harness-check/.build/spv/check.vert.spv` has not been rewritten (compare `stat -c %Y` before and after). Restore the file and confirm `test` passes again.

- [ ] **Step 6: Commit**

```bash
git add first.jai README.md modules/Gfx_Test vulkan/harness-check directx/README.md metal/README.md
git commit -m "Add the shader path, X11 surface check, test-all, and track stubs" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Done when

`~/jai/jai/bin/jai-linux first.jai - test-all` passes on the desktop with twelve cases in `vulkan/harness-check`, `capture` produces a readable PNG, `regen-vulkan-bindings` is a no-op on a clean tree, and the laptop can run the same `test-all` (the X11 case may SKIP there) without any change to the code.
