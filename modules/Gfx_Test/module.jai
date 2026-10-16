// Gfx_Test: the headless Vulkan harness every exercise's tests.jai builds on.
//
// A test case gets a fresh Gfx_Context: a Vulkan 1.3 device with dynamicRendering and
// synchronization2 enabled, the Khronos validation layer on, and a debug messenger whose
// callback records every validation error and warning into ctx.recorder. The runner fails
// a case whose recorder holds errors the case did not declare, so "zero validation errors"
// is a free, suite-wide assertion, in the spirit of the error-recording logger pattern.
//
// Tests never open a window. Rendering goes to offscreen targets (target.jai) that can be
// read back into Pixels and asserted on, or written to a PNG with `first.jai - capture`.

#import "Basic";
#import "File";             // make_directory_if_it_does_not_exist
#import "String";           // path_strip_filename
#import "Vulkan";
#import "stb_image_write";  // stbi_write_png

Error_Recorder :: struct {
    errors:   int;
    warnings: int;
    messages: [..] string;
}

Gfx_Context :: struct {
    instance:          VkInstance;
    messenger:         VkDebugUtilsMessengerEXT;
    destroy_messenger: PFN_vkDestroyDebugUtilsMessengerEXT;
    physical_device:   VkPhysicalDevice;
    device:            VkDevice;
    queue:             VkQueue;
    queue_family:      u32;
    command_pool:      VkCommandPool;
    recorder:          Error_Recorder;
    device_name:       string;
}

Gfx_Init_Options :: struct {
    sync_validation := false;
    layer_name      := "VK_LAYER_KHRONOS_validation";
}

// A physical device as seen by choose_physical_device: pure data, so the choice is testable
// without a GPU.
Device_Candidate :: struct {
    index:       int;
    device_type: VkPhysicalDeviceType;
    api_version: u32;
    name:        string;
}

Test_Case :: struct {
    name:                     string;
    proc:                     (ctx: *Gfx_Context) -> bool;
    expect_validation_errors := 0;      // a negative test says how many it expects
    warnings_fatal           := false;
    sync_validation          := false;
    needs_display            := false;  // SKIP when DISPLAY is unset
}

#load "device.jai";
#load "target.jai";
#load "runner.jai";
