const std = @import("std");
usingnamespace @import("special_c.zig");
usingnamespace @import("test.zig");

// these are part of the c standard library. I shouldn't have to reimplement these and I'm
// not sure why I do. it might be a zig bug.

// returns 0 on eql, -1/1 on lt/gt. this code does not do that.
export fn strncasecmp(s1: [*:0]const u8, s2: [*:0]const u8, n: usize) c_int {
    const is_eql = std.ascii.eqlIgnoreCase(s1[0..n], s2[0..n]);
    // debugprint("strncasecomp on `{s}` == `{s}` → {}", .{ s1[0..n], s2[0..n], is_eql });
    return if (is_eql) return 0 else return 100;
}
export fn isalnum(arg: c_int) c_int {
    // debugprint("isalnum on `{c}` : ", .{@intCast(i8, arg)});
    return @boolToInt(std.ascii.isAlNum(@bitCast(u8, @intCast(i8, arg))));
}
export fn ispunct(arg: c_int) c_int {
    return @boolToInt(std.ascii.isPunct(@bitCast(u8, @intCast(i8, arg))));
}
export fn isxdigit(arg: c_int) c_int {
    return @boolToInt(std.ascii.isXDigit(@bitCast(u8, @intCast(i8, arg))));
}
export fn tolower(arg: c_int) c_int {
    return std.ascii.toLower(@bitCast(u8, @intCast(i8, arg)));
}
export fn strchr(str: [*:0]const u8, char: c_int) ?[*:0]const u8 {
    // debugprint("strchr on `{s}`, `{c}`", .{ str, @bitCast(u8, @intCast(i8, char)) });
    // return str[indexOf(u8, str, char) orelse return null..].ptr
    var ptr = str;
    while (true) : (ptr += 1) {
        if (ptr[0] == char) return ptr;
        if (ptr[0] == 0) return null;
    }
    unreachable;
}
export fn strtol(str: [*:0]const u8, eptr: ?*[*:0]const u8, basev: c_int) c_long {
    const base = @bitCast(u8, @intCast(i8, basev));
    var res: c_long = 0;
    var cur = str;
    if (base == 0) @panic("unsupported");
    if (cur[0] == '+' or cur[0] == '-') @panic("unsupported");

    while (@as(?u8, std.fmt.charToDigit(cur[0], base) catch null)) |num| : (cur += 1) {
        res *= base;
        res += num;
    }
    if (eptr) |v| v.* = cur;
    return res;
}

// export fn vsnprintf(s: [*:0]u8, n: usize, format: [*:0]const u8, arg: c.va_list) {

// }

// var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var arena: ?std.heap.ArenaAllocator = null;
fn getAlloc() *std.mem.Allocator {
    // return &gpa.allocator;
    if (arena == null) arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    return &arena.?.allocator;
}

const MallocHeader = struct {
    magic: usize = 0xABCDEF,
    size: usize,
    comptime {
        if (@alignOf(MallocHeader) != @alignOf(c_int)) @compileError("oops");
    }
};
export fn malloc(size: usize) ?[*]align(@alignOf(c_int)) u8 {
    const alloc = getAlloc();
    const res = alloc.allocWithOptions(u8, size + @sizeOf(MallocHeader), @alignOf(c_int), null) catch return null;
    const mloc_h = @ptrCast(*MallocHeader, res.ptr);
    mloc_h.* = .{ .size = size };
    return res.ptr + @sizeOf(MallocHeader);
}
export fn calloc(num: usize, sizev: usize) ?[*]align(@alignOf(c_int)) u8 {
    const alloc = getAlloc();
    const size = num * sizev;
    const res = alloc.allocWithOptions(u8, size + @sizeOf(MallocHeader), @alignOf(c_int), null) catch return null;
    for (res) |*v| v.* = 0;
    const mloc_h = @ptrCast(*MallocHeader, res.ptr);
    mloc_h.* = .{ .size = size };
    return res.ptr + @sizeOf(MallocHeader);
}
export fn realloc(ptr_opt: ?[*]align(@alignOf(c_int)) u8, size: usize) ?[*]align(@alignOf(c_int)) u8 {
    const alloc = getAlloc();
    const ptr = ptr_opt orelse return malloc(size);

    const start_ptr = ptr - @sizeOf(MallocHeader);
    const mloc_h = @ptrCast(*MallocHeader, start_ptr);
    if (mloc_h.magic != 0xABCDEF) @panic("bad malloc header");

    const total_area = start_ptr[0 .. mloc_h.size + @sizeOf(MallocHeader)];
    const realloc_result = alloc.realloc(total_area, size + @sizeOf(MallocHeader)) catch return null;

    const new_mloc_h = @ptrCast(*MallocHeader, realloc_result.ptr);
    if (new_mloc_h.magic != 0xABCDEF) @panic("bad copied malloc header");
    new_mloc_h.size = size;

    return realloc_result.ptr + @sizeOf(MallocHeader);
}
export fn free(ptr_opt: ?[*]align(@alignOf(c_int)) u8) void {
    const alloc = getAlloc();

    const ptr = ptr_opt orelse return;

    const start_ptr = ptr - @sizeOf(MallocHeader);
    const mloc_h = @ptrCast(*MallocHeader, start_ptr);
    if (mloc_h.magic != 0xABCDEF) @panic("bad malloc header");

    const total_area = start_ptr[0 .. mloc_h.size + @sizeOf(MallocHeader)];
    alloc.free(total_area);
}

const va_list = opaque {
    extern fn va_get_int(arg: *va_list) c_int;
};

const w = @import("wasm/vsnprintf_writer.zig");

export fn vsnprintf_zig(s: [*]u8, n: usize, format_in: [*:0]u8, arg: *va_list) c_int {
    const format = std.mem.span(format_in);
    const out_ptr = s[0..n];
    var fbs = w.vsnprintfWriter(out_ptr);
    const out = fbs.writer();

    var read_char: usize = 0;

    while (read_char < format.len) : (read_char += 1) {
        if (format[read_char] == '%') {
            read_char += 1;
            if (format[read_char] == 'd') {
                const int_to_write = arg.va_get_int();
                out.print("{}", .{int_to_write}) catch unreachable;
                continue;
            } else {
                @panic("TODO");
            }
        }
        out.writeByte(format[read_char]) catch unreachable;
    }
    out.writeByte(0) catch unreachable;

    return @intCast(c_int, fbs.pos - 1);
}
export fn allocString(len: usize) ?[*]u8 {
    const alloc = getAlloc();
    const slice = alloc.alloc(u8, len) catch @panic("oom");
    return slice.ptr;
}
export fn freeText(ptr: [*]u8, len: usize) void {
    const alloc = getAlloc();
    alloc.free(ptr[0..len]);
}
export fn markdownToHTML(markdown: [*]u8, markdown_len: usize) [*]u8 {
    const alloc = getAlloc();
    const duped = alloc.dupeZ(u8, markdown[0..markdown_len]) catch @panic("oom");
    const ob = parse(alloc, duped);
    return ob.ptr;
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    debugprint("Panic! {s}\n", .{msg});
    debugpanic(msg.ptr, msg.len);
}

pub export fn main() void {}
