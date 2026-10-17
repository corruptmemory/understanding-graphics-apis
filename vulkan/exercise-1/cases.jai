// Exercise 1: the test cases. tests.jai loads them with the stubs; the solution's tests.jai loads
// them with the solution. Run with: first.jai - test vulkan/exercise-1

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

// A family written as its flags and its queue count.
family :: (flags: VkQueueFlags, count: u32) -> VkQueueFamilyProperties {
    f: VkQueueFamilyProperties;
    f.queueFlags = flags;
    f.queueCount = count;
    return f;
}

GCT :: VkQueueFlagBits.GRAPHICS_BIT | .COMPUTE_BIT | .TRANSFER_BIT;
CT  :: VkQueueFlagBits.COMPUTE_BIT | .TRANSFER_BIT;
T   :: VkQueueFlagBits.TRANSFER_BIT;

expect_choice :: (families: [] VkQueueFamilyProperties, graphics: u32, transfer: u32) -> bool {
    choice, ok := choose_queue_families(families);
    if !ok {
        print("    choose_queue_families returned ok = false\n");
        return false;
    }
    if choice.graphics_family != graphics || choice.transfer_family != transfer {
        print("    chose graphics %, transfer %; want %, %\n", choice.graphics_family, choice.transfer_family, graphics, transfer);
        return false;
    }
    return true;
}

families_one_of_each :: (ctx: *Gfx_Context) -> bool {
    return expect_choice(.[family(GCT, 1), family(CT, 4), family(T, 2)], 0, 2);
}

families_single_family :: (ctx: *Gfx_Context) -> bool {
    return expect_choice(.[family(GCT, 1)], 0, 0);
}

families_transfer_before_compute :: (ctx: *Gfx_Context) -> bool {
    return expect_choice(.[family(GCT, 16), family(T, 2), family(CT, 8)], 0, 1);
}

families_compute_is_not_transfer_only :: (ctx: *Gfx_Context) -> bool {   // a compute family is not a dedicated transfer engine
    return expect_choice(.[family(GCT, 1), family(CT, 2)], 0, 0);
}

families_none_graphics :: (ctx: *Gfx_Context) -> bool {
    _, ok := choose_queue_families(.[family(CT, 1), family(T, 1)]);
    if ok  print("    choose_queue_families said ok with no graphics family\n");
    return !ok;
}

// A family with GRAPHICS_BIT or COMPUTE_BIT can transfer whether or not it says so (the
// specification makes TRANSFER_BIT optional on those), so the transfer family only has to be able to.
can_transfer :: (flags: VkQueueFlags) -> bool {
    return cast(bool) (flags & (.TRANSFER_BIT | .GRAPHICS_BIT | .COMPUTE_BIT));
}

live_choice_matches_the_harness :: (ctx: *Gfx_Context) -> bool {
    families := queue_family_properties(ctx.physical_device);
    defer free(families.data);
    choice, ok := choose_queue_families(families);
    if !ok {
        print("    no graphics family chosen on %\n", ctx.device_name);
        return false;
    }
    if choice.graphics_family != ctx.queue_family {
        print("    graphics family %, the harness chose %\n", choice.graphics_family, ctx.queue_family);
        return false;
    }
    t := families[choice.transfer_family].queueFlags;
    if !can_transfer(t) {
        print("    transfer family % cannot transfer: %\n", choice.transfer_family, queue_flags_string(t));
        return false;
    }
    if choice.transfer_family != choice.graphics_family && (t & (.GRAPHICS_BIT | .COMPUTE_BIT)) {
        print("    transfer family % is not transfer-only: %\n", choice.transfer_family, queue_flags_string(t));
        return false;
    }
    return true;
}

live_device_creates_and_destroys :: (ctx: *Gfx_Context) -> bool {
    families := queue_family_properties(ctx.physical_device);
    defer free(families.data);
    choice, ok := choose_queue_families(families);
    if !ok  return false;

    device, graphics, transfer := create_device(ctx.physical_device, choice);
    if device == null {
        print("    create_device returned null\n");
        return false;
    }
    defer vkDestroyDevice(device, null);
    if graphics == null || transfer == null {
        print("    a queue is null: graphics %, transfer %\n", graphics, transfer);
        return false;
    }
    same_family := choice.graphics_family == choice.transfer_family;
    if (graphics == transfer) != same_family {
        print("    queues % and % for families % and %\n", graphics, transfer, choice.graphics_family, choice.transfer_family);
        return false;
    }
    return true;
}

CASES :: Test_Case.[
    .{name = "families_one_of_each",                  proc = families_one_of_each},
    .{name = "families_single_family",                proc = families_single_family},
    .{name = "families_transfer_before_compute",      proc = families_transfer_before_compute},
    .{name = "families_compute_is_not_transfer_only", proc = families_compute_is_not_transfer_only},
    .{name = "families_none_graphics",                proc = families_none_graphics},
    .{name = "live_choice_matches_the_harness",       proc = live_choice_matches_the_harness},
    .{name = "live_device_creates_and_destroys",      proc = live_device_creates_and_destroys},
];

main :: () { exit(run_tests(CASES, get_command_line_arguments())); }
