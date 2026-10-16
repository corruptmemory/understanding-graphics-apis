// The test runner: one fresh context per case, one line per case, a summary, an exit code.
//
// Arguments it understands (everything else is ignored):
//   -verbose           print every recorded validation message, not only on failure
//   -capture <path>    write the last readback of the run to <path> as a PNG (target.jai)

capture_path: string;
verbose      := false;

libc   :: #library,system "libc";
getenv :: (name: *u8) -> *u8 #foreign libc;

display_available :: () -> bool {
    d := getenv("DISPLAY");
    return d != null && d[0] != 0;
}

run_tests :: (cases: [] Test_Case, args: [] string) -> s32 {   // an exit code
    i := 1;   // args[0] is the binary
    while i < args.count {
        if args[i] == "-verbose" {
            verbose = true;
        } else if args[i] == "-capture" && i + 1 < args.count {
            capture_path = args[i + 1];
            i += 1;
        }
        i += 1;
    }

    passed, failed, skipped := 0, 0, 0;
    for test: cases {
        if test.needs_display && !display_available() {
            print("SKIP %: DISPLAY not set\n", test.name);
            skipped += 1;
            continue;
        }

        ctx := gfx_init(.{sync_validation = test.sync_validation});
        if !ctx {
            print("FAIL %: could not create a device\n", test.name);
            failed += 1;
            continue;
        }

        ok := test.proc(ctx);

        reason := "";
        if !ok {
            reason = "case returned false";
        } else if ctx.recorder.errors != test.expect_validation_errors {
            reason = tprint("% validation errors, expected %", ctx.recorder.errors, test.expect_validation_errors);
        } else if test.warnings_fatal && ctx.recorder.warnings != 0 {
            reason = tprint("% validation warnings", ctx.recorder.warnings);
        }

        if reason.count > 0 || verbose {
            for msg: ctx.recorder.messages  print("    %\n", msg);
        }

        errors_before := ctx.recorder.errors;
        errors_after  := gfx_shutdown(ctx);
        if reason.count == 0 && errors_after != errors_before {
            reason = tprint("% validation errors at teardown (leaked objects?)", errors_after - errors_before);
        }

        if reason.count > 0 {
            print("FAIL %: %\n", test.name, reason);
            failed += 1;
        } else {
            print("PASS %\n", test.name);
            passed += 1;
        }
        reset_temporary_storage();
    }

    print("% passed, % failed, % skipped\n", passed, failed, skipped);
    if failed > 0  return 1;
    return 0;
}
