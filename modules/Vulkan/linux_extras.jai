// Hand-written additions for Linux. The generator skips platform-surface
// extensions (vulkan_xlib.h is only pulled in under VK_USE_PLATFORM_XLIB_KHR),
// and the shipped module only knows version constants up to 1.2.

VK_API_VERSION_1_3 :: #run VK_MAKE_API_VERSION(0, 1, 3, 0);
VK_API_VERSION_1_4 :: #run VK_MAKE_API_VERSION(0, 1, 4, 0);

// VK_KHR_xlib_surface. The loader (libvulkan.so.1) exports these directly.
VK_KHR_XLIB_SURFACE_SPEC_VERSION   :: 6;
VK_KHR_XLIB_SURFACE_EXTENSION_NAME :: "VK_KHR_xlib_surface";

VkXlibSurfaceCreateFlagsKHR :: VkFlags;

VkXlibSurfaceCreateInfoKHR :: struct {
    sType:  VkStructureType = .XLIB_SURFACE_CREATE_INFO_KHR;
    pNext:  *void;
    flags:  VkXlibSurfaceCreateFlagsKHR;
    dpy:    *void;   // *X11.Display
    window: u64;     // X11.Window (an XID)
}

PFN_vkCreateXlibSurfaceKHR :: #type (instance: VkInstance, pCreateInfo: *VkXlibSurfaceCreateInfoKHR, pAllocator: *VkAllocationCallbacks, pSurface: *VkSurfaceKHR) -> VkResult #c_call;

vkCreateXlibSurfaceKHR :: (instance: VkInstance, pCreateInfo: *VkXlibSurfaceCreateInfoKHR, pAllocator: *VkAllocationCallbacks, pSurface: *VkSurfaceKHR) -> VkResult #foreign libvulkan;
vkGetPhysicalDeviceXlibPresentationSupportKHR :: (physicalDevice: VkPhysicalDevice, queueFamilyIndex: u32, dpy: *void, visualID: u64) -> VkBool32 #foreign libvulkan;
