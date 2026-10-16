// Instance, device and queue creation for the harness, plus the two pure functions the
// choice rests on (choose_physical_device, find_memory_type), kept free of Vulkan calls
// so they can be table-tested without a GPU.

// Prefer a discrete GPU that reports API 1.3 or newer; otherwise the first device that does;
// -1 when none does. Lowest index wins ties, so the choice is stable across runs.
choose_physical_device :: (candidates: [] Device_Candidate) -> int {
    first_capable := -1;
    for candidates {
        if !supports_1_3(it.api_version)  continue;
        if it.device_type == .DISCRETE_GPU  return it.index;
        if first_capable == -1  first_capable = it.index;
    }
    return first_capable;
}

supports_1_3 :: (api_version: u32) -> bool {
    major := VK_API_VERSION_MAJOR(api_version);
    minor := VK_API_VERSION_MINOR(api_version);
    return major > 1 || (major == 1 && minor >= 3);
}

// First memory type allowed by type_bits that has every wanted property flag.
find_memory_type :: (props: VkPhysicalDeviceMemoryProperties, type_bits: u32, wanted: VkMemoryPropertyFlags) -> (index: u32, ok: bool) {
    for i: 0..props.memoryTypeCount-1 {
        if !(type_bits & (1 << i))  continue;
        if (props.memoryTypes[i].propertyFlags & wanted) == wanted  return i, true;
    }
    return 0, false;
}

debug_callback :: (severity: VkDebugUtilsMessageSeverityFlagBitsEXT, types: VkDebugUtilsMessageTypeFlagsEXT,
                   data: *VkDebugUtilsMessengerCallbackDataEXT, user: *void) -> VkBool32 #c_call {
    push_context {
        rec := cast(*Error_Recorder) user;
        if severity & .ERROR_BIT_EXT {
            rec.errors += 1;
            array_add(*rec.messages, copy_string(to_string(data.pMessage)));
        } else if severity & .WARNING_BIT_EXT {
            rec.warnings += 1;
            array_add(*rec.messages, copy_string(to_string(data.pMessage)));
        }
    }
    return VK_FALSE;
}

// Returns null after a log_error naming the failing call. Nothing is left allocated on failure.
gfx_init :: (options := Gfx_Init_Options.{}) -> *Gfx_Context {
    ctx := New(Gfx_Context);

    // ---- instance, with the validation layer and the recorder wired in from the first call --
    app: VkApplicationInfo;
    app.pApplicationName = "Gfx_Test";
    app.apiVersion       = VK_API_VERSION_1_3;

    layer_name := to_c_string(options.layer_name);
    defer free(layer_name);
    layers: [1] *u8;
    layers[0] = layer_name;

    exts: [3] *u8;
    exts[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
    exts[1] = VK_KHR_XLIB_SURFACE_EXTENSION_NAME.data;
    exts[2] = VK_EXT_DEBUG_UTILS_EXTENSION_NAME.data;

    dbg: VkDebugUtilsMessengerCreateInfoEXT;
    dbg.messageSeverity = .WARNING_BIT_EXT | .ERROR_BIT_EXT;
    dbg.messageType     = .GENERAL_BIT_EXT | .VALIDATION_BIT_EXT | .PERFORMANCE_BIT_EXT;
    dbg.pfnUserCallback = debug_callback;
    dbg.pUserData       = *ctx.recorder;

    enabled_features := VkValidationFeatureEnableEXT.[.SYNCHRONIZATION_VALIDATION_EXT];
    validation_features: VkValidationFeaturesEXT;
    validation_features.pNext                         = *dbg;
    validation_features.enabledValidationFeatureCount = 1;
    validation_features.pEnabledValidationFeatures    = enabled_features.data;

    ici: VkInstanceCreateInfo;
    ici.pNext                   = ifx options.sync_validation then cast(*void) *validation_features else cast(*void) *dbg;
    ici.pApplicationInfo        = *app;
    ici.enabledLayerCount       = layers.count;
    ici.ppEnabledLayerNames     = layers.data;
    ici.enabledExtensionCount   = exts.count;
    ici.ppEnabledExtensionNames = exts.data;

    result := vkCreateInstance(*ici, null, *ctx.instance);
    if result != .SUCCESS {
        log_error("vkCreateInstance failed: % (is the layer '%' installed, and the loader 1.3 or newer?)", result, options.layer_name);
        free(ctx);
        return null;
    }

    create_messenger: PFN_vkCreateDebugUtilsMessengerEXT = xx vkGetInstanceProcAddr(ctx.instance, "vkCreateDebugUtilsMessengerEXT");
    ctx.destroy_messenger                                = xx vkGetInstanceProcAddr(ctx.instance, "vkDestroyDebugUtilsMessengerEXT");
    if !create_messenger || !ctx.destroy_messenger {
        log_error("VK_EXT_debug_utils entry points are missing from the loader.");
        gfx_shutdown(ctx);
        return null;
    }
    result = create_messenger(ctx.instance, *dbg, null, *ctx.messenger);
    if result != .SUCCESS {
        log_error("vkCreateDebugUtilsMessengerEXT failed: %", result);
        gfx_shutdown(ctx);
        return null;
    }

    // ---- physical device ---------------------------------------------------------------------
    count: u32;
    vkEnumeratePhysicalDevices(ctx.instance, *count, null);
    if count == 0 {
        log_error("vkEnumeratePhysicalDevices found no devices.");
        gfx_shutdown(ctx);
        return null;
    }
    devices := NewArray(count, VkPhysicalDevice);
    defer free(devices.data);
    vkEnumeratePhysicalDevices(ctx.instance, *count, devices.data);

    candidates := NewArray(count, Device_Candidate);
    defer free(candidates.data);
    for devices {
        props: VkPhysicalDeviceProperties;
        vkGetPhysicalDeviceProperties(it, *props);
        candidates[it_index] = .{it_index, props.deviceType, props.apiVersion, copy_string(to_string(props.deviceName.data))};
    }
    chosen := choose_physical_device(candidates);
    if chosen == -1 {
        log_error("No physical device reports Vulkan 1.3 or newer (saw: %).", candidates);
        for candidates  free(it.name);
        gfx_shutdown(ctx);
        return null;
    }
    ctx.physical_device = devices[chosen];
    ctx.device_name     = candidates[chosen].name;
    for candidates  if it_index != chosen  free(it.name);

    // ---- a graphics queue family -----------------------------------------------------------------
    family_count: u32;
    vkGetPhysicalDeviceQueueFamilyProperties(ctx.physical_device, *family_count, null);
    families := NewArray(family_count, VkQueueFamilyProperties);
    defer free(families.data);
    vkGetPhysicalDeviceQueueFamilyProperties(ctx.physical_device, *family_count, families.data);
    ctx.queue_family = 0xffff_ffff;
    for families  if it.queueFlags & .GRAPHICS_BIT { ctx.queue_family = xx it_index; break; }
    if ctx.queue_family == 0xffff_ffff {
        log_error("% has no graphics queue family.", ctx.device_name);
        gfx_shutdown(ctx);
        return null;
    }

    // ---- the 1.3 features the lessons rely on ------------------------------------------------------
    have13: VkPhysicalDeviceVulkan13Features;
    have2:  VkPhysicalDeviceFeatures2;
    have2.pNext = *have13;
    vkGetPhysicalDeviceFeatures2(ctx.physical_device, *have2);
    if have13.dynamicRendering == 0 || have13.synchronization2 == 0 {
        log_error("% lacks dynamicRendering (%) or synchronization2 (%).", ctx.device_name, have13.dynamicRendering, have13.synchronization2);
        gfx_shutdown(ctx);
        return null;
    }

    want13: VkPhysicalDeviceVulkan13Features;
    want13.dynamicRendering = VK_TRUE;
    want13.synchronization2 = VK_TRUE;
    want2: VkPhysicalDeviceFeatures2;
    want2.pNext = *want13;

    // ---- logical device + queue + command pool ---------------------------------------------------
    priority := float.[1.0];
    qci: VkDeviceQueueCreateInfo;
    qci.queueFamilyIndex = ctx.queue_family;
    qci.queueCount       = 1;
    qci.pQueuePriorities = priority.data;

    device_exts: [1] *u8;
    device_exts[0] = VK_KHR_SWAPCHAIN_EXTENSION_NAME.data;

    dci: VkDeviceCreateInfo;
    dci.pNext                   = *want2;
    dci.queueCreateInfoCount    = 1;
    dci.pQueueCreateInfos       = *qci;
    dci.enabledExtensionCount   = device_exts.count;
    dci.ppEnabledExtensionNames = device_exts.data;

    result = vkCreateDevice(ctx.physical_device, *dci, null, *ctx.device);
    if result != .SUCCESS {
        log_error("vkCreateDevice failed on %: %", ctx.device_name, result);
        gfx_shutdown(ctx);
        return null;
    }
    vkGetDeviceQueue(ctx.device, ctx.queue_family, 0, *ctx.queue);

    cpci: VkCommandPoolCreateInfo;
    cpci.flags            = .RESET_COMMAND_BUFFER_BIT;
    cpci.queueFamilyIndex = ctx.queue_family;
    result = vkCreateCommandPool(ctx.device, *cpci, null, *ctx.command_pool);
    if result != .SUCCESS {
        log_error("vkCreateCommandPool failed: %", result);
        gfx_shutdown(ctx);
        return null;
    }

    return ctx;
}

// Destroys everything the context owns, in reverse order, and frees it. Returns the recorder's
// final counts so a caller can tell whether teardown itself reported anything (leaked objects
// surface here as validation errors). Messages recorded during teardown are printed, since
// the recorder dies with the context.
gfx_shutdown :: (ctx: *Gfx_Context) -> (errors: int, warnings: int) {
    before := ctx.recorder.messages.count;

    if ctx.device {
        vkDeviceWaitIdle(ctx.device);
        if ctx.command_pool  vkDestroyCommandPool(ctx.device, ctx.command_pool, null);
        vkDestroyDevice(ctx.device, null);
    }
    if ctx.messenger && ctx.destroy_messenger  ctx.destroy_messenger(ctx.instance, ctx.messenger, null);
    if ctx.instance  vkDestroyInstance(ctx.instance, null);

    for i: before..ctx.recorder.messages.count-1  print("    teardown: %\n", ctx.recorder.messages[i]);

    errors   := ctx.recorder.errors;
    warnings := ctx.recorder.warnings;
    for ctx.recorder.messages  free(it);
    array_free(ctx.recorder.messages);
    free(ctx.device_name);
    free(ctx);
    return errors, warnings;
}
