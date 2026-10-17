# Project 1 rubric

Graded from `build/vulkan-project-1.png` (frame 30, written by `first.jai - capture vulkan/project-1`)
and the README's Layout section, plus one windowed run. Written before the project is started.

## Must-haves

| #   | Criterion                                                                                                                         | Judged from      |
|-----|-----------------------------------------------------------------------------------------------------------------------------------|------------------|
| 1   | At least six shapes are visible, each distinguishable by position, size or color                                                  | the capture      |
| 2   | At least two triangles and at least two quads among them                                                                          | the capture      |
| 3   | At least three overlaps between shapes                                                                                            | the capture      |
| 4   | At every overlap the color on top is the one the Layout section says comes later                                                  | capture + README |
| 5   | The moving shape sits over the static shapes it overlaps                                                                          | the capture      |
| 6   | Nothing is clipped unintentionally: no shape cut by the edge or by a scissor the Layout does not mention                          | the capture      |
| 7   | `test vulkan/project-1` passes: a frame renders headlessly, two buffers per frame, frames 0 and 30 differ, zero validation errors | the tests        |
| 8   | The windowed program fills the window at the swapchain's size and keeps running when the window is resized                        | the run          |

## Stretch

| #   | Criterion                                                                                   | Judged from             |
|-----|---------------------------------------------------------------------------------------------|-------------------------|
| S1  | One shape is clipped on purpose by a scissor rectangle the Layout section names             | capture + README        |
| S2  | A second moving shape, at a different speed from the first                                  | two captures or the run |
| S3  | A comment in `project.jai` saying why the static buffer is safe to submit again every frame | the source              |
