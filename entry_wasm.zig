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

const MallocHeader = struct {
    magic: usize = 0xABCDEF,
    size: usize,
};
export fn malloc(size: usize) ?[*]u8 {
    const res = std.heap.page_allocator.alloc(u8, size + @sizeOf(MallocHeader)) catch return null;
    const mloc_h = @intToPtr(*MallocHeader, @ptrToInt(res.ptr));
    mloc_h.* = .{ .size = size };
    return res.ptr + @sizeOf(MallocHeader);
}
export fn calloc(num: usize, sizev: usize) ?[*]u8 {
    const size = num * sizev;
    const res = std.heap.page_allocator.alloc(u8, size + @sizeOf(MallocHeader)) catch return null;
    for (res) |*v| v.* = 0;
    const mloc_h = @intToPtr(*MallocHeader, @ptrToInt(res.ptr));
    mloc_h.* = .{ .size = size };
    return res.ptr + @sizeOf(MallocHeader);
}
export fn realloc(ptr_opt: ?[*]u8, size: usize) ?*c_void {
    const ptr = ptr_opt orelse return malloc(size);

    const start_ptr = ptr - @sizeOf(MallocHeader);
    const mloc_h = @intToPtr(*MallocHeader, @ptrToInt(start_ptr));
    if (mloc_h.magic != 0xABCDEF) @panic("bad malloc header");

    const total_area = start_ptr[0 .. mloc_h.size + @sizeOf(MallocHeader)];
    const realloc_result = std.heap.page_allocator.realloc(total_area, size) catch return null;

    const new_mloc_h = @intToPtr(*MallocHeader, @ptrToInt(realloc_result.ptr));
    if (new_mloc_h.magic != 0xABCDEF) @panic("bad copied malloc header");
    new_mloc_h.size = size;

    return realloc_result.ptr + @sizeOf(MallocHeader);
}
export fn free(ptr_opt: ?[*]u8) void {
    const ptr = ptr_opt orelse return;

    const start_ptr = ptr - @sizeOf(MallocHeader);
    const mloc_h = @intToPtr(*MallocHeader, @ptrToInt(start_ptr));
    if (mloc_h.magic != 0xABCDEF) @panic("bad malloc header");

    const total_area = ptr[0 .. mloc_h.size + @sizeOf(MallocHeader)];
    return std.heap.page_allocator.free(total_area);
}

const va_list = opaque {
    extern fn va_get_int(arg: *va_list) c_int;
};
export fn vsnprintf_zig(s: [*:0]u8, n: usize, format_in: [*:0]u8, arg: *va_list) c_int {
    const format = std.mem.span(format_in);
    const out_ptr = s[0..n];
    var fbs = std.io.fixedBufferStream(out_ptr);
    const out = fbs.writer();

    var read_char: usize = 0;

    while (read_char < format.len) : (read_char += 1) {
        if (format[read_char] == '%') {
            read_char += 1;
            if (format[read_char] == 'd') {
                const int_to_write = arg.va_get_int();
                out.print("{}", .{int_to_write}) catch @panic("too long");
                continue;
            } else {
                @panic("TODO");
            }
        }
        out.writeByte(format[read_char]) catch @panic("too long");
    }
    out.writeByte(0) catch @panic("too long");

    return @intCast(c_int, fbs.pos - 1);
}
export fn allocString(len: usize) ?[*]u8 {
    const alloc = std.heap.page_allocator;
    const slice = alloc.alloc(u8, len) catch @panic("oom");
    return slice.ptr;
}
export fn markdownToHTML(markdown: [*]u8, markdown_len: usize) [*]u8 {
    const alloc = std.heap.page_allocator;
    const duped = alloc.dupeZ(u8, markdown[0..markdown_len]) catch @panic("oom");
    const ob = parse(alloc, duped);
    return ob.ptr;
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    debugprint("Panic! {s}\n", .{msg});
    debugpanic();
}

pub export fn main() void {}
