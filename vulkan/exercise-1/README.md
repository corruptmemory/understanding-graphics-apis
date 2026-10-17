# Exercise 1: instance, device, queues

Lesson 1 ([`lessons/vulkan/01-instance-device-queues.html`](../../lessons/vulkan/01-instance-device-queues.html))
follows one `vkCreateDevice` from your code through the loader's trampoline, the validation layer and
into the ICD, and says what a queue family is, what a queue is in the ICD, and what it is in the kernel.
The lesson and the test harness take the first graphics family and one queue. This exercise makes you
choose families for a device you have never seen and create a device with more than one queue.

## What's different from the lesson

- A dedicated transfer family: the first family that reports `TRANSFER_BIT` and neither `GRAPHICS_BIT`
  nor `COMPUTE_BIT`. Those are DMA engines on most discrete GPUs; a compute family is not one. When the
  device has no such family, the graphics family does the transfers.
- A `VkDeviceCreateInfo` with one `VkDeviceQueueCreateInfo` per distinct family, not one.
- The features chain: `VkPhysicalDeviceVulkan13Features` with `dynamicRendering` and `synchronization2`
  hung off `VkPhysicalDeviceFeatures2` in `pNext`, which is how a Vulkan 1.3 device asks for 1.3 features.

The desktop's RADV reports five families: graphics, compute, transfer and sparse binding with one
queue; compute, transfer and sparse binding with four; video decode; video encode; and sparse binding
alone, which cannot transfer. None is transfer-only, so the live cases see `0 / 0` there; the table
cases carry the layouts other drivers report, including a dedicated DMA family.

## The contract

Fill in the two procedures in `exercise.jai`; their signatures are fixed. `given.jai` is a library:
read it, do not edit it.

| Procedure                                                                                                                         | Pinned by                                                                                                                                                                                                                                       |
|-----------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `choose_queue_families :: (families: [] VkQueueFamilyProperties) -> (choice: Queue_Choice, ok: bool)`                             | `families_one_of_each`, `families_single_family`, `families_transfer_before_compute`, `families_compute_is_not_transfer_only`, `families_none_graphics` (`ok` is false when no family has `GRAPHICS_BIT`)                                       |
| `create_device :: (physical: VkPhysicalDevice, choice: Queue_Choice) -> (device: VkDevice, graphics: VkQueue, transfer: VkQueue)` | `live_device_creates_and_destroys`: a device with one queue per distinct family, both queues non-null, equal exactly when the families are equal, destroyed with zero validation errors; `null` after a `log_error` when `vkCreateDevice` fails |
| both, on the real device                                                                                                          | `live_choice_matches_the_harness`: the graphics family is the harness's, the transfer family can transfer, and when it differs from the graphics family it has neither `GRAPHICS_BIT` nor `COMPUTE_BIT`                                         |

## Run

```
~/jai/jai/bin/jai-linux first.jai - test vulkan/exercise-1    # the gate
~/jai/jai/bin/jai-linux first.jai - run vulkan/exercise-1     # prints the families, the choice, and creates the device
```
