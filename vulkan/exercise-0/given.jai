// Exercise 0, given: the inventory lesson 0 walks through. Read it as a library, do not edit it.
// collect_inventory makes the five enumeration calls; print_inventory writes the report and names
// which of the three layers answered each query. The learner's part is exercise.jai.

#import "Basic";
#import "String";   // join
#import "Vulkan";

Layer_Info  :: struct { name: string; spec_version: u32; implementation_version: u32; description: string; extensions: [] string; }   // extensions: vkEnumerateInstanceExtensionProperties(name)
Device_Info :: struct { name: string; device_type: VkPhysicalDeviceType; api_version: u32; driver_version: u32; vendor_id: u32; device_extension_count: int; }
Inventory   :: struct { instance_version: u32; layers: [] Layer_Info; base_extensions: [] string; devices: [] Device_Info; }   // base_extensions: the pLayerName == null query

// Everything the loader, the layers and the drivers will say about this machine before a real
// instance exists. ok is false after a log_error naming the call that failed.
collect_inventory :: () -> (inv: Inventory, ok: bool) {
    inv: Inventory;

    // 1. The loader answers for itself: no driver has been opened yet.
    result := vkEnumerateInstanceVersion(*inv.instance_version);
    if result != .SUCCESS {
        log_error("vkEnumerateInstanceVersion failed: %", result);
        return inv, false;
    }

    // 2. Layers: the loader reads the manifests under /usr/share/vulkan/explicit_layer.d and
    //    implicit_layer.d (and $XDG_* equivalents). Two calls: count, then fill.
    layer_count: u32;
    result = vkEnumerateInstanceLayerProperties(*layer_count, null);
    if result != .SUCCESS {
        log_error("vkEnumerateInstanceLayerProperties (count) failed: %", result);
        return inv, false;
    }
    layer_props := NewArray(layer_count, VkLayerProperties);
    defer free(layer_props.data);
    result = vkEnumerateInstanceLayerProperties(*layer_count, layer_props.data);
    if result != .SUCCESS {
        log_error("vkEnumerateInstanceLayerProperties failed: %", result);
        return inv, false;
    }

    layers := NewArray(layer_count, Layer_Info);
    for layer_props {
        name := copy_string(to_string(it.layerName.data));
        extensions, ok := instance_extension_names(it.layerName.data);   // the layer's own list, from its manifest; the API's buffer is null-terminated, a Jai string is not
        if !ok  return inv, false;
        layers[it_index] = .{name, it.specVersion, it.implementationVersion, copy_string(to_string(it.description.data)), extensions};
    }
    inv.layers = layers;

    // 3. Extensions with no layer named: the loader merges its own, every driver's and every
    //    enabled implicit layer's into one list, without saying who contributed what.
    base, ok := instance_extension_names(null);
    if !ok  return inv, false;
    inv.base_extensions = base;

    // 4. Physical devices need an instance: this one has no layers and no extensions and lives
    //    only long enough to ask each driver what the kernel told it.
    app: VkApplicationInfo;
    app.pApplicationName = "exercise-0";
    app.apiVersion       = VK_API_VERSION_1_3;
    ici: VkInstanceCreateInfo;
    ici.pApplicationInfo = *app;
    instance: VkInstance;
    result = vkCreateInstance(*ici, null, *instance);
    if result != .SUCCESS {
        log_error("vkCreateInstance failed: %", result);
        return inv, false;
    }
    defer vkDestroyInstance(instance, null);

    device_count: u32;
    result = vkEnumeratePhysicalDevices(instance, *device_count, null);
    if result != .SUCCESS {
        log_error("vkEnumeratePhysicalDevices (count) failed: %", result);
        return inv, false;
    }
    physicals := NewArray(device_count, VkPhysicalDevice);
    defer free(physicals.data);
    result = vkEnumeratePhysicalDevices(instance, *device_count, physicals.data);
    if result != .SUCCESS {
        log_error("vkEnumeratePhysicalDevices failed: %", result);
        return inv, false;
    }

    devices := NewArray(device_count, Device_Info);
    for physicals {
        props: VkPhysicalDeviceProperties;
        vkGetPhysicalDeviceProperties(it, *props);
        extension_count: u32;
        result = vkEnumerateDeviceExtensionProperties(it, null, *extension_count, null);
        if result != .SUCCESS {
            log_error("vkEnumerateDeviceExtensionProperties failed on %: %", to_string(props.deviceName.data), result);
            return inv, false;
        }
        devices[it_index] = .{copy_string(to_string(props.deviceName.data)), props.deviceType, props.apiVersion, props.driverVersion, props.vendorID, extension_count};
    }
    inv.devices = devices;

    return inv, true;
}

// The names vkEnumerateInstanceExtensionProperties returns for one layer (null: the merged list).
instance_extension_names :: (layer: *u8) -> (names: [] string, ok: bool) {
    who := ifx layer then to_string(layer) else "null";
    count: u32;
    result := vkEnumerateInstanceExtensionProperties(layer, *count, null);
    if result != .SUCCESS {
        log_error("vkEnumerateInstanceExtensionProperties(%) (count) failed: %", who, result);
        return .[], false;
    }
    props := NewArray(count, VkExtensionProperties);
    defer free(props.data);
    result = vkEnumerateInstanceExtensionProperties(layer, *count, props.data);
    if result != .SUCCESS {
        log_error("vkEnumerateInstanceExtensionProperties(%) failed: %", who, result);
        return .[], false;
    }
    names := NewArray(count, string);
    for props  names[it_index] = copy_string(to_string(it.extensionName.data));
    return names, true;
}

// The report: one block per query, each headed by who answered it.
print_inventory :: (inv: Inventory) {
    print("instance version %   answered by: the loader\n", api_version_string(inv.instance_version));

    print("layers (%)   answered by: the loader, from the manifests\n", inv.layers.count);
    for inv.layers {
        print("  %  spec %  impl %  %\n", it.name, api_version_string(it.spec_version), it.implementation_version, it.description);
        print("    offers: %\n", join(..it.extensions, separator = ", "));
    }

    print("extensions (%)   answered by: the loader, the drivers and any enabled implicit layer, merged\n", inv.base_extensions.count);
    for inv.base_extensions  print("  %  from: %\n", it, join(..extension_sources(inv, it), separator = ", "));

    print("devices (%)   answered by: each driver (ICD), from the kernel\n", inv.devices.count);
    for inv.devices {
        print("  %  %  api %  driver %  vendor 0x%  device extensions %\n",
              it.name, it.device_type, api_version_string(it.api_version), driver_version_string(it.vendor_id, it.driver_version),
              formatInt(it.vendor_id, base = 16), it.device_extension_count);
    }
}
