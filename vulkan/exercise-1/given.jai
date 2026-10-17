// Exercise 1, given: the queue-family enumeration and the choice record. Read it as a library, do not
// edit it. The instance, the physical device and the validation recorder come from Gfx_Test, which
// lesson 1 reads alongside this file. The learner's part is exercise.jai.

#import "Basic";
#import "String";   // join
#import "Vulkan";

Queue_Choice :: struct { graphics_family: u32; transfer_family: u32; }   // equal when the device has no transfer-only family

// The two-call enumeration, heap allocated: one VkQueueFamilyProperties per family the ICD exposes.
queue_family_properties :: (physical: VkPhysicalDevice) -> [] VkQueueFamilyProperties {
    count: u32;
    vkGetPhysicalDeviceQueueFamilyProperties(physical, *count, null);
    families := NewArray(count, VkQueueFamilyProperties);
    vkGetPhysicalDeviceQueueFamilyProperties(physical, *count, families.data);
    return families;
}

// "GRAPHICS | COMPUTE | TRANSFER | SPARSE_BINDING", for printing.
queue_flags_string :: (flags: VkQueueFlags) -> string {
    Name :: struct { bit: VkQueueFlagBits; name: string; }
    NAMES :: Name.[
        .{.GRAPHICS_BIT,         "GRAPHICS"},
        .{.COMPUTE_BIT,          "COMPUTE"},
        .{.TRANSFER_BIT,         "TRANSFER"},
        .{.SPARSE_BINDING_BIT,   "SPARSE_BINDING"},
        .{.PROTECTED_BIT,        "PROTECTED"},
        .{.VIDEO_DECODE_BIT_KHR, "VIDEO_DECODE"},
        .{.VIDEO_ENCODE_BIT_KHR, "VIDEO_ENCODE"},
        .{.OPTICAL_FLOW_BIT_NV,  "OPTICAL_FLOW"},
    ];
    names: [..] string;
    for NAMES  if flags & it.bit  array_add(*names, it.name);
    if names.count == 0  return "(none)";
    return join(..names, separator = " | ");
}
