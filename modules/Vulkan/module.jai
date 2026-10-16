/*

Vulkan API bindings for this repo: the Jai distribution's Vulkan module, regenerated
from Vulkan header 363 (Vulkan 1.4) instead of the shipped header 85 (1.1 era).

Linux-only. The DirectX and Metal tracks do not use this module; the Windows and
macOS branches of the shipped module were dropped on purpose.

Regenerate with `first.jai - regen-vulkan-bindings`: it refreshes source/ from
/usr/include/vulkan/, runs generate.jai (two local patches: the video-codec API is
omitted, and the 1.3/1.4 feature/property structs get their sType defaults), and then
builds and runs smoke.jai. generated_linux.jai is committed so the build does not
depend on the host's header version.

Quirks to know when reading or writing code against these bindings:
  - A C member whose name collides with a Jai type gets a leading underscore:
    VkClearColorValue.float32 is `_float32` here.
  - The 64-bit `*FlagBits2` values (VK_PIPELINE_STAGE_2_*, VK_ACCESS_2_*) are plain u64
    constants, not enum_flags: combine them with `|`, there is no `.NAME` syntax for them.
  - Nine digit-named feature structs (e.g. VkPhysicalDeviceShaderFloat8FeaturesEXT) have
    no sType default; set it by hand if you ever use one.
  - Platform-surface entry points are hand-written in linux_extras.jai; extension
    functions the loader does not export (vkCreateDebugUtilsMessengerEXT, ...) must be
    fetched with vkGetInstanceProcAddr, using the PFN_ types generated here.

*/


#module_parameters();

// Helpers

VkVersion :: u32;

VK_Version :: struct {
    major, minor, patch: VkVersion;
}

vk_unmake_version :: (vk_version: VkVersion) -> VK_Version {
    major := VK_VERSION_MAJOR(vk_version);
    minor := VK_VERSION_MINOR(vk_version);
    patch := VK_VERSION_PATCH(vk_version);
    return .{major, minor, patch};
}

// Macros from vulkan headers

VK_NULL_HANDLE                    :: null;

VK_TRUE:                   VkBool32: 1;
VK_FALSE:                  VkBool32: 0;

VK_WHOLE_SIZE:             u64: xx ~0;
VK_ATTACHMENT_UNUSED:      u32: 0xffff_ffff;
VK_QUEUE_FAMILY_IGNORED:   u32: 0xffff_ffff;
VK_REMAINING_ARRAY_LAYERS: u32: 0xffff_ffff;
VK_REMAINING_MIP_LEVELS:   u32: 0xffff_ffff;
VK_SUBPASS_EXTERNAL:       u32: 0xffff_ffff;

VK_MAX_PHYSICAL_DEVICE_NAME_SIZE: u32: 256;
VK_UUID_SIZE:                     u32: 16;
VK_MAX_MEMORY_TYPES:              u32: 32;
VK_MAX_MEMORY_HEAPS:              u32: 16;
VK_MAX_EXTENSION_NAME_SIZE:       u32: 256;
VK_MAX_DESCRIPTION_SIZE:          u32: 256;

// These defines are deprecated by vulkan 1.2:
VK_MAKE_VERSION :: (major: u32, minor: u32, patch: u32) -> u32 {
    return (major << 22) | (minor << 12) | patch;
}
VK_VERSION_MAJOR :: (version: u32) -> u32 { return version >> 22; }
VK_VERSION_MINOR :: (version: u32) -> u32 { return (version >> 12) & 0x3ff; }
VK_VERSION_PATCH :: (version: u32) -> u32 { return version & 0xfff; }

VK_API_VERSION_1_0 :: #run VK_MAKE_VERSION(1, 0, 0);
VK_API_VERSION_1_1 :: #run VK_MAKE_VERSION(1, 1, 0);
VK_API_VERSION_1_2 :: #run VK_MAKE_VERSION(1, 2, 0);

// These are the new versions:
VK_MAKE_API_VERSION :: (variant:u32, major: u32, minor: u32, patch: u32) -> u32 {
    return (variant << 29) | (major << 22) | (minor << 12) | patch;
}

VK_API_VERSION_VARIANT :: (version: u32) -> u32 { return (version >> 29); }
VK_API_VERSION_MAJOR   :: (version: u32) -> u32 { return (version >> 22) & 0x3ff; }
VK_API_VERSION_MINOR   :: (version: u32) -> u32 { return (version >> 12) & 0x3ff; }
VK_API_VERSION_PATCH   :: (version: u32) -> u32 { return version & 0xfff; }

#if OS == .LINUX {
    #load "generated_linux.jai";
    #load "linux_extras.jai";
    libvulkan :: #library,system "libvulkan";
} else {
    #assert false "modules/Vulkan in this repo is Linux-only; the DirectX and Metal tracks do not use it.";
}

