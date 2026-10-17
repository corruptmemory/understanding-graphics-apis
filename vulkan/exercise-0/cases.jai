// Exercise 0: the test cases. tests.jai loads them with the stubs; the solution's tests.jai loads
// them with the solution. Run with: first.jai - test vulkan/exercise-0

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

api_version_table :: (ctx: *Gfx_Context) -> bool {
    Row :: struct { v: u32; want: string; }
    rows := Row.[
        .{#run VK_MAKE_API_VERSION(0, 1, 4, 354), "1.4.354"},
        .{#run VK_MAKE_API_VERSION(0, 1, 3, 0),   "1.3.0"},
        .{#run VK_MAKE_API_VERSION(1, 1, 0, 0),   "1.0.0 (variant 1)"},
    ];
    ok := true;
    for rows {
        got := api_version_string(it.v);
        if got != it.want {
            print("    api_version_string(0x%): got '%', want '%'\n", formatInt(it.v, base = 16), got, it.want);
            ok = false;
        }
    }
    return ok;
}

driver_version_table :: (ctx: *Gfx_Context) -> bool {
    Row :: struct { vendor: u32; v: u32; want: string; }
    mesa :: #run VK_MAKE_API_VERSION(0, 26, 2, 4);
    rows := Row.[
        .{0x10DE, (580 << 22) | (95 << 14) | (5 << 6), "580.95.5.0"},   // NVIDIA's split
        .{0x1002, mesa,                                "26.2.4"},        // AMD on Mesa
        .{0x8086, mesa,                                "26.2.4"},        // Intel on Mesa
    ];
    ok := true;
    for rows {
        got := driver_version_string(it.vendor, it.v);
        if got != it.want {
            print("    driver_version_string(0x%, 0x%): got '%', want '%'\n", formatInt(it.vendor, base = 16), formatInt(it.v, base = 16), got, it.want);
            ok = false;
        }
    }
    return ok;
}

same_strings :: (a: [] string, b: [] string) -> bool {
    if a.count != b.count  return false;
    for a  if it != b[it_index]  return false;
    return true;
}

extension_sources_table :: (ctx: *Gfx_Context) -> bool {
    inv: Inventory;
    inv.base_extensions = .["VK_KHR_surface", "VK_KHR_xlib_surface", "VK_EXT_debug_utils"];
    inv.layers = .[
        .{name = "VK_LAYER_KHRONOS_validation", extensions = .["VK_EXT_debug_utils", "VK_EXT_validation_features", "VK_EXT_layer_settings"]},
        .{name = "VK_LAYER_FAKE_overlay",       extensions = .["VK_EXT_debug_utils"]},
    ];
    Row :: struct { extension: string; want: [] string; }
    rows := Row.[
        .{"VK_EXT_debug_utils",         .["base", "VK_LAYER_KHRONOS_validation", "VK_LAYER_FAKE_overlay"]},
        .{"VK_EXT_validation_features", .["VK_LAYER_KHRONOS_validation"]},
        .{"VK_KHR_surface",             .["base"]},
        .{"VK_KHR_nope",                .[]},
    ];
    ok := true;
    for rows {
        got := extension_sources(inv, it.extension);
        if !same_strings(got, it.want) {
            print("    extension_sources(%): got %, want %\n", it.extension, got, it.want);
            ok = false;
        }
    }
    return ok;
}

live_inventory_has_the_validation_layer :: (ctx: *Gfx_Context) -> bool {
    inv, ok := collect_inventory();
    if !ok  return false;
    if inv.instance_version < VK_API_VERSION_1_3 {
        print("    instance version 0x% is below 1.3\n", formatInt(inv.instance_version, base = 16));
        return false;
    }
    has_layer := false;
    for inv.layers  if it.name == "VK_LAYER_KHRONOS_validation"  has_layer = true;
    if !has_layer {
        print("    VK_LAYER_KHRONOS_validation is not among the % layers\n", inv.layers.count);
        return false;
    }
    sources := extension_sources(inv, "VK_EXT_validation_features");
    from_layer, from_base := false, false;
    for sources {
        if it == "VK_LAYER_KHRONOS_validation"  from_layer = true;
        if it == "base"                         from_base  = true;
    }
    if !from_layer || from_base {
        print("    VK_EXT_validation_features comes from %, want the validation layer and not base\n", sources);
        return false;
    }
    if inv.devices.count < 1 {
        print("    no physical devices\n");
        return false;
    }
    return true;
}

CASES :: Test_Case.[
    .{name = "api_version_table",                       proc = api_version_table},
    .{name = "driver_version_table",                    proc = driver_version_table},
    .{name = "extension_sources_table",                 proc = extension_sources_table},
    .{name = "live_inventory_has_the_validation_layer", proc = live_inventory_has_the_validation_layer},
];

main :: () { exit(run_tests(CASES, get_command_line_arguments())); }
