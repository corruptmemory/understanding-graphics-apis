# Exercise 0: the three layers

Lesson 0 ([`lessons/vulkan/00-three-layers.html`](../../lessons/vulkan/00-three-layers.html))
walks through the five enumeration calls and says which of the three layers answers each one:
your program, the loader with its layers and drivers, or the kernel and the GPU. `given.jai`
makes those calls and prints the report. This exercise owns the parts the lesson only reads off
the screen: the two version packings and the bookkeeping of who offers an extension.

## What's different from the lesson

The lesson shows the five calls and one layer's extension list. The exercise owns:

- the API version packing (`VK_API_VERSION_*` fields, including the variant bits a Vulkan SC
  implementation sets);
- the driver version, which is the driver's to define: NVIDIA splits the 32 bits 10/8/8/6, Mesa
  (RADV, ANV) uses the Vulkan packing;
- `extension_sources`: for one extension name, who offers it, `"base"` (the null-layer query)
  first, then every layer that lists it, in inventory order.

## The contract

Fill in the three procedures in `exercise.jai`; their signatures are fixed. `given.jai` is a
library: read it, do not edit it.

| Procedure                                                               | Pinned by                                                                                                                                                                                                                                |
|-------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `api_version_string :: (v: u32) -> string`                              | `api_version_table`: `"1.4.354"`, `"1.3.0"`, `"1.0.0 (variant 1)"`                                                                                                                                                                       |
| `driver_version_string :: (vendor_id: u32, v: u32) -> string`           | `driver_version_table`: vendor `0x10DE` splits bits 31..22, 21..14, 13..6, 5..0 as `"580.95.5.0"`; any other vendor uses the Vulkan packing, `"26.2.4"`                                                                                  |
| `extension_sources :: (inv: Inventory, extension: string) -> [] string` | `extension_sources_table`: `"base"` first when `base_extensions` holds it, then each layer name whose `extensions` hold it, in inventory order; empty when nobody offers it                                                              |
| all three, on the real machine                                          | `live_inventory_has_the_validation_layer`: the inventory collects, the instance is 1.3 or newer, `VK_LAYER_KHRONOS_validation` is present, `VK_EXT_validation_features` comes from that layer and not from `"base"`, at least one device |

## Run

```
~/jai/jai/bin/jai-linux first.jai - test vulkan/exercise-0    # the gate
~/jai/jai/bin/jai-linux first.jai - run vulkan/exercise-0     # the report, through print_inventory
```
