const std = @import("std");

// a writer like fixedbufferwriter but instead of erroring on
// overflow, silently just keeps increasing pos and writing nothing
const VsnprintfWriter = struct {
    buffer: []u8,
    pos: usize,

    pub const WriteError = error{};

    pub const Writer = std.io.Writer(*Self, WriteError, write);

    const Self = @This();

    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }
    pub fn write(self: *Self, bytes: []const u8) WriteError!usize {
        const write_start = std.math.min(self.pos, self.buffer.len);
        const write_range = self.buffer[write_start..];
        self.pos += bytes.len;

        std.mem.copy(u8, write_range, bytes[0..std.math.min(bytes.len, write_range.len)]);

        return bytes.len;
    }
};
pub fn vsnprintfWriter(out_ptr: []u8) VsnprintfWriter {
    return .{ .buffer = out_ptr, .pos = 0 };
}

test "vsnprintf_writer" {
    var demo_out = [_]u8{'?'} ** 25;

    var writer = vsnprintfWriter(&demo_out);
    const out = writer.writer();

    try out.writeAll("!" ** 10);
    std.testing.expectEqual(writer.pos, 10);
    std.testing.expectEqualStrings(writer.buffer, "!" ** 10 ++ "?" ** 15);
    try out.writeAll("!" ** 40);
    std.testing.expectEqual(writer.pos, 50);
    std.testing.expectEqualStrings(writer.buffer, "!" ** 25);
    try out.writeAll("!" ** 10);
    std.testing.expectEqual(writer.pos, 60);
    std.testing.expectEqualStrings(writer.buffer, "!" ** 25);
}
