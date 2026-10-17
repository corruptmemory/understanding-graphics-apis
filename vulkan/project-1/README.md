# Project 1: several things, more than one command buffer, an order the picture must reveal

A mini-project, not an exercise: the base boilerplate is in `given.jai`, the rest is comments. You
draw a small scene from two command buffers, one recorded once and submitted every frame, one
re-recorded every frame, and the picture has to make the submission order visible. Lessons 2, 3 and
4 are the material; this README is the contract and [`RUBRIC.md`](RUBRIC.md) is how it is graded.

## The contract

- At least **six distinct shapes**, with different sizes, positions and colors: at least two
  triangles and at least two quads.
- Drawn from **at least two command buffers**: a **static** buffer recorded once and submitted every
  frame, and a **per-frame** buffer re-recorded each frame with at least one shape that **moves**
  with the frame number.
- At least **three overlaps**. Every per-frame shape lies over every static shape it overlaps, and
  within each buffer later draws cover earlier ones in the order your **Layout** section below
  declares.
- The first buffer **clears**; the second **loads**. Put `attachment_barrier` at the start of the
  second, because two render instances on one image need a barrier between them (lesson 4, step 5).
- The windowed program runs at the **swapchain's size**, not a hard-coded one: the viewport and
  scissor come from the extent `scene_record` receives.
- `scene_init`, `scene_record` and `scene_destroy` in `project.jai` keep their signatures; add to
  `Scene` whatever else you need.

## Layout (yours to write)

Replace this list with your shapes, in draw order per buffer, with the color each one is drawn in.
The grader reads it next to the capture.

- static, draw 1: …
- static, draw 2: …
- per-frame, draw 1: … (moves: …)

## What to look up

- `gl_VertexIndex` and the `firstVertex` argument of `vkCmdDraw`: a table of shapes and colors in the
  vertex shader, with no vertex buffers, as `vulkan/exercise-4/shaders/table.vert` does. A quad is two
  triangles, six corners.
- `vkCmdSetViewport` and `vkCmdSetScissor` for placement and clipping: one table, drawn through
  different viewports, is six shapes.
- `loadOp`: `CLEAR` for the first buffer, `LOAD` for the second.
- The begin flags. `ONE_TIME_SUBMIT_BIT` forbids submitting a buffer again, so the static buffer is
  recorded without it. `vkResetCommandBuffer`, or simply `vkBeginCommandBuffer` again (the pool was
  created with `RESET_COMMAND_BUFFER_BIT`), re-records the per-frame buffer.
- `SIMULTANEOUS_USE_BIT`: what it means, and why `present_loop`'s one-frame-in-flight fence makes it
  unnecessary here. `present_loop` waits for last frame's fence before it calls `scene_record` again,
  so nothing you appended last frame is still pending.
- The static buffer is recorded for one image view. The tests render into one target; the windowed
  program's swapchain has several images, each with its own view, so either keep one static buffer
  per view (record on first use) or accept re-recording when the view changes. Say which in a comment.

## Run and grade

```
~/jai/jai/bin/jai-linux first.jai - test    vulkan/project-1   # the deterministic floor: builds, a frame renders, two buffers, frames differ, zero validation errors
~/jai/jai/bin/jai-linux first.jai - run     vulkan/project-1   # 600 frames in a window, at the swapchain's size
~/jai/jai/bin/jai-linux first.jai - capture vulkan/project-1   # build/vulkan-project-1.png: frame 30, for grading against RUBRIC.md
```

The tests are the floor, not the grade. Grading is a session: Claude runs `capture`, reads the PNG
and judges each line of `RUBRIC.md` against it and against this README's Layout section.
