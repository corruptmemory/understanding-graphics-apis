# Exercise 4: command buffers and submission

Lesson 4 ([`lessons/vulkan/04-command-buffers.html`](../../lessons/vulkan/04-command-buffers.html))
says what memory a `vkCmd*` call writes, what `vkQueueSubmit2` does and does not do, and which draw
wins at an overlapping pixel. The harness records one buffer and frees it for you. This exercise makes
you own the whole life of a command buffer: allocation, begin, a list of draws, end, a submit of
several buffers at once with a fence, and the free. The tests read the submission order off the
pixels.

## What's different from the lesson

- `given.jai` supplies a shader table: four triangles that all cover the center of the target and
  each cover one point no other does, in four colors, so `vkCmdDraw(cb, 3, 1, 3 * k, 0)` draws
  triangle `k` and the pixels say which draw came last.
- You record several draws into one buffer, and more into a second buffer that loads instead of
  clearing; the tests submit them in an order that is not the recording order and check the pixels.
- You own the submit: one `vkQueueSubmit2` carrying every buffer in order, a fence to wait on, and the
  free afterwards.

The tests put the barriers around your buffers: `prepare_target` goes first in a clearing buffer,
`attachment_barrier` first in a loading one, because two render instances on one image need a barrier
between them whether or not validation can see it yet (lesson 5). The windowed program's loop does the
same between your two buffers each frame.

| k   | Color  | Point only it covers (128 by 128 pixel) |
|-----|--------|-----------------------------------------|
| 0   | red    | `(64, 12)`                              |
| 1   | green  | `(115, 64)`                             |
| 2   | blue   | `(64, 115)`                             |
| 3   | yellow | `(12, 64)`                              |

All four cover `(64, 64)`; `(2, 2)` is outside all of them.

## The contract

Fill in the three procedures in `exercise.jai`; their signatures are fixed.

| Procedure                                                                                                               | Pinned by                                                                                                                                                                                                                                                              |
|-------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `begin_buffer :: (ctx: *Gfx_Context) -> VkCommandBuffer`                                                                | every case: one `PRIMARY` buffer from `ctx.command_pool`, begun with `ONE_TIME_SUBMIT_BIT`; null after a `log_error` on failure                                                                                                                                        |
| `record_scene :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, p: Pipeline, draws: [] int, clear: bool)` | every case: begin rendering over `extent` with `loadOp` `CLEAR` to black when `clear` and `LOAD` otherwise, `storeOp` `STORE`; bind `p`; full viewport and scissor; one `vkCmdDraw(cb, 3, 1, 3 * draws[i], 0)` per entry in order; end rendering; `vkEndCommandBuffer` |
| `submit_ordered :: (ctx: *Gfx_Context, cbs: [] VkCommandBuffer)`                                                        | every case: one `vkQueueSubmit2` carrying every buffer in order through `VkCommandBufferSubmitInfo` entries, with a fence; `vkWaitForFences`; destroy the fence; free the buffers                                                                                      |
| draw order                                                                                                              | `draw_order_within_one_buffer`: `[0, 1, 2, 3]` in one buffer leaves yellow at the center and each unique point its own color; `second_buffer_draws_over_the_first`: `[0, 1]` then a loading `[2]` leaves blue at the center                                            |
| submission order                                                                                                        | `submission_order_not_recording_order`: the loading buffer `[3]` is recorded first but submitted second, so the center is yellow; `two_submits_in_sequence`: two separate submits, the second loading, so the center is green                                          |
| the empty list                                                                                                          | `empty_draw_list_only_clears`: a clearing buffer with no draws leaves the target black                                                                                                                                                                                 |

Every case expects zero validation errors.

## Run

```
~/jai/jai/bin/jai-linux first.jai - test vulkan/exercise-4    # the gate
~/jai/jai/bin/jai-linux first.jai - run vulkan/exercise-4     # four overlapping triangles; the one on top changes every second
```
