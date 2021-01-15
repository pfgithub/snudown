// test.zig -lc -Isrc -Ihtml --verbose-cimport -cflags -fno-sanitize=undefined -- src/*.c html/*.c

const std = @import("std");
comptime {
    _ = @import("snudown/html_entities.zig");
}

const c = @cImport({
    @cInclude("markdown.h");
    @cInclude("html.h");
    @cInclude("autolink.h");
});

// zig fmt: off
const snudown_default_render_flags = 0
    | c.HTML_SKIP_HTML
    | c.HTML_SKIP_IMAGES
    | c.HTML_SAFELINK
    | c.HTML_ESCAPE
    | c.HTML_USE_XHTML
;

const snudown_default_md_flags = 0
    | c.MKDEXT_NO_INTRA_EMPHASIS
    | c.MKDEXT_SUPERSCRIPT
    | c.MKDEXT_AUTOLINK
    | c.MKDEXT_STRIKETHROUGH
    | c.MKDEXT_TABLES
    | c.MKDEXT_FENCED_CODE
;
// zig fmt: on

fn snudown_link_attr(ob: [*c]c.struct_buf, link: [*c]const c.struct_buf, opaquev: ?*c_void) callconv(.C) void {
    // const literal = " rel=\"noreferrer noopener\"";
    // c.bufput(ob, literal, literal.len);
}

pub var html_element_whitelist = &[_]?[*c]const u8{ "tr", "th", "td", "table", "tbody", "thead", "tfoot", "caption", null };
pub var html_attr_whitelist = &[_]?[*c]const u8{ "colspan", "rowspan", "cellspacing", "cellpadding", "scope", null };

pub fn parse(alloc: *std.mem.Allocator, inmd: [:0]const u8) [:0]u8 {
    var callbacks: c.struct_sd_callbacks = undefined;
    var options: c.struct_html_renderopt = undefined;
    c.sdhtml_renderer(
        &callbacks,
        &options,
        snudown_default_render_flags,
    );

    options.link_attributes = snudown_link_attr;
    options.html_element_whitelist = @intToPtr([*c][*c]u8, @ptrToInt(html_element_whitelist));
    options.html_attr_whitelist = @intToPtr([*c][*c]u8, @ptrToInt(html_attr_whitelist));

    const parser = c.sd_markdown_new(snudown_default_md_flags, 16, 64, &callbacks, &options);

    const ob: *c.struct_buf = c.bufnew(128);
    defer c.bufrelease(ob);

    c.sd_markdown_render(ob, inmd.ptr, inmd.len, parser);

    const dupeval = if (ob.size == 0) "" else ob.data[0..ob.size];

    const res = alloc.dupeZ(u8, dupeval) catch @panic("oom");
    return res;
}

extern fn debugprints(str: [*]const u8, len: usize) callconv(.C) void;
pub extern fn debugpanic(str: [*]const u8, len: usize) callconv(.C) noreturn;
comptime {
    _ = struct {
        export fn debugprint(str: [*:0]const u8) void {
            debugprints(str, std.mem.span(str).len);
        }
    };
}

pub fn debugprint(comptime fmt: []const u8, args: anytype) void {
    var print_buf = [_]u8{0} ** 200;
    const str = std.fmt.bufPrint(&print_buf, fmt, args) catch @panic("print too long");
    debugprints(str.ptr, str.len);
}
