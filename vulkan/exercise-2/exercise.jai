// Exercise 2: your part. Fill in the five procedures; their signatures are fixed and cases.jai
// checks them. The contract is in README.md; the mechanism is in lesson 2.

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

// B8G8R8A8_SRGB with COLOR_SPACE_SRGB_NONLINEAR_KHR when offered, else formats[0].
choose_surface_format :: (formats: [] VkSurfaceFormatKHR) -> VkSurfaceFormatKHR {
    // TODO (lesson 2, step 2)
    return .{};
}

// vsync: FIFO_KHR. Otherwise MAILBOX_KHR if offered, else IMMEDIATE_KHR if offered, else FIFO_KHR.
choose_present_mode :: (modes: [] VkPresentModeKHR, vsync: bool) -> VkPresentModeKHR {
    // TODO (lesson 2, step 2): FIFO is the one mode every surface offers.
    return .IMMEDIATE_KHR;   // the zero value; replace it
}

// caps.currentExtent unless its width is 0xFFFFFFFF, then the window size clamped to
// [minImageExtent, maxImageExtent].
choose_extent :: (caps: VkSurfaceCapabilitiesKHR, window_w: u32, window_h: u32) -> VkExtent2D {
    // TODO (lesson 2, step 2): X11 reports the window size; Wayland reports the sentinel.
    return .{};
}

// minImageCount + 1, clamped to maxImageCount when maxImageCount != 0.
choose_image_count :: (caps: VkSurfaceCapabilitiesKHR) -> u32 {
    // TODO (lesson 2, step 2): zero means "no maximum".
    return 0;
}

// One dynamic-rendering instance over the whole extent whose only effect is loadOp CLEAR with
// `color` and storeOp STORE, on an image already in COLOR_ATTACHMENT_OPTIMAL.
record_clear :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, color: [4] float) {
    // TODO (lesson 2, step 5)
}
