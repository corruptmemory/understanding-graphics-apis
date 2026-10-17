// Exercise 4: the test cases. tests.jai loads them with the stubs; the solution's tests.jai loads
// them with the solution. Run with: first.jai - test vulkan/exercise-4

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

// A 128 by 128 target and the table pipeline, shared by every case.
Scene :: struct { t: Gfx_Target; p: Pipeline; ok: bool; }

scene_begin :: (ctx: *Gfx_Context) -> Scene {
    s: Scene;
    s.t = create_target(ctx, 128, 128);
    s.p, s.ok = create_table_pipeline(ctx, s.t.format);
    if !s.ok  print("    create_table_pipeline failed\n");
    return s;
}

scene_end :: (ctx: *Gfx_Context, s: *Scene) {
    destroy_pipeline(ctx, *s.p);
    destroy_target(ctx, *s.t);
}

// A clearing buffer: prepare_target first, then the learner's draws over a clear.
clearing :: (ctx: *Gfx_Context, s: *Scene, draws: [] int) -> (cb: VkCommandBuffer, ok: bool) {
    cb := begin_buffer(ctx);
    if !cb {
        print("    begin_buffer returned null\n");
        return null, false;
    }
    prepare_target(cb, s.t.image);
    record_scene(cb, s.t.view, .{128, 128}, s.p, draws, clear = true);
    return cb, true;
}

// A loading buffer: attachment_barrier first, then the learner's draws over what is there.
loading :: (ctx: *Gfx_Context, s: *Scene, draws: [] int) -> (cb: VkCommandBuffer, ok: bool) {
    cb := begin_buffer(ctx);
    if !cb {
        print("    begin_buffer returned null\n");
        return null, false;
    }
    attachment_barrier(cb, s.t.image);
    record_scene(cb, s.t.view, .{128, 128}, s.p, draws, clear = false);
    return cb, true;
}

RED    :: u8.[255, 0, 0, 255];
GREEN  :: u8.[0, 255, 0, 255];
BLUE   :: u8.[0, 0, 255, 255];
YELLOW :: u8.[255, 255, 0, 255];
BLACK  :: u8.[0, 0, 0, 255];

at :: (p: Pixels, x: int, y: int, c: [4] u8, loc := #caller_location) -> bool {
    return expect_pixel(p, x, y, c[0], c[1], c[2], c[3], loc = loc);
}

draw_order_within_one_buffer :: (ctx: *Gfx_Context) -> bool {
    s := scene_begin(ctx);
    defer scene_end(ctx, *s);
    if !s.ok  return false;
    a, ok := clearing(ctx, *s, .[0, 1, 2, 3]);
    if !ok  return false;
    submit_ordered(ctx, .[a]);
    p := readback(ctx, *s.t, .COLOR_ATTACHMENT_OPTIMAL);
    return at(p, 64, 64, YELLOW) && at(p, 64, 12, RED) && at(p, 115, 64, GREEN) && at(p, 64, 115, BLUE) && at(p, 12, 64, YELLOW) && at(p, 2, 2, BLACK);
}

second_buffer_draws_over_the_first :: (ctx: *Gfx_Context) -> bool {
    s := scene_begin(ctx);
    defer scene_end(ctx, *s);
    if !s.ok  return false;
    a, aok := clearing(ctx, *s, .[0, 1]);
    if !aok  return false;
    b, bok := loading(ctx, *s, .[2]);
    if !bok  return false;
    submit_ordered(ctx, .[a, b]);
    p := readback(ctx, *s.t, .COLOR_ATTACHMENT_OPTIMAL);
    return at(p, 64, 64, BLUE) && at(p, 64, 12, RED) && at(p, 115, 64, GREEN);
}

submission_order_not_recording_order :: (ctx: *Gfx_Context) -> bool {
    s := scene_begin(ctx);
    defer scene_end(ctx, *s);
    if !s.ok  return false;
    b, bok := loading(ctx, *s, .[3]);       // recorded first
    if !bok  return false;
    a, aok := clearing(ctx, *s, .[0, 1, 2]); // recorded second
    if !aok  return false;
    submit_ordered(ctx, .[a, b]);            // submitted the other way round
    p := readback(ctx, *s.t, .COLOR_ATTACHMENT_OPTIMAL);
    return at(p, 64, 64, YELLOW);            // recording order would have given blue
}

two_submits_in_sequence :: (ctx: *Gfx_Context) -> bool {
    s := scene_begin(ctx);
    defer scene_end(ctx, *s);
    if !s.ok  return false;
    a, aok := clearing(ctx, *s, .[0]);
    if !aok  return false;
    submit_ordered(ctx, .[a]);
    b, bok := loading(ctx, *s, .[1]);
    if !bok  return false;
    submit_ordered(ctx, .[b]);
    p := readback(ctx, *s.t, .COLOR_ATTACHMENT_OPTIMAL);
    return at(p, 64, 64, GREEN) && at(p, 64, 12, RED);
}

empty_draw_list_only_clears :: (ctx: *Gfx_Context) -> bool {
    s := scene_begin(ctx);
    defer scene_end(ctx, *s);
    if !s.ok  return false;
    a, ok := clearing(ctx, *s, .[]);
    if !ok  return false;
    submit_ordered(ctx, .[a]);
    p := readback(ctx, *s.t, .COLOR_ATTACHMENT_OPTIMAL);
    return expect_region_solid(p, 0, 0, 128, 128, 0, 0, 0, 255);
}

CASES :: Test_Case.[
    .{name = "draw_order_within_one_buffer",         proc = draw_order_within_one_buffer},
    .{name = "second_buffer_draws_over_the_first",   proc = second_buffer_draws_over_the_first},
    .{name = "submission_order_not_recording_order", proc = submission_order_not_recording_order},
    .{name = "two_submits_in_sequence",              proc = two_submits_in_sequence},
    .{name = "empty_draw_list_only_clears",          proc = empty_draw_list_only_clears},
];

main :: () { exit(run_tests(CASES, get_command_line_arguments())); }
