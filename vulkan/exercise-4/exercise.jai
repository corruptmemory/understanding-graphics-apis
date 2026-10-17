// Exercise 4: your part. Fill in the three procedures; their signatures are fixed and cases.jai
// checks them. The contract is in README.md; the mechanism is in lesson 4.

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

// Allocate one PRIMARY command buffer from ctx.command_pool and begin it with ONE_TIME_SUBMIT_BIT.
// null after a log_error when allocation fails.
begin_buffer :: (ctx: *Gfx_Context) -> VkCommandBuffer {
    // TODO (lesson 4, step 1): the pool hands out driver-owned memory; begin resets it.
    return null;
}

// Begin rendering over `extent` with loadOp CLEAR to black when `clear` and LOAD otherwise, storeOp
// STORE; bind p; full viewport and scissor; one vkCmdDraw(cb, 3, 1, 3 * draws[i], 0) per entry, in
// order; end rendering; vkEndCommandBuffer.
record_scene :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, p: Pipeline, draws: [] int, clear: bool) {
    // TODO (lesson 4, steps 2 and 3): every vkCmd* call appends the driver's packets, now.
}

// One vkQueueSubmit2 carrying every buffer in order through VkCommandBufferSubmitInfo entries, with
// a fence; vkWaitForFences; destroy the fence; free the buffers.
submit_ordered :: (ctx: *Gfx_Context, cbs: [] VkCommandBuffer) {
    // TODO (lesson 4, step 4): submit is an ioctl naming the buffers, not a translation.
}
