// Exercise 1: your part. Fill in the two procedures; their signatures are fixed and cases.jai
// checks them. The contract is in README.md; the mechanism is in lesson 1.

#import "Basic";
#import "Vulkan";

// graphics_family: the first family with GRAPHICS_BIT; ok is false when none has it.
// transfer_family: the first family with TRANSFER_BIT and neither GRAPHICS_BIT nor COMPUTE_BIT;
// the graphics family when there is none.
choose_queue_families :: (families: [] VkQueueFamilyProperties) -> (choice: Queue_Choice, ok: bool) {
    // TODO (lesson 1, step 3): a family is a set of queues with the same capabilities; pick two.
    return .{}, false;
}

// One VkDeviceQueueCreateInfo per distinct family, one queue each, priority 1.0;
// VkPhysicalDeviceVulkan13Features with dynamicRendering and synchronization2 chained through
// VkPhysicalDeviceFeatures2 in pNext; no device extensions. A null device after a log_error when
// vkCreateDevice fails.
create_device :: (physical: VkPhysicalDevice, choice: Queue_Choice) -> (device: VkDevice, graphics: VkQueue, transfer: VkQueue) {
    // TODO (lesson 1, steps 4 and 5): the ICD opens a kernel context; each queue is a scheduled channel.
    return null, null, null;
}
