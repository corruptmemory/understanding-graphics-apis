// Self-check for the Gfx_Test harness. Run with: first.jai - test vulkan/harness-check

#import "Basic";
#import "File_Utilities";
#import "Gfx_Test";
#import "Vulkan";
#import "Window_Creation";
#import "X11";

// ---- pure functions ------------------------------------------------------------------

choose_discrete_over_integrated :: (ctx: *Gfx_Context) -> bool {
    c := Device_Candidate.[
        .{0, .INTEGRATED_GPU, VK_API_VERSION_1_3, "igpu"},
        .{1, .DISCRETE_GPU,   VK_API_VERSION_1_3, "dgpu"},
    ];
    return choose_physical_device(c) == 1;
}

choose_first_capable_without_discrete :: (ctx: *Gfx_Context) -> bool {
    c := Device_Candidate.[
        .{0, .INTEGRATED_GPU, VK_API_VERSION_1_2, "old"},
        .{1, .INTEGRATED_GPU, VK_API_VERSION_1_3, "new"},
        .{2, .CPU,            VK_API_VERSION_1_4, "llvmpipe"},
    ];
    return choose_physical_device(c) == 1;
}

choose_none_when_nothing_is_1_3 :: (ctx: *Gfx_Context) -> bool {
    c := Device_Candidate.[ .{0, .DISCRETE_GPU, VK_API_VERSION_1_2, "old"} ];
    return choose_physical_device(c) == -1;
}

memory_type_table :: (ctx: *Gfx_Context) -> bool {
    props: VkPhysicalDeviceMemoryProperties;
    props.memoryTypeCount = 3;
    props.memoryTypes[0].propertyFlags = .DEVICE_LOCAL_BIT;
    props.memoryTypes[1].propertyFlags = .HOST_VISIBLE_BIT;
    props.memoryTypes[2].propertyFlags = .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT;

    i, ok := find_memory_type(props, 0b111, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT);
    if !(ok && i == 2) return false;
    i, ok = find_memory_type(props, 0b001, .HOST_VISIBLE_BIT);     // bit mask excludes the matches
    if ok return false;
    i, ok = find_memory_type(props, 0b110, .HOST_VISIBLE_BIT);     // first match wins
    return ok && i == 1;
}

// ---- the real device ------------------------------------------------------------------

device_comes_up_with_1_3_features :: (ctx: *Gfx_Context) -> bool {
    f13: VkPhysicalDeviceVulkan13Features;
    f2:  VkPhysicalDeviceFeatures2;
    f2.pNext = *f13;
    vkGetPhysicalDeviceFeatures2(ctx.physical_device, *f2);
    return f13.dynamicRendering != 0 && f13.synchronization2 != 0 && ctx.queue != null && ctx.device_name.count > 0;
}

validation_error_is_recorded :: (ctx: *Gfx_Context) -> bool {
    // vkEndCommandBuffer on a buffer that was never begun is a validation error.
    ai: VkCommandBufferAllocateInfo;
    ai.commandPool = ctx.command_pool; ai.level = .PRIMARY; ai.commandBufferCount = 1;
    cb: VkCommandBuffer;
    vkAllocateCommandBuffers(ctx.device, *ai, *cb);
    vkEndCommandBuffer(cb);
    return ctx.recorder.errors == 1 && ctx.recorder.messages.count >= 1;
}

// The loader announces every implicit layer the test runner disabled; those notices are not
// validation warnings and must not count as such, or warnings_fatal is unusable on a desktop
// with overlays installed.
fresh_context_has_no_warnings :: (ctx: *Gfx_Context) -> bool {
    return ctx.recorder.warnings == 0 && ctx.recorder.messages.count == 0;
}

missing_layer_is_reported :: (ctx: *Gfx_Context) -> bool {
    other := gfx_init(.{layer_name = "VK_LAYER_DOES_NOT_EXIST"});
    return other == null;   // and the run shows a log_error naming VK_LAYER_DOES_NOT_EXIST
}

// ---- offscreen target, readback, pixel assertions, PNG ------------------------------

clear_color_reads_back :: (ctx: *Gfx_Context) -> bool {
    t := create_target(ctx, 64, 64);
    defer destroy_target(ctx, *t);
    cb := begin_commands(ctx);
    transition_image(cb, t.image, .UNDEFINED, .COLOR_ATTACHMENT_OPTIMAL,
                     VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                     VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT);
    att: VkRenderingAttachmentInfo;
    att.imageView = t.view; att.imageLayout = .COLOR_ATTACHMENT_OPTIMAL;
    att.loadOp = .CLEAR; att.storeOp = .STORE;
    att.clearValue.color._float32 = .[0.25, 0.5, 0.75, 1.0];
    ri: VkRenderingInfo;
    ri.renderArea = .{.{0, 0}, .{64, 64}}; ri.layerCount = 1;
    ri.colorAttachmentCount = 1; ri.pColorAttachments = *att;
    vkCmdBeginRendering(cb, *ri);
    vkCmdEndRendering(cb);
    submit_and_wait(ctx, cb);
    p := readback(ctx, *t, .COLOR_ATTACHMENT_OPTIMAL);
    return expect_pixel(p, 32, 32, 64, 128, 191, 255) && expect_region_solid(p, 0, 0, 64, 64, 64, 128, 191, 255);
}

expect_pixel_out_of_range_fails_cleanly :: (ctx: *Gfx_Context) -> bool {
    p: Pixels; p.width = 2; p.height = 2; p.rgba = NewArray(16, u8);
    r, g, b, a, ok := pixel_at(p, 2, 0);
    return !ok && !expect_pixel(p, 2, 0, 0, 0, 0, 0);
}

capture_creates_parent_directory :: (ctx: *Gfx_Context) -> bool {
    p: Pixels; p.width = 2; p.height = 2; p.rgba = NewArray(16, u8);
    path := "build/capture-check/nested/out.png";
    return save_png(p, path) && file_exists(path);
}

// ---- the shader path and the X11 surface -------------------------------------------

CHECK_VERT :: #run load_spirv(tprint("%.build/spv/check.vert.spv", #filepath));

shader_module_from_glslc_output :: (ctx: *Gfx_Context) -> bool {
    ci: VkShaderModuleCreateInfo;
    ci.codeSize = xx (CHECK_VERT.count * 4);
    ci.pCode    = CHECK_VERT.data;
    m: VkShaderModule;
    if vkCreateShaderModule(ctx.device, *ci, null, *m) != .SUCCESS return false;
    vkDestroyShaderModule(ctx.device, m, null);
    return CHECK_VERT[0] == 0x07230203;
}

xlib_surface_is_presentable :: (ctx: *Gfx_Context) -> bool {
    win := create_window(160, 120, "harness-check");
    sci: VkXlibSurfaceCreateInfoKHR;
    sci.dpy = x_global_display; sci.window = xx win;
    surface: VkSurfaceKHR;
    if vkCreateXlibSurfaceKHR(ctx.instance, *sci, null, *surface) != .SUCCESS return false;
    defer vkDestroySurfaceKHR(ctx.instance, surface, null);
    ok: VkBool32;
    vkGetPhysicalDeviceSurfaceSupportKHR(ctx.physical_device, ctx.queue_family, surface, *ok);
    return ok != 0;
}

CASES :: Test_Case.[
    .{name = "choose_discrete_over_integrated",       proc = choose_discrete_over_integrated},
    .{name = "choose_first_capable_without_discrete", proc = choose_first_capable_without_discrete},
    .{name = "choose_none_when_nothing_is_1_3",       proc = choose_none_when_nothing_is_1_3},
    .{name = "memory_type_table",                     proc = memory_type_table},
    .{name = "device_comes_up_with_1_3_features",     proc = device_comes_up_with_1_3_features},
    .{name = "validation_error_is_recorded",          proc = validation_error_is_recorded, expect_validation_errors = 1},
    .{name = "fresh_context_has_no_warnings",         proc = fresh_context_has_no_warnings, warnings_fatal = true},
    .{name = "missing_layer_is_reported",             proc = missing_layer_is_reported},
    .{name = "clear_color_reads_back",                proc = clear_color_reads_back},
    .{name = "expect_pixel_out_of_range_fails_cleanly", proc = expect_pixel_out_of_range_fails_cleanly},
    .{name = "capture_creates_parent_directory",      proc = capture_creates_parent_directory},
    .{name = "shader_module_from_glslc_output",       proc = shader_module_from_glslc_output},
    .{name = "xlib_surface_is_presentable",           proc = xlib_surface_is_presentable, needs_display = true},
];

main :: () { exit(run_tests(CASES, get_command_line_arguments())); }
