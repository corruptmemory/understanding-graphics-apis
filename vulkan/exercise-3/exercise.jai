// Exercise 3: your part. Fill in the two procedures and the two shaders under shaders/; the
// signatures are fixed and cases.jai checks them. The contract is in README.md; the mechanism is in
// lesson 3.

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

// The SPIR-V words glslc produced from shaders/tri.vert and tri.frag, baked into the binary at
// compile time. `first.jai` compiles the shaders before building this file.
TRI_VERT :: #run load_spirv(tprint("%.build/spv/tri.vert.spv", #filepath));
TRI_FRAG :: #run load_spirv(tprint("%.build/spv/tri.frag.spv", #filepath));

// Two stages from TRI_VERT and TRI_FRAG, no vertex input, a triangle list, dynamic viewport and
// scissor, polygon FILL with the given cull mode and front face, one sample, one color attachment
// with blending off, an empty layout, and VkPipelineRenderingCreateInfo naming color_format.
// false after a log_error when creation fails.
create_pipeline :: (ctx: *Gfx_Context, color_format: VkFormat, front_face: VkFrontFace, cull: VkCullModeFlags) -> (p: Pipeline, ok: bool) {
    // TODO (lesson 3, steps 2 and 3): vkCreateShaderModule copies words; vkCreateGraphicsPipelines compiles them.
    return .{}, false;
}

// Begin rendering over `extent` with loadOp CLEAR to `clear` and storeOp STORE, bind p, set the
// viewport, scissor the whole extent, draw three vertices, end rendering.
record_triangle :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, p: Pipeline, viewport: VkViewport, clear: [4] float) {
    // TODO (lesson 3, steps 4 and 5): the viewport is dynamic state; the winding is baked.
}
