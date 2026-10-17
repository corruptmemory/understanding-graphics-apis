// Exercise 1, reference solution: choose the families, create the device with one queue per family.

#import "Basic";
#import "Vulkan";

// graphics_family: the first family with GRAPHICS_BIT; ok is false when none has it.
// transfer_family: the first family with TRANSFER_BIT and neither GRAPHICS_BIT nor COMPUTE_BIT;
// the graphics family when there is none.
choose_queue_families :: (families: [] VkQueueFamilyProperties) -> (choice: Queue_Choice, ok: bool) {
    graphics := -1;
    transfer := -1;
    for families {
        if graphics < 0 && (it.queueFlags & .GRAPHICS_BIT)  graphics = it_index;
        if transfer < 0 && (it.queueFlags & .TRANSFER_BIT) && !(it.queueFlags & (.GRAPHICS_BIT | .COMPUTE_BIT))  transfer = it_index;
    }
    if graphics < 0  return .{}, false;
    if transfer < 0  transfer = graphics;
    return .{xx graphics, xx transfer}, true;
}

// One VkDeviceQueueCreateInfo per distinct family, one queue each, priority 1.0; the 1.3 features
// the lessons rely on chained through VkPhysicalDeviceFeatures2; no device extensions.
create_device :: (physical: VkPhysicalDevice, choice: Queue_Choice) -> (device: VkDevice, graphics: VkQueue, transfer: VkQueue) {
    priority := float.[1.0];
    qcis: [2] VkDeviceQueueCreateInfo;
    qcis[0].queueFamilyIndex = choice.graphics_family;
    qcis[0].queueCount       = 1;
    qcis[0].pQueuePriorities = priority.data;
    qcis[1].queueFamilyIndex = choice.transfer_family;
    qcis[1].queueCount       = 1;
    qcis[1].pQueuePriorities = priority.data;
    family_count: u32 = 1;
    if choice.transfer_family != choice.graphics_family  family_count = 2;

    features13: VkPhysicalDeviceVulkan13Features;
    features13.dynamicRendering = VK_TRUE;
    features13.synchronization2 = VK_TRUE;
    features2: VkPhysicalDeviceFeatures2;
    features2.pNext = *features13;

    dci: VkDeviceCreateInfo;
    dci.pNext                = *features2;
    dci.queueCreateInfoCount = family_count;
    dci.pQueueCreateInfos    = qcis.data;

    device: VkDevice;
    result := vkCreateDevice(physical, *dci, null, *device);
    if result != .SUCCESS {
        log_error("vkCreateDevice failed: %", result);
        return null, null, null;
    }

    graphics, transfer: VkQueue;
    vkGetDeviceQueue(device, choice.graphics_family, 0, *graphics);
    vkGetDeviceQueue(device, choice.transfer_family, 0, *transfer);
    return device, graphics, transfer;
}
