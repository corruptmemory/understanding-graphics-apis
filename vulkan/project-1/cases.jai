// Project 1: the deterministic floor. Builds, a frame renders headlessly from at least two buffers,
// frames 0 and 30 differ, zero validation errors. The rubric covers the rest.
// Run with: first.jai - test vulkan/project-1

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

// A 256 by 256 target, transitioned for rendering, plus the learner's scene.
Frame :: struct { t: Gfx_Target; scene: Scene; ok: bool; }

frame_begin :: (ctx: *Gfx_Context) -> Frame {
    f: Frame;
    f.t = create_target(ctx, 256, 256);
    ready(ctx, *f.t);
    f.scene, f.ok = scene_init(ctx, f.t.format);
    if !f.ok  print("    scene_init returned ok = false\n");
    return f;
}

frame_end :: (ctx: *Gfx_Context, f: *Frame) {
    if f.ok  scene_destroy(ctx, *f.scene);
    destroy_target(ctx, *f.t);
}

// UNDEFINED -> COLOR_ATTACHMENT_OPTIMAL (readback leaves the image in TRANSFER_SRC_OPTIMAL, and the
// first buffer clears, so the old contents never matter).
ready :: (ctx: *Gfx_Context, t: *Gfx_Target) {
    cb := begin_commands(ctx);
    prepare_target(cb, t.image);
    submit_and_wait(ctx, cb);
}

// One frame through the learner's scene_record and the given submit; the pixels and the buffer count.
render :: (ctx: *Gfx_Context, f: *Frame, frame: int) -> (p: Pixels, buffers: int) {
    cbs: [..] VkCommandBuffer;
    defer array_free(cbs);
    scene_record(ctx, *f.scene, f.t.image, f.t.view, .{256, 256}, frame, *cbs);
    if cbs.count == 0 {
        print("    scene_record appended no command buffers\n");
        return .{}, 0;
    }
    submit_and_wait_all(ctx, cbs);
    return readback(ctx, *f.t, .COLOR_ATTACHMENT_OPTIMAL), cbs.count;
}

renders_a_frame_headlessly :: (ctx: *Gfx_Context) -> bool {
    f := frame_begin(ctx);
    defer frame_end(ctx, *f);
    if !f.ok  return false;
    p, n := render(ctx, *f, 0);
    if n == 0  return false;
    colors := distinct_colors(p);
    if colors < 6  print("    % distinct colors, want at least 6 (the clear plus five or more shapes)\n", colors);
    return colors >= 6;
}

two_buffers_per_frame :: (ctx: *Gfx_Context) -> bool {
    f := frame_begin(ctx);
    defer frame_end(ctx, *f);
    if !f.ok  return false;
    _, n := render(ctx, *f, 0);
    if n < 2  print("    % command buffers appended, want at least 2\n", n);
    return n >= 2;
}

frames_differ :: (ctx: *Gfx_Context) -> bool {
    f := frame_begin(ctx);
    defer frame_end(ctx, *f);
    if !f.ok  return false;
    p0, n0 := render(ctx, *f, 0);
    if n0 == 0  return false;
    ready(ctx, *f.t);
    p30, n30 := render(ctx, *f, 30);
    if n30 == 0  return false;
    if !pixels_differ(p0, p30)  print("    frames 0 and 30 are identical; nothing moves\n");
    return pixels_differ(p0, p30);
}

CASES :: Test_Case.[
    .{name = "renders_a_frame_headlessly", proc = renders_a_frame_headlessly},
    .{name = "two_buffers_per_frame",      proc = two_buffers_per_frame},
    .{name = "frames_differ",              proc = frames_differ},
];

main :: () { exit(run_tests(CASES, get_command_line_arguments())); }
