# Understanding Graphics APIs

A learning repo, not a reference: illustrated HTML lessons plus Jai exercises for
Vulkan (Linux/X11), DirectX 11 and 12 (Windows) and Metal (macOS), built around one
question for every call: where is this actually happening, on the CPU, in the driver,
or on the GPU? Only the Vulkan track exists until this repo runs on the other two
operating systems. The design lives in `docs/superpowers/specs/`.

## Building

Everything goes through the build program:

```
~/jai/jai/bin/jai-linux first.jai - <verb> [args]
```

| Verb                          | Does                                                                                                |
|-------------------------------|-----------------------------------------------------------------------------------------------------|
| `help`                        | print the verb table                                                                                |
| `build <api>/<name>`          | compile `<api>/<name>/main.jai` to `build/<api>-<name>`; compiles the target's shaders first        |
| `run <api>/<name> [args...]`  | build, then run the binary with `args`                                                              |
| `test <api>/<name> [args...]` | compile `tests.jai` to `build/<api>-<name>-tests` and run it headlessly; exit code is the result    |
| `capture <api>/<name> [path]` | run the tests with `-capture`; the last readback lands in `path` (default `build/<api>-<name>.png`) |
| `shaders <api>/<name>`        | `glslc` every `shaders/*.vert`, `*.frag`, `*.comp` into `<target>/.build/spv/`                      |
| `regen-vulkan-bindings`       | refresh `modules/Vulkan/source/` from `/usr/include/vulkan/` and regenerate the bindings            |

A target is a directory `<api>/<name>/`, for example `vulkan/exercise-3`. Test binaries run
with `VK_LOADER_LAYERS_DISABLE=~implicit~` so overlay layers stay out of the validation
recorder. Binaries land in `build/`, intermediates in each target's `.build/`; both are
git-ignored.

## Layout

| Path                 | What                                                             |
|----------------------|------------------------------------------------------------------|
| `lessons/`           | the HTML lessons (plan 2)                                        |
| `vulkan/exercise-N/` | one reinforcement exercise per lesson, with headless tests       |
| `vulkan/project-N/`  | mini-projects graded against a rubric                            |
| `modules/Vulkan/`    | the Jai distribution's Vulkan module regenerated from header 363 |
| `modules/Gfx_Test/`  | the headless test harness every exercise's tests build on        |
| `directx/`, `metal/` | placeholders until the repo runs on Windows and macOS            |
| `docs/superpowers/`  | design documents and implementation plans                        |
