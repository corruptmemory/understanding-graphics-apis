// Exercise 0: your part. Fill in the three procedures; their signatures are fixed and cases.jai
// checks them. The contract is in README.md; the mechanism is in lesson 0.

#import "Basic";
#import "Vulkan";

// "1.4.354"; when VK_API_VERSION_VARIANT(v) != 0, "1.0.0 (variant 1)".
api_version_string :: (v: u32) -> string {
    // TODO (lesson 0, step 1): unpack the four fields with the VK_API_VERSION_* procedures.
    return "";
}

// Vendor 0x10DE (NVIDIA): "major.minor.patch.rest" from bits 31..22, 21..14, 13..6, 5..0.
// Any other vendor: the Vulkan packing, "26.2.4".
driver_version_string :: (vendor_id: u32, v: u32) -> string {
    // TODO (lesson 0, step 4): driverVersion is the driver's to define; two packings cover what you will meet.
    return "";
}

// Who offers `extension`: "base" first when base_extensions holds it, then every layer whose
// extensions hold it, in inventory order. Empty when nobody offers it.
extension_sources :: (inv: Inventory, extension: string) -> [] string {
    // TODO (lesson 0, step 2): the null-layer list is a merge the loader does not label; the per-layer lists do.
    return .[];
}
