// Exercise 2, reference solution: the four swapchain choices and a clear through dynamic rendering.

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

// B8G8R8A8_SRGB with COLOR_SPACE_SRGB_NONLINEAR_KHR when offered, else formats[0].
choose_surface_format :: (formats: [] VkSurfaceFormatKHR) -> VkSurfaceFormatKHR {
    for formats  if it.format == .B8G8R8A8_SRGB && it.colorSpace == .COLOR_SPACE_SRGB_NONLINEAR_KHR  return it;
    return formats[0];
}

// vsync: FIFO_KHR. Otherwise MAILBOX_KHR if offered, else IMMEDIATE_KHR if offered, else FIFO_KHR,
// which every surface must offer.
choose_present_mode :: (modes: [] VkPresentModeKHR, vsync: bool) -> VkPresentModeKHR {
    if vsync  return .FIFO_KHR;
    if array_find(modes, .MAILBOX_KHR)    return .MAILBOX_KHR;
    if array_find(modes, .IMMEDIATE_KHR)  return .IMMEDIATE_KHR;
    return .FIFO_KHR;
}

// caps.currentExtent unless its width is 0xFFFFFFFF, then the window size clamped to
// [minImageExtent, maxImageExtent].
choose_extent :: (caps: VkSurfaceCapabilitiesKHR, window_w: u32, window_h: u32) -> VkExtent2D {
    if caps.currentExtent.width != 0xFFFF_FFFF  return caps.currentExtent;
    return .{clamp(window_w, caps.minImageExtent.width,  caps.maxImageExtent.width),
             clamp(window_h, caps.minImageExtent.height, caps.maxImageExtent.height)};
}

// minImageCount + 1, clamped to maxImageCount when maxImageCount != 0 (zero means no maximum).
choose_image_count :: (caps: VkSurfaceCapabilitiesKHR) -> u32 {
    count := caps.minImageCount + 1;
    if caps.maxImageCount != 0 && count > caps.maxImageCount  count = caps.maxImageCount;
    return count;
}

// One dynamic-rendering instance over the whole extent whose only effect is loadOp CLEAR with
// `color` and storeOp STORE, on an image already in COLOR_ATTACHMENT_OPTIMAL.
record_clear :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, color: [4] float) {
    att: VkRenderingAttachmentInfo;
    att.imageView   = view;
    att.imageLayout = .COLOR_ATTACHMENT_OPTIMAL;
    att.loadOp      = .CLEAR;
    att.storeOp     = .STORE;
    att.clearValue.color._float32 = color;

    ri: VkRenderingInfo;
    ri.renderArea           = .{.{0, 0}, extent};
    ri.layerCount           = 1;
    ri.colorAttachmentCount = 1;
    ri.pColorAttachments    = *att;
    vkCmdBeginRendering(cb, *ri);
    vkCmdEndRendering(cb);
}
