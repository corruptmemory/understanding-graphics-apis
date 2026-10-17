// Exercise 2: the test cases. tests.jai loads them with the stubs; the solution's tests.jai loads
// them with the solution. Run with: first.jai - test vulkan/exercise-2

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";
#import "Window_Creation";

sf :: (format: VkFormat, space: VkColorSpaceKHR) -> VkSurfaceFormatKHR { return .{format, space}; }

surface_format_prefers_bgra_srgb :: (ctx: *Gfx_Context) -> bool {
    formats := VkSurfaceFormatKHR.[sf(.R8G8B8A8_UNORM, .COLOR_SPACE_SRGB_NONLINEAR_KHR), sf(.B8G8R8A8_SRGB, .COLOR_SPACE_SRGB_NONLINEAR_KHR)];
    got := choose_surface_format(formats);
    if got.format != .B8G8R8A8_SRGB || got.colorSpace != .COLOR_SPACE_SRGB_NONLINEAR_KHR {
        print("    chose %/%, want B8G8R8A8_SRGB/COLOR_SPACE_SRGB_NONLINEAR_KHR\n", got.format, got.colorSpace);
        return false;
    }
    return true;
}

surface_format_falls_back_to_first :: (ctx: *Gfx_Context) -> bool {
    formats := VkSurfaceFormatKHR.[sf(.R8G8B8A8_UNORM, .COLOR_SPACE_SRGB_NONLINEAR_KHR), sf(.B8G8R8A8_UNORM, .COLOR_SPACE_SRGB_NONLINEAR_KHR)];
    got := choose_surface_format(formats);
    if got.format != .R8G8B8A8_UNORM {
        print("    chose %, want the first, R8G8B8A8_UNORM\n", got.format);
        return false;
    }
    return true;
}

present_mode_table :: (ctx: *Gfx_Context) -> bool {
    Row :: struct { vsync: bool; modes: [] VkPresentModeKHR; want: VkPresentModeKHR; }
    all := VkPresentModeKHR.[.IMMEDIATE_KHR, .MAILBOX_KHR, .FIFO_KHR];
    rows := Row.[
        .{true,  all,                                    .FIFO_KHR},
        .{false, all,                                    .MAILBOX_KHR},
        .{false, .[.IMMEDIATE_KHR, .FIFO_KHR],           .IMMEDIATE_KHR},
        .{false, .[.FIFO_KHR],                           .FIFO_KHR},
    ];
    ok := true;
    for rows {
        got := choose_present_mode(it.modes, it.vsync);
        if got != it.want {
            print("    choose_present_mode(%, vsync %): got %, want %\n", it.modes, it.vsync, got, it.want);
            ok = false;
        }
    }
    return ok;
}

extent_uses_current_when_set :: (ctx: *Gfx_Context) -> bool {
    caps: VkSurfaceCapabilitiesKHR;
    caps.currentExtent  = .{800, 600};
    caps.minImageExtent = .{1, 1};
    caps.maxImageExtent = .{4096, 4096};
    got := choose_extent(caps, 1, 1);
    if got.width != 800 || got.height != 600 {
        print("    chose %x%, want 800x600\n", got.width, got.height);
        return false;
    }
    return true;
}

extent_clamps_when_undefined :: (ctx: *Gfx_Context) -> bool {
    caps: VkSurfaceCapabilitiesKHR;
    caps.currentExtent  = .{0xFFFF_FFFF, 0xFFFF_FFFF};
    caps.minImageExtent = .{1, 1};
    caps.maxImageExtent = .{4096, 4096};
    got := choose_extent(caps, 5000, 10);
    if got.width != 4096 || got.height != 10 {
        print("    chose %x%, want 4096x10\n", got.width, got.height);
        return false;
    }
    return true;
}

image_count_table :: (ctx: *Gfx_Context) -> bool {
    Row :: struct { min: u32; max: u32; want: u32; }
    rows := Row.[ .{2, 0, 3}, .{2, 3, 3}, .{3, 3, 3}, .{2, 8, 3} ];
    ok := true;
    for rows {
        caps: VkSurfaceCapabilitiesKHR;
        caps.minImageCount = it.min;
        caps.maxImageCount = it.max;
        got := choose_image_count(caps);
        if got != it.want {
            print("    choose_image_count(min %, max %): got %, want %\n", it.min, it.max, got, it.want);
            ok = false;
        }
    }
    return ok;
}

clear_reads_back :: (ctx: *Gfx_Context) -> bool {
    t := create_target(ctx, 96, 64);
    defer destroy_target(ctx, *t);
    cb := begin_commands(ctx);
    transition_image(cb, t.image, .UNDEFINED, .COLOR_ATTACHMENT_OPTIMAL,
                     VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                     VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT);
    record_clear(cb, t.view, .{96, 64}, .[0.8, 0.2, 0.4, 1.0]);
    submit_and_wait(ctx, cb);
    p := readback(ctx, *t, .COLOR_ATTACHMENT_OPTIMAL);
    return expect_region_solid(p, 0, 0, 96, 64, 204, 51, 102, 255);
}

swapchain_from_real_surface :: (ctx: *Gfx_Context) -> bool {
    win := create_window(320, 200, "exercise-2");
    surface, sok := create_surface(ctx, win);
    if !sok  return false;
    defer vkDestroySurfaceKHR(ctx.instance, surface, null);

    caps: VkSurfaceCapabilitiesKHR;
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(ctx.physical_device, surface, *caps);
    formats, _ := vkGetPhysicalDeviceSurfaceFormatsKHR(ctx.physical_device, surface);
    defer free(formats.data);
    want_format := choose_surface_format(formats).format;

    sc, ok := create_swapchain(ctx, surface, 320, 200, vsync = true);
    if !ok  return false;
    defer destroy_swapchain(ctx, *sc);

    // X11 reports the window's size as currentExtent (the window manager may have resized the window
    // by now); the swapchain must have taken it. Only a surface that leaves the choice open gets the
    // clamped request.
    want := caps.currentExtent;
    if want.width == 0xFFFF_FFFF  want = .{320, 200};
    good := true;
    if sc.images.count < caps.minImageCount {
        print("    % images, the surface needs at least %\n", sc.images.count, caps.minImageCount);
        good = false;
    }
    if sc.extent.width != want.width || sc.extent.height != want.height {
        print("    extent %x%, want %x%\n", sc.extent.width, sc.extent.height, want.width, want.height);
        good = false;
    }
    if sc.format != want_format {
        print("    format %, the chooser picked %\n", sc.format, want_format);
        good = false;
    }
    return good;
}

CASES :: Test_Case.[
    .{name = "surface_format_prefers_bgra_srgb",   proc = surface_format_prefers_bgra_srgb},
    .{name = "surface_format_falls_back_to_first", proc = surface_format_falls_back_to_first},
    .{name = "present_mode_table",                 proc = present_mode_table},
    .{name = "extent_uses_current_when_set",       proc = extent_uses_current_when_set},
    .{name = "extent_clamps_when_undefined",       proc = extent_clamps_when_undefined},
    .{name = "image_count_table",                  proc = image_count_table},
    .{name = "clear_reads_back",                   proc = clear_reads_back},
    .{name = "swapchain_from_real_surface",        proc = swapchain_from_real_surface, needs_display = true},
];

main :: () { exit(run_tests(CASES, get_command_line_arguments())); }
