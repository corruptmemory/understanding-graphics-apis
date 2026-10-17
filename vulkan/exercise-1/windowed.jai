// The runner for exercise 1: no window yet. It prints the device, its families and the choice, then
// creates and destroys a device through the contract. Run with: first.jai - run vulkan/exercise-1

#import "Basic";
#import "Gfx_Test";
#import "Vulkan";

main :: () {
    ctx := gfx_init();
    if !ctx  exit(1);
    print("device: %\n", ctx.device_name);

    families := queue_family_properties(ctx.physical_device);
    for families  print("  family %: % ×%\n", it_index, queue_flags_string(it.queueFlags), it.queueCount);

    choice, ok := choose_queue_families(families);
    if !ok {
        log_error("choose_queue_families found no graphics family (is exercise.jai still a stub?)");
        exit(1);
    }
    print("choice: graphics family %, transfer family %\n", choice.graphics_family, choice.transfer_family);

    device, graphics, transfer := create_device(ctx.physical_device, choice);
    if !device  exit(1);
    vkDestroyDevice(device, null);
    print("device created%, destroyed\n", ifx graphics == transfer then " (one queue serves both)" else " (two queues)");

    for ctx.recorder.messages  print("    validation: %\n", it);
    errors, _ := gfx_shutdown(ctx);
    if errors  exit(1);
}
