// The windowed program for exercise 3: a green triangle pointing up on a dark window, 300 frames.
// Run with: first.jai - run vulkan/exercise-3

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";
#import "Window_Creation";

the_pipeline: Pipeline;   // record_frame cannot capture, so the pipeline lives here

record_frame :: (ctx: *Gfx_Context, image: VkImage, view: VkImageView, extent: VkExtent2D, frame: int, cbs: *[..] VkCommandBuffer) {
    cb := begin_commands(ctx);
    full := VkViewport.{0, 0, xx extent.width, xx extent.height, 0, 1};
    record_triangle(cb, view, extent, the_pipeline, full, .[0.08, 0.08, 0.12, 1.0]);
    vkEndCommandBuffer(cb);
    array_add(cbs, cb);
}

main :: () {
    ctx := gfx_init();
    if !ctx  exit(1);

    win := create_window(640, 480, "exercise-3");
    surface, sok := create_surface(ctx, win);
    if !sok  exit(1);
    sc, ok := create_swapchain(ctx, surface, 640, 480, vsync = true);
    if !ok  exit(1);

    pipe, pok := create_pipeline(ctx, sc.format, .COUNTER_CLOCKWISE, .BACK_BIT);
    if !pok  exit(1);
    the_pipeline = pipe;

    present_loop(ctx, *sc, 300, record_frame);

    destroy_pipeline(ctx, *the_pipeline);
    destroy_swapchain(ctx, *sc);
    vkDestroySurfaceKHR(ctx.instance, surface, null);
    for ctx.recorder.messages  print("    validation: %\n", it);
    errors, _ := gfx_shutdown(ctx);
    if errors  exit(1);
}
