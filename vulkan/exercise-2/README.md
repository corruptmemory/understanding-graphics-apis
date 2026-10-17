# Exercise 2: surface and swapchain under X11

Lesson 2 ([`lessons/vulkan/02-surface-swapchain.html`](../../lessons/vulkan/02-surface-swapchain.html))
shows where pixels go: the surface the loader makes from an X11 window, the swapchain whose images the
presentation engine owns, and the acquire, clear, present round trip. The lesson shows a 64 by 64 clear
and one hard-coded swapchain. This exercise owns the four decisions a swapchain rests on and a clear of
a given color on a 96 by 64 target.

## What's different from the lesson

- The four choosers, each with its trap: the surface format (prefer `B8G8R8A8_SRGB`, fall back to
  whatever is first), the present mode (`FIFO_KHR` is the only one always offered), the extent
  (`currentExtent` is `0xFFFFFFFF` when the surface lets you choose, so clamp the window size instead;
  X11 reports the window size, Wayland reports the sentinel), and the image count (`maxImageCount` is
  zero when there is no maximum).
- `record_clear`: one dynamic-rendering instance whose only effect is a `CLEAR` load with the given
  color, on an image already in `COLOR_ATTACHMENT_OPTIMAL`, over the whole extent, with `STORE`.

`given.jai` carries the surface, the swapchain creation that calls your choosers, and `present_loop`,
the one-frame-in-flight windowed loop every later exercise reuses. Read it; lesson 5 opens up the sync
objects it uses.

## The contract

Fill in the five procedures in `exercise.jai`; their signatures are fixed.

| Procedure                                                                                        | Pinned by                                                                                                                                                                                                                                                                                                         |
|--------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `choose_surface_format :: (formats: [] VkSurfaceFormatKHR) -> VkSurfaceFormatKHR`                | `surface_format_prefers_bgra_srgb`, `surface_format_falls_back_to_first`                                                                                                                                                                                                                                          |
| `choose_present_mode :: (modes: [] VkPresentModeKHR, vsync: bool) -> VkPresentModeKHR`           | `present_mode_table`: vsync gives `FIFO_KHR`; otherwise `MAILBOX_KHR` if offered, else `IMMEDIATE_KHR` if offered, else `FIFO_KHR`                                                                                                                                                                                |
| `choose_extent :: (caps: VkSurfaceCapabilitiesKHR, window_w: u32, window_h: u32) -> VkExtent2D`  | `extent_uses_current_when_set`, `extent_clamps_when_undefined`                                                                                                                                                                                                                                                    |
| `choose_image_count :: (caps: VkSurfaceCapabilitiesKHR) -> u32`                                  | `image_count_table`: `minImageCount + 1`, clamped to `maxImageCount` when that is not zero                                                                                                                                                                                                                        |
| `record_clear :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, color: [4] float)` | `clear_reads_back`: a 96 by 64 target cleared to `(0.8, 0.2, 0.4, 1.0)` reads back as `(204, 51, 102, 255)` everywhere                                                                                                                                                                                            |
| all of them, on a real window                                                                    | `swapchain_from_real_surface` (skipped without `DISPLAY`): a 320 by 200 window, a surface, a swapchain with vsync whose image count honors `minImageCount`, whose extent is the surface's `currentExtent`, and whose format is what your chooser picked from the real list; destroyed with zero validation errors |

## Run

```
~/jai/jai/bin/jai-linux first.jai - test vulkan/exercise-2    # the gate
~/jai/jai/bin/jai-linux first.jai - run vulkan/exercise-2     # a 640 by 480 window cleared to dark blue, 300 frames
```
