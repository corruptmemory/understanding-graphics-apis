// Exercise 4, reference solution: a command buffer's whole life, a draw list, and an ordered submit.

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

// One PRIMARY buffer from the context's pool, begun for a single submission.
begin_buffer :: (ctx: *Gfx_Context) -> VkCommandBuffer {
    ai: VkCommandBufferAllocateInfo;
    ai.commandPool        = ctx.command_pool;
    ai.level              = .PRIMARY;
    ai.commandBufferCount = 1;
    cb: VkCommandBuffer;
    result := vkAllocateCommandBuffers(ctx.device, *ai, *cb);
    if result != .SUCCESS {
        log_error("vkAllocateCommandBuffers failed: %", result);
        return null;
    }
    bi: VkCommandBufferBeginInfo;
    bi.flags = .ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(cb, *bi);
    return cb;
}

// One render instance: clear or load, then every draw in the list in order, then end the buffer.
record_scene :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, p: Pipeline, draws: [] int, clear: bool) {
    att: VkRenderingAttachmentInfo;
    att.imageView   = view;
    att.imageLayout = .COLOR_ATTACHMENT_OPTIMAL;
    att.loadOp      = ifx clear then VkAttachmentLoadOp.CLEAR else .LOAD;
    att.storeOp     = .STORE;
    att.clearValue.color._float32 = .[0.0, 0.0, 0.0, 1.0];
    ri: VkRenderingInfo;
    ri.renderArea           = .{.{0, 0}, extent};
    ri.layerCount           = 1;
    ri.colorAttachmentCount = 1;
    ri.pColorAttachments    = *att;
    vkCmdBeginRendering(cb, *ri);

    vkCmdBindPipeline(cb, .GRAPHICS, p.handle);
    viewport := VkViewport.{0, 0, xx extent.width, xx extent.height, 0, 1};
    vkCmdSetViewport(cb, 0, 1, *viewport);
    scissor := VkRect2D.{.{0, 0}, extent};
    vkCmdSetScissor(cb, 0, 1, *scissor);
    for draws  vkCmdDraw(cb, 3, 1, xx (3 * it), 0);   // triangle `it` of the table

    vkCmdEndRendering(cb);
    vkEndCommandBuffer(cb);
}

// Every buffer in one submit, in order; wait for the fence; free the buffers.
submit_ordered :: (ctx: *Gfx_Context, cbs: [] VkCommandBuffer) {
    infos := NewArray(cbs.count, VkCommandBufferSubmitInfo,, temp);
    for cbs  infos[it_index].commandBuffer = it;
    si: VkSubmitInfo2;
    si.commandBufferInfoCount = xx cbs.count;
    si.pCommandBufferInfos    = infos.data;

    fci: VkFenceCreateInfo;
    fence: VkFence;
    vkCreateFence(ctx.device, *fci, null, *fence);
    result := vkQueueSubmit2(ctx.queue, 1, *si, fence);
    if result != .SUCCESS  log_error("vkQueueSubmit2 failed: %", result);
    else                   vkWaitForFences(ctx.device, 1, *fence, VK_TRUE, 0xffff_ffff_ffff_ffff);
    vkDestroyFence(ctx.device, fence, null);
    vkFreeCommandBuffers(ctx.device, ctx.command_pool, xx cbs.count, cbs.data);
}
