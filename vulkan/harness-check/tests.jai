// Self-check for the Gfx_Test harness. Run with: first.jai - test vulkan/harness-check

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

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

CASES :: Test_Case.[
    .{name = "choose_discrete_over_integrated",       proc = choose_discrete_over_integrated},
    .{name = "choose_first_capable_without_discrete", proc = choose_first_capable_without_discrete},
    .{name = "choose_none_when_nothing_is_1_3",       proc = choose_none_when_nothing_is_1_3},
    .{name = "memory_type_table",                     proc = memory_type_table},
    .{name = "device_comes_up_with_1_3_features",     proc = device_comes_up_with_1_3_features},
    .{name = "validation_error_is_recorded",          proc = validation_error_is_recorded, expect_validation_errors = 1},
    .{name = "fresh_context_has_no_warnings",         proc = fresh_context_has_no_warnings, warnings_fatal = true},
    .{name = "missing_layer_is_reported",             proc = missing_layer_is_reported},
];

main :: () { exit(run_tests(CASES, get_command_line_arguments())); }
