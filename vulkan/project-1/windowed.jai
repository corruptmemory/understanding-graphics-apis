// The windowed program for project 1: your scene for 600 frames, at the swapchain's size.
// Run with: first.jai - run vulkan/project-1

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";
#import "Window_Creation";

the_scene: Scene;   // record_frame cannot capture, so the scene lives here

record_frame :: (ctx: *Gfx_Context, image: VkImage, view: VkImageView, extent: VkExtent2D, frame: int, cbs: *[..] VkCommandBuffer) {
    scene_record(ctx, *the_scene, image, view, extent, frame, cbs);
}

main :: () {
    ctx := gfx_init();
    if !ctx  exit(1);

    win := create_window(800, 600, "project-1");
    surface, sok := create_surface(ctx, win);
    if !sok  exit(1);
    sc, ok := create_swapchain(ctx, surface, 800, 600, vsync = true);
    if !ok  exit(1);

    scene, init_ok := scene_init(ctx, sc.format);
    if !init_ok  exit(1);
    the_scene = scene;

    present_loop(ctx, *sc, 600, record_frame);

    scene_destroy(ctx, *the_scene);
    destroy_swapchain(ctx, *sc);
    vkDestroySurfaceKHR(ctx.instance, surface, null);
    for ctx.recorder.messages  print("    validation: %\n", it);
    errors, _ := gfx_shutdown(ctx);
    if errors  exit(1);
}
