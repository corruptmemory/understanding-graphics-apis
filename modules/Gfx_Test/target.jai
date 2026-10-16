// Offscreen colour targets, one-shot command buffers, layout transitions, readback into
// host memory, pixel assertions, and PNG output. Everything an exercise test needs to
// render without a window and check what it drew.

Gfx_Target :: struct {
    width, height:   u32;
    format:          VkFormat;
    image:           VkImage;
    memory:          VkDeviceMemory;
    view:            VkImageView;
    readback_buffer: VkBuffer;
    readback_memory: VkDeviceMemory;
}

// Tightly packed RGBA8, row-major, top-left first.
Pixels :: struct {
    width, height: int;
    rgba:          [] u8;
}

// A colour attachment the GPU can render to and that readback can copy from, plus a
// host-visible buffer sized for one RGBA8 copy. Formats other than 4-byte ones are not
// supported by readback yet.
create_target :: (ctx: *Gfx_Context, width: u32, height: u32, format := VkFormat.R8G8B8A8_UNORM) -> Gfx_Target {
    t: Gfx_Target;
    t.width  = width;
    t.height = height;
    t.format = format;

    ici: VkImageCreateInfo;
    ici.imageType     = ._2D;
    ici.format        = format;
    ici.extent        = .{width, height, 1};
    ici.mipLevels     = 1;
    ici.arrayLayers   = 1;
    ici.samples       = ._1_BIT;
    ici.tiling        = .OPTIMAL;
    ici.usage         = .COLOR_ATTACHMENT_BIT | .TRANSFER_SRC_BIT;
    ici.sharingMode   = .EXCLUSIVE;
    ici.initialLayout = .UNDEFINED;
    check(vkCreateImage(ctx.device, *ici, null, *t.image), "vkCreateImage");

    t.memory = allocate_for_image(ctx, t.image, .DEVICE_LOCAL_BIT);
    check(vkBindImageMemory(ctx.device, t.image, t.memory, 0), "vkBindImageMemory");

    vci: VkImageViewCreateInfo;
    vci.image            = t.image;
    vci.viewType         = ._2D;
    vci.format           = format;
    vci.subresourceRange = .{.COLOR_BIT, 0, 1, 0, 1};
    check(vkCreateImageView(ctx.device, *vci, null, *t.view), "vkCreateImageView");

    bci: VkBufferCreateInfo;
    bci.size        = width * height * 4;
    bci.usage       = .TRANSFER_DST_BIT;
    bci.sharingMode = .EXCLUSIVE;
    check(vkCreateBuffer(ctx.device, *bci, null, *t.readback_buffer), "vkCreateBuffer");

    t.readback_memory = allocate_for_buffer(ctx, t.readback_buffer, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT);
    check(vkBindBufferMemory(ctx.device, t.readback_buffer, t.readback_memory, 0), "vkBindBufferMemory");

    return t;
}

destroy_target :: (ctx: *Gfx_Context, target: *Gfx_Target) {
    vkDeviceWaitIdle(ctx.device);
    if target.readback_buffer  vkDestroyBuffer(ctx.device, target.readback_buffer, null);
    if target.readback_memory  vkFreeMemory(ctx.device, target.readback_memory, null);
    if target.view             vkDestroyImageView(ctx.device, target.view, null);
    if target.image            vkDestroyImage(ctx.device, target.image, null);
    if target.memory           vkFreeMemory(ctx.device, target.memory, null);
    target.* = .{};
}

// A primary command buffer from the context's pool, already begun for one submission.
begin_commands :: (ctx: *Gfx_Context) -> VkCommandBuffer {
    ai: VkCommandBufferAllocateInfo;
    ai.commandPool        = ctx.command_pool;
    ai.level              = .PRIMARY;
    ai.commandBufferCount = 1;
    cb: VkCommandBuffer;
    check(vkAllocateCommandBuffers(ctx.device, *ai, *cb), "vkAllocateCommandBuffers");

    bi: VkCommandBufferBeginInfo;
    bi.flags = .ONE_TIME_SUBMIT_BIT;
    check(vkBeginCommandBuffer(cb, *bi), "vkBeginCommandBuffer");
    return cb;
}

// End, submit on the context's queue, block until the GPU is done, free the buffer.
submit_and_wait :: (ctx: *Gfx_Context, cb: VkCommandBuffer) {
    check(vkEndCommandBuffer(cb), "vkEndCommandBuffer");

    fci: VkFenceCreateInfo;
    fence: VkFence;
    check(vkCreateFence(ctx.device, *fci, null, *fence), "vkCreateFence");

    cbsi: VkCommandBufferSubmitInfo;
    cbsi.commandBuffer = cb;
    si: VkSubmitInfo2;
    si.commandBufferInfoCount = 1;
    si.pCommandBufferInfos    = *cbsi;
    check(vkQueueSubmit2(ctx.queue, 1, *si, fence), "vkQueueSubmit2");
    check(vkWaitForFences(ctx.device, 1, *fence, VK_TRUE, 0xffff_ffff_ffff_ffff), "vkWaitForFences");

    vkDestroyFence(ctx.device, fence, null);
    vkFreeCommandBuffers(ctx.device, ctx.command_pool, 1, *cb);
}

// One image barrier over the colour aspect, every mip and layer.
transition_image :: (cb: VkCommandBuffer, image: VkImage,
                     old_layout: VkImageLayout, new_layout: VkImageLayout,
                     src_stage: VkPipelineStageFlags2, src_access: VkAccessFlags2,
                     dst_stage: VkPipelineStageFlags2, dst_access: VkAccessFlags2) {
    b: VkImageMemoryBarrier2;
    b.srcStageMask        = src_stage;
    b.srcAccessMask       = src_access;
    b.dstStageMask        = dst_stage;
    b.dstAccessMask       = dst_access;
    b.oldLayout           = old_layout;
    b.newLayout           = new_layout;
    b.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    b.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    b.image               = image;
    b.subresourceRange    = .{.COLOR_BIT, 0, VK_REMAINING_MIP_LEVELS, 0, VK_REMAINING_ARRAY_LAYERS};

    dep: VkDependencyInfo;
    dep.imageMemoryBarrierCount = 1;
    dep.pImageMemoryBarriers    = *b;
    vkCmdPipelineBarrier2(cb, *dep);
}

// Copy the target's image into host memory. The image is transitioned from current_layout
// to TRANSFER_SRC_OPTIMAL and left there. When capture_path is set, the pixels are also
// written to that PNG (the last readback of a run wins).
readback :: (ctx: *Gfx_Context, target: *Gfx_Target, current_layout: VkImageLayout) -> Pixels {
    cb := begin_commands(ctx);
    transition_image(cb, target.image, current_layout, .TRANSFER_SRC_OPTIMAL,
                     VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, VK_ACCESS_2_MEMORY_WRITE_BIT,
                     VK_PIPELINE_STAGE_2_TRANSFER_BIT, VK_ACCESS_2_TRANSFER_READ_BIT);

    region: VkBufferImageCopy;
    region.imageSubresource = .{.COLOR_BIT, 0, 0, 1};
    region.imageExtent      = .{target.width, target.height, 1};
    vkCmdCopyImageToBuffer(cb, target.image, .TRANSFER_SRC_OPTIMAL, target.readback_buffer, 1, *region);

    // Make the transfer's writes visible to the host before the fence wait returns.
    hb: VkBufferMemoryBarrier2;
    hb.srcStageMask        = VK_PIPELINE_STAGE_2_TRANSFER_BIT;
    hb.srcAccessMask       = VK_ACCESS_2_TRANSFER_WRITE_BIT;
    hb.dstStageMask        = VK_PIPELINE_STAGE_2_HOST_BIT;
    hb.dstAccessMask       = VK_ACCESS_2_HOST_READ_BIT;
    hb.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    hb.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    hb.buffer              = target.readback_buffer;
    hb.size                = VK_WHOLE_SIZE;
    dep: VkDependencyInfo;
    dep.bufferMemoryBarrierCount = 1;
    dep.pBufferMemoryBarriers    = *hb;
    vkCmdPipelineBarrier2(cb, *dep);

    submit_and_wait(ctx, cb);

    p: Pixels;
    p.width  = target.width;
    p.height = target.height;
    p.rgba   = NewArray(p.width * p.height * 4, u8);

    mapped: *void;
    check(vkMapMemory(ctx.device, target.readback_memory, 0, VK_WHOLE_SIZE, 0, *mapped), "vkMapMemory");
    memcpy(p.rgba.data, mapped, p.rgba.count);
    vkUnmapMemory(ctx.device, target.readback_memory);

    if capture_path.count > 0  save_png(p, capture_path);
    return p;
}

pixel_at :: (p: Pixels, x: int, y: int) -> (r: u8, g: u8, b: u8, a: u8, ok: bool) {
    if x < 0 || y < 0 || x >= p.width || y >= p.height  return 0, 0, 0, 0, false;
    i := (y * p.width + x) * 4;
    return p.rgba[i], p.rgba[i + 1], p.rgba[i + 2], p.rgba[i + 3], true;
}

expect_pixel :: (p: Pixels, x: int, y: int, r: u8, g: u8, b: u8, a: u8, tolerance := 1, loc := #caller_location) -> bool {
    pr, pg, pb, pa, ok := pixel_at(p, x, y);
    if !ok {
        print("expect failed at %:%: pixel (%,%) out of range for a %x% image\n", loc.fully_pathed_filename, loc.line_number, x, y, p.width, p.height);
        return false;
    }
    if within(pr, r, tolerance) && within(pg, g, tolerance) && within(pb, b, tolerance) && within(pa, a, tolerance)  return true;
    print("expect failed at %:%: pixel (%,%) = (%,%,%,%), wanted (%,%,%,%) ±%\n",
          loc.fully_pathed_filename, loc.line_number, x, y, pr, pg, pb, pa, r, g, b, a, tolerance);
    return false;
}

// Every pixel in [x0,x1) × [y0,y1) matches; reports the first that does not.
expect_region_solid :: (p: Pixels, x0: int, y0: int, x1: int, y1: int, r: u8, g: u8, b: u8, a: u8, tolerance := 1, loc := #caller_location) -> bool {
    for y: y0..y1-1  for x: x0..x1-1 {
        if !expect_pixel(p, x, y, r, g, b, a, tolerance, loc)  return false;
    }
    return true;
}

// Writes an RGBA8 PNG, creating the parent directory first.
save_png :: (p: Pixels, path: string) -> bool {
    dir := path_strip_filename(path);
    if dir.count > 0 && !make_directory_if_it_does_not_exist(dir, recursive = true) {
        log_error("save_png: could not create directory '%' for '%'", dir, path);
        return false;
    }
    c_path := to_c_string(path);
    defer free(c_path);
    if stbi_write_png(c_path, xx p.width, xx p.height, 4, p.rgba.data, xx (p.width * 4)) == 0 {
        log_error("save_png: stbi_write_png failed for '%'", path);
        return false;
    }
    return true;
}

#scope_file

within :: (got: u8, want: u8, tolerance: int) -> bool {
    d := cast(int) got - cast(int) want;
    return d >= -tolerance && d <= tolerance;
}

check :: (result: VkResult, what: string, loc := #caller_location) {
    if result != .SUCCESS  log_error("% failed with % (%:%)", what, result, loc.fully_pathed_filename, loc.line_number);
}

allocate_for_image :: (ctx: *Gfx_Context, image: VkImage, wanted: VkMemoryPropertyFlags) -> VkDeviceMemory {
    req: VkMemoryRequirements;
    vkGetImageMemoryRequirements(ctx.device, image, *req);
    return allocate(ctx, req, wanted);
}

allocate_for_buffer :: (ctx: *Gfx_Context, buffer: VkBuffer, wanted: VkMemoryPropertyFlags) -> VkDeviceMemory {
    req: VkMemoryRequirements;
    vkGetBufferMemoryRequirements(ctx.device, buffer, *req);
    return allocate(ctx, req, wanted);
}

allocate :: (ctx: *Gfx_Context, req: VkMemoryRequirements, wanted: VkMemoryPropertyFlags) -> VkDeviceMemory {
    props: VkPhysicalDeviceMemoryProperties;
    vkGetPhysicalDeviceMemoryProperties(ctx.physical_device, *props);
    index, ok := find_memory_type(props, req.memoryTypeBits, wanted);
    if !ok {
        log_error("No memory type satisfies bits % with properties %", req.memoryTypeBits, wanted);
        return null;
    }
    ai: VkMemoryAllocateInfo;
    ai.allocationSize  = req.size;
    ai.memoryTypeIndex = index;
    memory: VkDeviceMemory;
    check(vkAllocateMemory(ctx.device, *ai, null, *memory), "vkAllocateMemory");
    return memory;
}
