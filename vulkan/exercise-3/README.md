# Exercise 3: shaders and pipelines

Lesson 3 ([`lessons/vulkan/03-shaders-pipelines.html`](../../lessons/vulkan/03-shaders-pipelines.html))
shows one pipeline, counter-clockwise front faces with back-face culling, and one full-size viewport,
and says what the driver compiles and when. This exercise makes the winding and the cull mode
parameters of the pipeline and asks for a half-width viewport, so that the pipeline's baked state and
the dynamic state are seen to be different things, and so that the corners must be ordered by
Vulkan's rule, not OpenGL's.

## What's different from the lesson

- You write both shaders. `shaders/tri.vert` holds the three corners `(-0.8, 0.8)`, `(0.8, 0.8)`,
  `(0.0, -0.8)` in a `const vec2[3]` indexed by `gl_VertexIndex`, in an order that is front-facing under
  `VK_FRONT_FACE_COUNTER_CLOCKWISE` by the specification's rule: the signed area is computed in
  framebuffer coordinates, where y points down. `shaders/tri.frag` writes solid green,
  `vec4(0.0, 1.0, 0.0, 1.0)`. The build compiles them with `glslc` before every test and run.
- `create_pipeline` takes the front face and the cull mode as parameters; the tests make three
  pipelines from the same shaders and expect different pixels.
- `record_triangle` takes the viewport as a parameter and sets it with `vkCmdSetViewport`; the scissor
  is always the whole extent. One pipeline then serves any target size and any placement.

`given.jai` carries lesson 2 forward and adds `Pipeline`, `destroy_pipeline` and `draw_to_target`, the
headless frame the tests use.

## The contract

Fill in `exercise.jai` and the two shaders; the signatures are fixed.

| Procedure                                                                                                                                   | Pinned by                                                                                                                                                                                                                                                                                                                                                                                                                                             |
|---------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `create_pipeline :: (ctx: *Gfx_Context, color_format: VkFormat, front_face: VkFrontFace, cull: VkCullModeFlags) -> (p: Pipeline, ok: bool)` | every case; two stages from `TRI_VERT` and `TRI_FRAG` (modules destroyed after creation), no vertex input, `TRIANGLE_LIST`, dynamic `VIEWPORT` and `SCISSOR` (one each), `FILL`, the given cull and front face, line width 1, one sample, one color attachment with blending off and an RGBA write mask, an empty layout, `VkPipelineRenderingCreateInfo` naming `color_format` in `pNext`, `renderPass` null; `false` after a `log_error` on failure |
| `record_triangle :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, p: Pipeline, viewport: VkViewport, clear: [4] float)`      | every case; begin rendering over `extent` with `loadOp` `CLEAR` to `clear` and `storeOp` `STORE`, bind `p`, set the viewport, scissor the whole extent, `vkCmdDraw(cb, 3, 1, 0, 0)`, end rendering                                                                                                                                                                                                                                                    |
| the shaders                                                                                                                                 | `triangle_shows_with_ccw_and_back_cull`: on a 128 by 128 target, `(64, 64)` and `(64, 100)` are green and `(5, 5)`, `(10, 60)`, `(120, 120)` are black                                                                                                                                                                                                                                                                                                |
| winding and culling                                                                                                                         | `triangle_culled_when_front_face_is_clockwise`: the same corners with `CLOCKWISE` and `BACK_BIT` leave the target black; `triangle_shows_when_cull_is_none`: `CLOCKWISE` with `NONE` shows the triangle                                                                                                                                                                                                                                               |
| dynamic state                                                                                                                               | `viewport_moves_the_triangle`: viewport `{64, 0, 64, 128, 0, 1}` leaves the left half black and puts green at `(96, 64)` and `(96, 100)`                                                                                                                                                                                                                                                                                                              |

Every case destroys its pipeline and expects zero validation errors.

## Run

```
~/jai/jai/bin/jai-linux first.jai - test vulkan/exercise-3    # the gate
~/jai/jai/bin/jai-linux first.jai - run vulkan/exercise-3     # a green triangle pointing up on a dark window
```
