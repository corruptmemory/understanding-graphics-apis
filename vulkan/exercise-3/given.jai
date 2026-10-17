// Exercise 3, given: lesson 2's surface, swapchain, choosers and present loop carried forward as
// finished code, plus the pipeline record and the headless draw the tests use. Read it as a library,
// do not edit it. The learner's part is exercise.jai and the two shaders.

#import "Basic";
#import "Gfx_Test";
#import "Input";
#import "Vulkan";
#import "Window_Creation";
#import "X11";

Swapchain :: struct {
    handle:    VkSwapchainKHR;
    format:    VkFormat;
    extent:    VkExtent2D;
    images:    [] VkImage;       // owned by the presentation engine; we borrow one at a time
    views:     [] VkImageView;   // ours, one per image
    surface:   VkSurfaceKHR;     // kept so present_loop can recreate the swapchain after a resize
    requested: VkExtent2D;       // the window size create_swapchain was given
    vsync:     bool;
}

// Called once per frame by present_loop with the acquired image, already in COLOR_ATTACHMENT_OPTIMAL.
// It appends finished (ended) command buffers to cbs; present_loop submits them in order and frees
// them once the frame's fence says the GPU is done.
Record_Proc :: #type (ctx: *Gfx_Context, image: VkImage, view: VkImageView, extent: VkExtent2D, frame: int, cbs: *[..] VkCommandBuffer);

// The loader makes the surface object from the X11 display and window; no driver is involved yet.
create_surface :: (ctx: *Gfx_Context, window: Window) -> (surface: VkSurfaceKHR, ok: bool) {
    sci: VkXlibSurfaceCreateInfoKHR;
    sci.dpy    = x_global_display;
    sci.window = xx window;
    surface: VkSurfaceKHR;
    result := vkCreateXlibSurfaceKHR(ctx.instance, *sci, null, *surface);
    if result != .SUCCESS {
        log_error("vkCreateXlibSurfaceKHR failed: %", result);
        return null, false;
    }
    supported: VkBool32;
    vkGetPhysicalDeviceSurfaceSupportKHR(ctx.physical_device, ctx.queue_family, surface, *supported);
    if !supported {
        log_error("queue family % cannot present to this surface", ctx.queue_family);
        vkDestroySurfaceKHR(ctx.instance, surface, null);
        return null, false;
    }
    return surface, true;
}

// Query what the surface can do, let the four choosers decide, create the swapchain and its views.
create_swapchain :: (ctx: *Gfx_Context, surface: VkSurfaceKHR, window_w: u32, window_h: u32, vsync: bool) -> (sc: Swapchain, ok: bool) {
    sc: Swapchain;
    sc.surface   = surface;
    sc.requested = .{window_w, window_h};
    sc.vsync     = vsync;

    caps: VkSurfaceCapabilitiesKHR;
    result := vkGetPhysicalDeviceSurfaceCapabilitiesKHR(ctx.physical_device, surface, *caps);
    if result != .SUCCESS {
        log_error("vkGetPhysicalDeviceSurfaceCapabilitiesKHR failed: %", result);
        return sc, false;
    }
    formats, fresult := vkGetPhysicalDeviceSurfaceFormatsKHR(ctx.physical_device, surface);
    defer free(formats.data);
    if fresult != .SUCCESS || formats.count == 0 {
        log_error("vkGetPhysicalDeviceSurfaceFormatsKHR failed: % (% formats)", fresult, formats.count);
        return sc, false;
    }
    modes, mresult := vkGetPhysicalDeviceSurfacePresentModesKHR(ctx.physical_device, surface);
    defer free(modes.data);
    if mresult != .SUCCESS || modes.count == 0 {
        log_error("vkGetPhysicalDeviceSurfacePresentModesKHR failed: % (% modes)", mresult, modes.count);
        return sc, false;
    }

    format := choose_surface_format(formats);
    mode   := choose_present_mode(modes, vsync);
    extent := choose_extent(caps, window_w, window_h);
    count  := choose_image_count(caps);
    if extent.width == 0 || extent.height == 0 || count == 0 {
        log_error("the choosers returned an empty extent (%x%) or zero images (%): is exercise.jai still a stub?", extent.width, extent.height, count);
        return sc, false;
    }
    sc.format = format.format;
    sc.extent = extent;

    sci: VkSwapchainCreateInfoKHR;
    sci.surface          = surface;
    sci.minImageCount    = count;
    sci.imageFormat      = format.format;
    sci.imageColorSpace  = format.colorSpace;
    sci.imageExtent      = extent;
    sci.imageArrayLayers = 1;
    sci.imageUsage       = .COLOR_ATTACHMENT_BIT;
    sci.imageSharingMode = .EXCLUSIVE;
    sci.preTransform     = caps.currentTransform;
    sci.compositeAlpha   = .OPAQUE_BIT_KHR;
    sci.presentMode      = mode;
    sci.clipped          = VK_TRUE;
    result = vkCreateSwapchainKHR(ctx.device, *sci, null, *sc.handle);
    if result != .SUCCESS {
        log_error("vkCreateSwapchainKHR failed: %", result);
        return sc, false;
    }

    images, iresult := vkGetSwapchainImagesKHR(ctx.device, sc.handle);
    if iresult != .SUCCESS {
        log_error("vkGetSwapchainImagesKHR failed: %", iresult);
        destroy_swapchain(ctx, *sc);
        return sc, false;
    }
    sc.images = images;
    sc.views  = NewArray(images.count, VkImageView);
    for sc.images {
        vci: VkImageViewCreateInfo;
        vci.image            = it;
        vci.viewType         = ._2D;
        vci.format           = sc.format;
        vci.subresourceRange = .{.COLOR_BIT, 0, 1, 0, 1};
        result = vkCreateImageView(ctx.device, *vci, null, *sc.views[it_index]);
        if result != .SUCCESS {
            log_error("vkCreateImageView failed on swapchain image %: %", it_index, result);
            destroy_swapchain(ctx, *sc);
            return sc, false;
        }
    }
    return sc, true;
}

destroy_swapchain :: (ctx: *Gfx_Context, sc: *Swapchain) {
    vkDeviceWaitIdle(ctx.device);
    for sc.views  if it  vkDestroyImageView(ctx.device, it, null);
    if sc.handle  vkDestroySwapchainKHR(ctx.device, sc.handle, null);
    free(sc.views.data);
    free(sc.images.data);   // the images themselves belong to the swapchain
    sc.* = .{};
}

// The windowed loop, one frame in flight: wait for last frame's fence, acquire, transition the image
// to COLOR_ATTACHMENT_OPTIMAL, let `record` append its buffers, transition to PRESENT_SRC_KHR, submit
// everything at once, present. Stops after `frames` frames or on a QUIT event. A resize makes the
// swapchain out of date; the loop recreates it from the same surface and carries on. Lesson 5 opens up
// the fence, the semaphores and frames in flight.
//
// Two kinds of semaphore: one `acquired`, reused every frame, because the fence proves last frame's
// submit (which waited on it) is done; and one `done` per swapchain image, because the present that
// waits on it is not covered by the fence, so the only safe time to signal it again is after the
// engine has handed that same image back.
present_loop :: (ctx: *Gfx_Context, sc: *Swapchain, frames: int, record: Record_Proc) {
    NEVER :: 0xffff_ffff_ffff_ffff;

    fci: VkFenceCreateInfo;
    fci.flags = .SIGNALED_BIT;   // so the first wait passes
    fence: VkFence;
    vkCreateFence(ctx.device, *fci, null, *fence);
    semci: VkSemaphoreCreateInfo;
    acquired: VkSemaphore;
    vkCreateSemaphore(ctx.device, *semci, null, *acquired);   // signaled when the image is ours
    done := make_semaphores(ctx, sc.images.count);           // signaled when our rendering of that image is done
    cbs: [..] VkCommandBuffer;

    frame := 0;
    while frame < frames {
        update_window_events();
        quit := false;
        for events_this_frame  if it.type == .QUIT  quit = true;
        if quit  break;

        // Last frame's GPU work must be finished before its buffers are freed and the fence reused.
        vkWaitForFences(ctx.device, 1, *fence, VK_TRUE, NEVER);
        if cbs.count  vkFreeCommandBuffers(ctx.device, ctx.command_pool, xx cbs.count, cbs.data);
        cbs.count = 0;

        index: u32;
        result := vkAcquireNextImageKHR(ctx.device, sc.handle, NEVER, acquired, null, *index);
        if result == .ERROR_OUT_OF_DATE_KHR {
            if !recreate_swapchain(ctx, sc)  break;
            destroy_semaphores(ctx, done);
            done = make_semaphores(ctx, sc.images.count);
            continue;   // nothing was signaled; try again with the new images
        }
        if result != .SUCCESS && result != .SUBOPTIMAL_KHR {
            log_error("vkAcquireNextImageKHR failed: %", result);
            break;
        }
        vkResetFences(ctx.device, 1, *fence);

        pre := begin_commands(ctx);
        transition_image(pre, sc.images[index], .UNDEFINED, .COLOR_ATTACHMENT_OPTIMAL,
                         VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_NONE,
                         VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT);
        vkEndCommandBuffer(pre);
        array_add(*cbs, pre);

        record(ctx, sc.images[index], sc.views[index], sc.extent, frame, *cbs);

        post := begin_commands(ctx);
        transition_image(post, sc.images[index], .COLOR_ATTACHMENT_OPTIMAL, .PRESENT_SRC_KHR,
                         VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
                         VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE);
        vkEndCommandBuffer(post);
        array_add(*cbs, post);

        infos := NewArray(cbs.count, VkCommandBufferSubmitInfo,, temp);
        for cbs  infos[it_index].commandBuffer = it;
        wait: VkSemaphoreSubmitInfo;
        wait.semaphore = acquired;
        wait.stageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;   // the image may be read by the engine until then
        signal: VkSemaphoreSubmitInfo;
        signal.semaphore = done[index];
        signal.stageMask = VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT;
        si: VkSubmitInfo2;
        si.waitSemaphoreInfoCount   = 1;
        si.pWaitSemaphoreInfos      = *wait;
        si.commandBufferInfoCount   = xx cbs.count;
        si.pCommandBufferInfos      = infos.data;
        si.signalSemaphoreInfoCount = 1;
        si.pSignalSemaphoreInfos    = *signal;
        result = vkQueueSubmit2(ctx.queue, 1, *si, fence);
        if result != .SUCCESS {
            log_error("vkQueueSubmit2 failed: %", result);
            break;
        }

        pi: VkPresentInfoKHR;
        pi.waitSemaphoreCount = 1;
        pi.pWaitSemaphores    = *done[index];
        pi.swapchainCount     = 1;
        pi.pSwapchains        = *sc.handle;
        pi.pImageIndices      = *index;
        result = vkQueuePresentKHR(ctx.queue, *pi);
        if result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR {
            if !recreate_swapchain(ctx, sc)  break;
            destroy_semaphores(ctx, done);
            done = make_semaphores(ctx, sc.images.count);
        } else if result != .SUCCESS {
            log_error("vkQueuePresentKHR failed: %", result);
            break;
        }
        frame += 1;
        reset_temporary_storage();
    }

    vkDeviceWaitIdle(ctx.device);
    if cbs.count  vkFreeCommandBuffers(ctx.device, ctx.command_pool, xx cbs.count, cbs.data);
    array_free(cbs);
    vkDestroySemaphore(ctx.device, acquired, null);
    destroy_semaphores(ctx, done);
    vkDestroyFence(ctx.device, fence, null);
}

make_semaphores :: (ctx: *Gfx_Context, count: int) -> [] VkSemaphore {
    semci: VkSemaphoreCreateInfo;
    sems := NewArray(count, VkSemaphore);
    for * sems  vkCreateSemaphore(ctx.device, *semci, null, it);
    return sems;
}

// Only after the device is idle: destroy_swapchain waited, so the presents that used them are over.
destroy_semaphores :: (ctx: *Gfx_Context, sems: [] VkSemaphore) {
    for sems  vkDestroySemaphore(ctx.device, it, null);
    free(sems.data);
}

// After a resize: wait, drop the old swapchain, make a new one from the same surface and choices.
recreate_swapchain :: (ctx: *Gfx_Context, sc: *Swapchain) -> bool {
    surface, requested, vsync := sc.surface, sc.requested, sc.vsync;
    destroy_swapchain(ctx, sc);
    fresh, ok := create_swapchain(ctx, surface, requested.width, requested.height, vsync);
    if !ok {
        log_error("could not recreate the swapchain after a resize");
        return false;
    }
    sc.* = fresh;
    return true;
}

// ---- lesson 2's choices, finished --------------------------------------------------------------

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

// ---- lesson 3 ----------------------------------------------------------------------------------

Pipeline :: struct { layout: VkPipelineLayout; handle: VkPipeline; }

destroy_pipeline :: (ctx: *Gfx_Context, p: *Pipeline) {
    vkDeviceWaitIdle(ctx.device);
    if p.handle  vkDestroyPipeline(ctx.device, p.handle, null);
    if p.layout  vkDestroyPipelineLayout(ctx.device, p.layout, null);
    p.* = .{};
}

// One headless frame: transition the target, record the learner's triangle over a black clear with
// the given viewport, submit, wait, read back.
draw_to_target :: (ctx: *Gfx_Context, t: *Gfx_Target, p: Pipeline, viewport: VkViewport) -> Pixels {
    cb := begin_commands(ctx);
    transition_image(cb, t.image, .UNDEFINED, .COLOR_ATTACHMENT_OPTIMAL,
                     VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                     VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT);
    record_triangle(cb, t.view, .{t.width, t.height}, p, viewport, .[0.0, 0.0, 0.0, 1.0]);
    submit_and_wait(ctx, cb);
    return readback(ctx, t, .COLOR_ATTACHMENT_OPTIMAL);
}
