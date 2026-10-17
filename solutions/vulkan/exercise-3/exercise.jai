// Exercise 3, reference solution: a graphics pipeline from two shader modules, with the winding and
// the cull mode as parameters, and a draw with a dynamic viewport.

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

TRI_VERT :: #run load_spirv(tprint("%.build/spv/tri.vert.spv", #filepath));
TRI_FRAG :: #run load_spirv(tprint("%.build/spv/tri.frag.spv", #filepath));

// A shader module is a copy of the SPIR-V words; the driver compiles nothing here.
shader_module :: (ctx: *Gfx_Context, words: [] u32) -> VkShaderModule {
    ci: VkShaderModuleCreateInfo;
    ci.codeSize = xx (words.count * 4);
    ci.pCode    = words.data;
    m: VkShaderModule;
    result := vkCreateShaderModule(ctx.device, *ci, null, *m);
    if result != .SUCCESS  log_error("vkCreateShaderModule failed: %", result);
    return m;
}

create_pipeline :: (ctx: *Gfx_Context, color_format: VkFormat, front_face: VkFrontFace, cull: VkCullModeFlags) -> (p: Pipeline, ok: bool) {
    p: Pipeline;

    vert := shader_module(ctx, TRI_VERT);
    frag := shader_module(ctx, TRI_FRAG);
    defer vkDestroyShaderModule(ctx.device, vert, null);   // the pipeline keeps its own compiled code
    defer vkDestroyShaderModule(ctx.device, frag, null);
    if !vert || !frag  return .{}, false;

    stages: [2] VkPipelineShaderStageCreateInfo;
    stages[0].stage  = .VERTEX_BIT;
    stages[0].module = vert;
    stages[0].pName  = "main";
    stages[1].stage  = .FRAGMENT_BIT;
    stages[1].module = frag;
    stages[1].pName  = "main";

    vertex_input:   VkPipelineVertexInputStateCreateInfo;     // no buffers: the corners live in the shader
    input_assembly: VkPipelineInputAssemblyStateCreateInfo;
    input_assembly.topology = .TRIANGLE_LIST;

    viewport_state: VkPipelineViewportStateCreateInfo;        // counts only; the values are dynamic
    viewport_state.viewportCount = 1;
    viewport_state.scissorCount  = 1;

    raster: VkPipelineRasterizationStateCreateInfo;
    raster.polygonMode = .FILL;
    raster.cullMode    = cull;
    raster.frontFace   = front_face;
    raster.lineWidth   = 1.0;

    multisample: VkPipelineMultisampleStateCreateInfo;
    multisample.rasterizationSamples = ._1_BIT;

    blend_attachment: VkPipelineColorBlendAttachmentState;    // blending off, every channel written
    blend_attachment.colorWriteMask = .R_BIT | .G_BIT | .B_BIT | .A_BIT;
    blend: VkPipelineColorBlendStateCreateInfo;
    blend.attachmentCount = 1;
    blend.pAttachments    = *blend_attachment;

    dynamic_states := VkDynamicState.[.VIEWPORT, .SCISSOR];
    dynamic: VkPipelineDynamicStateCreateInfo;
    dynamic.dynamicStateCount = dynamic_states.count;
    dynamic.pDynamicStates    = dynamic_states.data;

    format := color_format;
    rendering: VkPipelineRenderingCreateInfo;                 // dynamic rendering: the format stands in for a render pass
    rendering.colorAttachmentCount    = 1;
    rendering.pColorAttachmentFormats = *format;

    layout_info: VkPipelineLayoutCreateInfo;                  // nothing bound yet: lesson 7 fills this
    result := vkCreatePipelineLayout(ctx.device, *layout_info, null, *p.layout);
    if result != .SUCCESS {
        log_error("vkCreatePipelineLayout failed: %", result);
        return .{}, false;
    }

    gpci: VkGraphicsPipelineCreateInfo;
    gpci.pNext               = *rendering;
    gpci.stageCount          = stages.count;
    gpci.pStages             = stages.data;
    gpci.pVertexInputState   = *vertex_input;
    gpci.pInputAssemblyState = *input_assembly;
    gpci.pViewportState      = *viewport_state;
    gpci.pRasterizationState = *raster;
    gpci.pMultisampleState   = *multisample;
    gpci.pColorBlendState    = *blend;
    gpci.pDynamicState       = *dynamic;
    gpci.layout              = p.layout;
    gpci.renderPass          = null;
    result = vkCreateGraphicsPipelines(ctx.device, null, 1, *gpci, null, *p.handle);
    if result != .SUCCESS {
        log_error("vkCreateGraphicsPipelines failed: %", result);
        vkDestroyPipelineLayout(ctx.device, p.layout, null);
        return .{}, false;
    }
    return p, true;
}

record_triangle :: (cb: VkCommandBuffer, view: VkImageView, extent: VkExtent2D, p: Pipeline, viewport: VkViewport, clear: [4] float) {
    att: VkRenderingAttachmentInfo;
    att.imageView   = view;
    att.imageLayout = .COLOR_ATTACHMENT_OPTIMAL;
    att.loadOp      = .CLEAR;
    att.storeOp     = .STORE;
    att.clearValue.color._float32 = clear;
    ri: VkRenderingInfo;
    ri.renderArea           = .{.{0, 0}, extent};
    ri.layerCount           = 1;
    ri.colorAttachmentCount = 1;
    ri.pColorAttachments    = *att;
    vkCmdBeginRendering(cb, *ri);

    vkCmdBindPipeline(cb, .GRAPHICS, p.handle);
    vp := viewport;
    vkCmdSetViewport(cb, 0, 1, *vp);
    scissor := VkRect2D.{.{0, 0}, extent};
    vkCmdSetScissor(cb, 0, 1, *scissor);
    vkCmdDraw(cb, 3, 1, 0, 0);

    vkCmdEndRendering(cb);
}
