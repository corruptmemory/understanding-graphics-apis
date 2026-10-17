// The windowed program for exercise 4: four overlapping triangles, two command buffers per frame;
// the triangle on top changes once a second. Run with: first.jai - run vulkan/exercise-4

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";
#import "Window_Creation";

the_pipeline: Pipeline;

record_frame :: (ctx: *Gfx_Context, image: VkImage, view: VkImageView, extent: VkExtent2D, frame: int, cbs: *[..] VkCommandBuffer) {
    all := begin_buffer(ctx);                                     // clears, then every triangle in order
    if !all  return;
    record_scene(all, view, extent, the_pipeline, .[0, 1, 2, 3], clear = true);
    array_add(cbs, all);

    top := begin_buffer(ctx);                                     // loads, then one triangle over the rest
    if !top  return;
    attachment_barrier(top, image);
    record_scene(top, view, extent, the_pipeline, .[(frame / 60) % 4], clear = false);
    array_add(cbs, top);
}

main :: () {
    ctx := gfx_init();
    if !ctx  exit(1);

    win := create_window(640, 480, "exercise-4");
    surface, sok := create_surface(ctx, win);
    if !sok  exit(1);
    sc, ok := create_swapchain(ctx, surface, 640, 480, vsync = true);
    if !ok  exit(1);

    pipe, pok := create_table_pipeline(ctx, sc.format);
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
