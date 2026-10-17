// The windowed program for exercise 2: a 640 by 480 window cleared to dark blue for 300 frames.
// Run with: first.jai - run vulkan/exercise-2

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";
#import "Window_Creation";

frame_cb: VkCommandBuffer;   // last frame's buffer; present_loop has waited for its fence by the time record_frame runs again

record_frame :: (ctx: *Gfx_Context, image: VkImage, view: VkImageView, extent: VkExtent2D, frame: int, cbs: *[..] VkCommandBuffer) {
    if frame_cb  vkFreeCommandBuffers(ctx.device, ctx.command_pool, 1, *frame_cb);
    frame_cb = begin_commands(ctx);
    record_clear(frame_cb, view, extent, .[0.1, 0.1, 0.3, 1.0]);
    vkEndCommandBuffer(frame_cb);
    array_add(cbs, frame_cb);
}

main :: () {
    ctx := gfx_init();
    if !ctx  exit(1);

    win := create_window(640, 480, "exercise-2");
    surface, sok := create_surface(ctx, win);
    if !sok  exit(1);
    sc, ok := create_swapchain(ctx, surface, 640, 480, vsync = true);
    if !ok  exit(1);
    print("swapchain: % images, %x%, %\n", sc.images.count, sc.extent.width, sc.extent.height, sc.format);

    present_loop(ctx, *sc, 300, record_frame);

    destroy_swapchain(ctx, *sc);
    vkDestroySurfaceKHR(ctx.instance, surface, null);
    for ctx.recorder.messages  print("    validation: %\n", it);
    errors, _ := gfx_shutdown(ctx);
    if errors  exit(1);
}
