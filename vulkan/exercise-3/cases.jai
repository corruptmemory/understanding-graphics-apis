// Exercise 3: the test cases. tests.jai loads them with the stubs; the solution's tests.jai loads
// them with the solution. Run with: first.jai - test vulkan/exercise-3

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

FULL :: VkViewport.{0, 0, 128, 128, 0, 1};

// A 128 by 128 target drawn once with a pipeline of the given winding and cull mode.
draw_once :: (ctx: *Gfx_Context, front_face: VkFrontFace, cull: VkCullModeFlags, viewport: VkViewport) -> (p: Pixels, ok: bool) {
    t := create_target(ctx, 128, 128);
    defer destroy_target(ctx, *t);
    pipe, ok := create_pipeline(ctx, t.format, front_face, cull);
    if !ok {
        print("    create_pipeline(%, %) failed\n", front_face, cull);
        return .{}, false;
    }
    defer destroy_pipeline(ctx, *pipe);
    return draw_to_target(ctx, *t, pipe, viewport), true;
}

triangle_shows_with_ccw_and_back_cull :: (ctx: *Gfx_Context) -> bool {
    p, ok := draw_once(ctx, .COUNTER_CLOCKWISE, .BACK_BIT, FULL);
    if !ok  return false;
    return expect_pixel(p, 64, 64, 0, 255, 0, 255) && expect_pixel(p, 64, 100, 0, 255, 0, 255)
        && expect_pixel(p, 5, 5, 0, 0, 0, 255) && expect_pixel(p, 10, 60, 0, 0, 0, 255) && expect_pixel(p, 120, 120, 0, 0, 0, 255);
}

triangle_culled_when_front_face_is_clockwise :: (ctx: *Gfx_Context) -> bool {
    p, ok := draw_once(ctx, .CLOCKWISE, .BACK_BIT, FULL);
    if !ok  return false;
    return expect_region_solid(p, 0, 0, 128, 128, 0, 0, 0, 255);
}

triangle_shows_when_cull_is_none :: (ctx: *Gfx_Context) -> bool {
    p, ok := draw_once(ctx, .CLOCKWISE, .NONE, FULL);
    if !ok  return false;
    return expect_pixel(p, 64, 64, 0, 255, 0, 255);
}

viewport_moves_the_triangle :: (ctx: *Gfx_Context) -> bool {
    p, ok := draw_once(ctx, .COUNTER_CLOCKWISE, .BACK_BIT, .{64, 0, 64, 128, 0, 1});
    if !ok  return false;
    return expect_region_solid(p, 0, 0, 64, 128, 0, 0, 0, 255)
        && expect_pixel(p, 96, 64, 0, 255, 0, 255) && expect_pixel(p, 96, 100, 0, 255, 0, 255);
}

CASES :: Test_Case.[
    .{name = "triangle_shows_with_ccw_and_back_cull",        proc = triangle_shows_with_ccw_and_back_cull},
    .{name = "triangle_culled_when_front_face_is_clockwise", proc = triangle_culled_when_front_face_is_clockwise},
    .{name = "triangle_shows_when_cull_is_none",             proc = triangle_shows_when_cull_is_none},
    .{name = "viewport_moves_the_triangle",                  proc = viewport_moves_the_triangle},
];

main :: () { exit(run_tests(CASES, get_command_line_arguments())); }
