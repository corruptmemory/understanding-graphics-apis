// Project 1: your part. The three procedures below are the contract; README.md says what the scene
// must contain and RUBRIC.md how it is graded. given.jai carries lessons 2 to 4 as finished code:
// create_shape_pipeline, prepare_target, attachment_barrier, submit_and_wait_all, present_loop.

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

// Compiled by first.jai from shaders/shapes.vert and shapes.frag before every build.
SHAPES_VERT :: #run load_spirv(tprint("%.build/spv/shapes.vert.spv", #filepath));
SHAPES_FRAG :: #run load_spirv(tprint("%.build/spv/shapes.frag.spv", #filepath));

// Add what else the scene needs: the view the static buffer was recorded for (or a table of static
// buffers per view), the swapchain_generation it was recorded under, the last extent, ...
Scene :: struct {
    pipeline:   Pipeline;
    static_cb:  VkCommandBuffer;   // recorded once, submitted every frame (begin without ONE_TIME_SUBMIT_BIT)
    dynamic_cb: VkCommandBuffer;   // re-recorded every frame
}

// Create the pipeline (create_shape_pipeline with SHAPES_VERT and SHAPES_FRAG) and allocate the
// buffers from ctx.command_pool. The static buffer may be recorded here or on first use; the view
// and the extent only arrive with the first scene_record, so "on first use" is the easier choice.
scene_init :: (ctx: *Gfx_Context, color_format: VkFormat) -> (scene: Scene, ok: bool) {
    // TODO
    return .{}, false;
}

// Append at least two finished (ended) buffers to cbs, in the order they must run: the static one,
// then the per-frame one re-recorded for this frame, with something in it that moves with `frame`.
// The image is already in COLOR_ATTACHMENT_OPTIMAL. The first buffer clears, the second loads and
// starts with attachment_barrier(cb, image). present_loop (and the tests) have waited for last
// frame's fence before calling this, so re-recording the dynamic buffer is safe. When
// swapchain_generation differs from the one your static buffer was recorded under, the window was
// resized and every view is new: free and re-record it before appending it.
scene_record :: (ctx: *Gfx_Context, scene: *Scene, image: VkImage, view: VkImageView, extent: VkExtent2D, frame: int, cbs: *[..] VkCommandBuffer) {
    // TODO
}

// Free the buffers (vkFreeCommandBuffers on ctx.command_pool), destroy the pipeline.
scene_destroy :: (ctx: *Gfx_Context, scene: *Scene) {
    // TODO
}
