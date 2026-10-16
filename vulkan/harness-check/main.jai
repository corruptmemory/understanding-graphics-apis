// The windowed runner for this target: there is nothing to show yet, so it just proves a
// device comes up and names it. Run with: first.jai - run vulkan/harness-check
#import "Basic";
#import "Gfx_Test";

main :: () {
    ctx := gfx_init();
    if !ctx  exit(1);
    print("device: %\n", ctx.device_name);
    gfx_shutdown(ctx);
}
