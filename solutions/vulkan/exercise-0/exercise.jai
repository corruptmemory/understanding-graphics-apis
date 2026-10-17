// Exercise 0, reference solution: the two version packings and who offers an extension.

#import "Basic";
#import "Vulkan";

// "1.4.354"; when VK_API_VERSION_VARIANT(v) != 0, "1.0.0 (variant 1)".
api_version_string :: (v: u32) -> string {
    base := tprint("%.%.%", VK_API_VERSION_MAJOR(v), VK_API_VERSION_MINOR(v), VK_API_VERSION_PATCH(v));
    variant := VK_API_VERSION_VARIANT(v);
    if variant == 0  return base;
    return tprint("% (variant %)", base, variant);
}

// Vendor 0x10DE (NVIDIA): "major.minor.patch.rest" from bits 31..22, 21..14, 13..6, 5..0.
// Any other vendor: the Vulkan packing, "26.2.4".
driver_version_string :: (vendor_id: u32, v: u32) -> string {
    if vendor_id == 0x10DE {
        return tprint("%.%.%.%", v >> 22, (v >> 14) & 0xff, (v >> 6) & 0xff, v & 0x3f);
    }
    return tprint("%.%.%", VK_API_VERSION_MAJOR(v), VK_API_VERSION_MINOR(v), VK_API_VERSION_PATCH(v));
}

// Who offers `extension`: "base" first when base_extensions holds it, then every layer whose
// extensions hold it, in inventory order. Empty when nobody offers it.
extension_sources :: (inv: Inventory, extension: string) -> [] string {
    sources: [..] string;
    if array_find(inv.base_extensions, extension)  array_add(*sources, "base");
    for inv.layers  if array_find(it.extensions, extension)  array_add(*sources, it.name);
    return sources;
}
