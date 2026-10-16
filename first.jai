// The build program. Everything is driven from here:
//
//     ~/jai/jai/bin/jai-linux first.jai - <verb> [args]
//
// Run it from anywhere: every path below is anchored on this file's directory, because a
// relative path given to the compiler is resolved against the main source file, not the cwd.
//
// Failure is signalled with compiler_set_workspace_status(.FAILED) and a plain return,
// never exit(): the compiler buffers a metaprogram's stdout and drops it on exit(), so a
// usage message printed before exit(1) would never be seen. (log_error goes to stderr
// immediately and does survive, which is why failures below use it.)
//
// Targets are directories named <api>/<name> (e.g. vulkan/exercise-3). A target's
// main.jai is its windowed program, its tests.jai its headless test program; both are
// built into build/<api>-<name>[ -tests ]. A target's files reference each other with
// #load, so the target directory itself is not an import path.

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "Sort";
#import "String";

#load "tools/lesson-check/check.jai";   // check_all, for the check-lessons verb

ROOT :: #filepath;   // absolute, trailing slash

VERBS :: string.[
    "help                               print this table",
    "build <api>/<name>                 compile <api>/<name>/main.jai to build/<api>-<name> (shaders first)",
    "run <api>/<name> [args...]         build, then run the binary with args",
    "test <api>/<name> [args...]        compile tests.jai to build/<api>-<name>-tests and run it headlessly",
    "test-all                           run every <api>/<name>/tests.jai under vulkan/, directx/, metal/, tools/",
    "capture <api>/<name> [path]        run the tests with -capture; the last readback lands in path (default build/<api>-<name>.png)",
    "shaders <api>/<name>               glslc every shaders/*.vert|*.frag|*.comp into <target>/.build/spv/",
    "check-lessons                      check every lessons/**/*.html, index.html and spine.js against the markup contract",
    "concept-map                        regenerate lessons/concept-map.html from every lesson's sidebars",
    "regen-vulkan-bindings              refresh modules/Vulkan/source from /usr/include/vulkan and regenerate",
];

// Environment handed to every test binary: keep implicit layers (overlays, device-select)
// out of the validation recorder. This is the loader's own interface, set by the runner.
TEST_ENV :: string.["VK_LOADER_LAYERS_DISABLE=~implicit~"];

#run {
    set_build_options_dc(.{do_output = false});
    args := get_build_options().compile_time_command_line;

    if args.count == 0 {
        print_usage();
        return;
    }

    verb := args[0];
    rest: [] string;
    if args.count > 1  rest = array_view(args, 1, args.count - 1);

    ok := false;
    if verb == {
      case "help";
        print_usage();
        ok = true;

      case "build";
        target, found := require_target(verb, rest);
        ok = found && build_target(target, "main.jai", "");

      case "run";
        target, found := require_target(verb, rest);
        ok = found && build_target(target, "main.jai", "")
                   && run_binary(binary_path(target, ""), array_view(rest, 1, rest.count - 1), .[]) == 0;

      case "test";
        target, found := require_target(verb, rest);
        ok = found && build_target(target, "tests.jai", "-tests")
                   && run_binary(binary_path(target, "-tests"), array_view(rest, 1, rest.count - 1), TEST_ENV) == 0;

      case "test-all";
        ok = test_all();

      case "capture";
        target, found := require_target(verb, rest);
        path := ifx rest.count > 1 then rest[1] else tprint("%1build/%2.png", ROOT, binary_name(target, ""));
        file_delete(path);   // a stale capture must never pass for a fresh one
        ok = found && build_target(target, "tests.jai", "-tests")
                   && run_binary(binary_path(target, "-tests"), .["-capture", path], TEST_ENV) == 0;
        if ok && !file_exists(path) {
            log_error("capture: % was not written; did any test case call readback?", path);
            ok = false;
        }
        if ok  print("capture: %\n", path);

      case "shaders";
        target, found := require_target(verb, rest);
        ok = found && compile_shaders(target);

      case "check-lessons";
        findings, pages := check_all(ROOT);
        for findings  print("%:%: %\n", it.path, it.line, it.message);
        print("% pages checked, % findings\n", pages, findings.count);
        ok = findings.count == 0;

      case "concept-map";
        entries := collect_sidebars(ROOT);
        path := tprint("%1lessons/concept-map.html", ROOT);
        ok = write_entire_file(path, concept_map_html(entries));
        if ok  print("concept-map: lessons/concept-map.html (% entries)\n", entries.count);
        else   log_error("concept-map: could not write %", path);

      case "regen-vulkan-bindings";
        ok = regen_vulkan_bindings();

      case;
        log_error("Unknown verb '%'.", verb);
        print_usage();
    }

    if !ok  compiler_set_workspace_status(.FAILED);   // exit code 1, printed output kept
}

print_usage :: () {
    print("usage: jai first.jai - <verb> [args]\n\n");
    for VERBS  print("  %\n", it);
    print("\n");
}

// A target is "<api>/<name>", given as the verb's first argument.
require_target :: (verb: string, rest: [] string) -> (target: string, ok: bool) {
    if rest.count == 0 {
        log_error("'%' needs a target, e.g. `first.jai - % vulkan/harness-check`.", verb, verb);
        return "", false;
    }
    target := rest[0];
    if !file_exists(tprint("%1%2", ROOT, target)) {
        log_error("No such target directory: %", target);
        return "", false;
    }
    return target, true;
}

target_dir   :: (target: string) -> string { return tprint("%1%2/", ROOT, target); }
binary_name  :: (target: string, suffix: string) -> string { return tprint("%1%2", replace(target, "/", "-"), suffix); }
binary_path  :: (target: string, suffix: string) -> string { return tprint("%1build/%2", ROOT, binary_name(target, suffix)); }

// Compile <target>/<entry> into build/<api>-<name><suffix>. Shaders first when the target has any.
build_target :: (target: string, entry: string, suffix: string) -> bool {
    if !compile_shaders(target)  return false;

    source := tprint("%1%2", target_dir(target), entry);
    if !file_exists(source) {
        log_error("Target '%' has no %: expected %", target, entry, source);
        return false;
    }

    name := binary_name(target, suffix);
    return compile_workspace(name, source, tprint("%1.build", target_dir(target)));
}

// One Jai workspace: modules/ ahead of the distribution's import path, debug build,
// fatal overflow checks, binary in build/, intermediates where the caller says.
compile_workspace :: (name: string, source: string, intermediate: string) -> bool {
    w := compiler_create_workspace(name);
    if !w {
        log_error("Could not create a workspace for %", name);
        return false;
    }

    opts := get_build_options(w);
    copy_commonly_propagated_fields(get_build_options(), *opts);

    import_path: [..] string;
    array_add(*import_path, tprint("%1modules", ROOT));
    for opts.import_path  array_add(*import_path, it);
    opts.import_path = import_path;

    set_optimization(*opts, .DEBUG);
    opts.arithmetic_overflow_check = .FATAL;
    opts.output_executable_name    = name;
    opts.output_path               = tprint("%1build", ROOT);
    opts.intermediate_path         = intermediate;
    make_directory_if_it_does_not_exist(opts.output_path, recursive = true);
    make_directory_if_it_does_not_exist(opts.intermediate_path, recursive = true);
    set_build_options(opts, w);

    compiler_begin_intercept(w);
    add_build_file(source, w);

    ok := true;
    while true {
        message := compiler_wait_for_message();
        if message.kind == .COMPLETE {
            mc := cast(*Message_Complete) message;
            if mc.error_code != .NONE  ok = false;
            break;
        }
    }
    compiler_end_intercept(w);

    if !ok  log_error("Build of % failed (see errors above).", name);
    return ok;
}

// glslc every GLSL source under <target>/shaders/ into <target>/.build/spv/<file>.spv.
// Stops at the first failure so a stale .spv is never used by a build that follows.
compile_shaders :: (target: string) -> bool {
    shaders_dir := tprint("%1shaders", target_dir(target));
    if !file_exists(shaders_dir)  return true;   // nothing to do

    out_dir := tprint("%1.build/spv", target_dir(target));
    make_directory_if_it_does_not_exist(out_dir, recursive = true);

    for file_list(shaders_dir) {
        if !(ends_with(it, ".vert") || ends_with(it, ".frag") || ends_with(it, ".comp"))  continue;

        out := tprint("%1/%2.spv", out_dir, path_filename(it));
        result, output, error := run_command("glslc", "--target-env=vulkan1.3", "-o", out, it, capture_and_return_output = true);
        if result.exit_code != 0 {
            log_error("glslc failed on %:\n%\n%", it, output, error);
            return false;
        }
        print("shaders: % -> %\n", path_filename(it), out);
    }
    return true;
}

// Run a binary with an environment prefix; returns its exit code.
run_binary :: (path: string, args: [] string, env: [] string) -> s32 {
    command: [..] string;
    array_add(*command, "env");
    for env   array_add(*command, it);
    array_add(*command, path);
    for args  array_add(*command, it);

    result := run_command(.. command);
    if result.type != .EXITED {
        log_error("% did not exit normally (signal %).", path, result.signal);
        return 1;
    }
    return result.exit_code;
}

// Every target with a tests.jai, in sorted order; one summary line each, then a total.
test_all :: () -> bool {
    targets: [..] string;
    for api: string.["vulkan", "directx", "metal", "tools"] {
        dir := tprint("%1%2", ROOT, api);
        if !file_exists(dir)  continue;
        for file_list(dir, recursive = true) {
            if !ends_with(it, "/tests.jai")  continue;
            rel := slice(it, ROOT.count, it.count - ROOT.count - "/tests.jai".count);   // "<api>/<name>"
            array_add(*targets, copy_string(rel));
        }
    }
    quick_sort(targets, compare_strings);

    failed := 0;
    for targets {
        passed := build_target(it, "tests.jai", "-tests")
               && run_binary(binary_path(it, "-tests"), .[], TEST_ENV) == 0;
        print("%: %\n", it, ifx passed then "ok" else "FAILED");
        if !passed  failed += 1;
    }
    print("% targets, % failed\n", targets.count, failed);
    return failed == 0;
}

// Refresh the committed header snapshot, regenerate the bindings, then build and run smoke.jai.
regen_vulkan_bindings :: () -> bool {
    module_dir := tprint("%1modules/Vulkan/", ROOT);

    for string.["vulkan.h", "vulkan_core.h", "vk_platform.h"] {
        src := tprint("/usr/include/vulkan/%", it);
        data, ok := read_entire_file(src);
        if !ok {
            log_error("Could not read % (is vulkan-headers installed?)", src);
            return false;
        }
        if !write_entire_file(tprint("%1source/%2", module_dir, it), data) {
            log_error("Could not write %1source/%2", module_dir, it);
            return false;
        }
    }

    jai := tprint("%/bin/jai-linux", compiler_get_base_path());   // base path has no trailing slash
    result := run_command(jai, "generate.jai", working_directory = module_dir);
    if result.exit_code != 0 {
        log_error("generate.jai failed (exit %).", result.exit_code);
        return false;
    }

    if !compile_workspace("vulkan-bindings-smoke", tprint("%1smoke.jai", module_dir), tprint("%1.build", module_dir))  return false;
    return run_binary(tprint("%1build/vulkan-bindings-smoke", ROOT), .[], .[]) == 0;
}
