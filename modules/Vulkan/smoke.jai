// Compile-only proof that the regenerated bindings are the ones in use.
// Built and run by `first.jai - regen-vulkan-bindings`; also runnable directly:
//   ~/jai/jai/bin/jai-linux modules/Vulkan/smoke.jai -import_dir "$PWD/modules" && modules/Vulkan/smoke
// (a RELATIVE -import_dir is resolved against this file's directory, not the cwd, and
//  the binary lands next to this file.)
#import "Basic";
#import "Vulkan";

#assert VK_HEADER_VERSION == 363;

main :: () {
    v := VK_API_VERSION_1_3;                               // from linux_extras.jai
    f := vkCmdBeginRendering;                              // 1.3 core, exported by the loader
    x := vkCreateXlibSurfaceKHR;                           // from linux_extras.jai
    b: VkImageMemoryBarrier2;                              // synchronization2 struct
    assert(b.sType == .IMAGE_MEMORY_BARRIER_2);
    f13: VkPhysicalDeviceVulkan13Features;
    assert(f13.sType == .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES);
    print("Vulkan bindings OK: header %, api 1.3 = %\n", VK_HEADER_VERSION, v);
}
