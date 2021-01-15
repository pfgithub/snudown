const std = @import("std");
const Builder = std.build.Builder;

fn addThings(a: anytype) void {
    a.linkLibC();
    a.addIncludeDir("src");
    a.addIncludeDir("html");
    inline for (.{
        "html/houdini_href_e.c",
        "html/houdini_html_e.c",
        "html/html.c",
        "html/html_smartypants.c",
        "src/autolink.c",
        "src/buffer.c",
        "src/markdown.c",
        "src/stack.c",
    }) |file| {
        a.addCSourceFile(file, &[_][]const u8{"-fno-sanitize=undefined"});
    }
}

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("entry_wasm", "src/entry_wasm.zig");
    lib.setBuildMode(mode);
    lib.setTarget(std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch @panic("err"));
    addThings(lib);
    lib.addCSourceFile("src/printf.c", &[_][]const u8{""});
    lib.install();

    var main_tests = b.addTest("src/entry_os.zig");
    addThings(main_tests);
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
