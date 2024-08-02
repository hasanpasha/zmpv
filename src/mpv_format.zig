const Allocator = @import("std").mem.Allocator;
const AllocatorError = Allocator.Error;
const c = @import("c.zig");
const testing = @import("std").testing;

pub const MpvFormat = enum(c.mpv_format) {
    None = c.MPV_FORMAT_NONE,
    String = c.MPV_FORMAT_STRING,
    OSDString = c.MPV_FORMAT_OSD_STRING,
    Flag = c.MPV_FORMAT_FLAG,
    INT64 = c.MPV_FORMAT_INT64,
    Double = c.MPV_FORMAT_DOUBLE,
    Node = c.MPV_FORMAT_NODE,
    NodeArray = c.MPV_FORMAT_NODE_ARRAY,
    NodeMap = c.MPV_FORMAT_NODE_MAP,
    ByteArray = c.MPV_FORMAT_BYTE_ARRAY,

    pub fn from(format: c.mpv_format) MpvFormat {
        return @enumFromInt(format);
    }

    pub fn to_c(self: MpvFormat) c.mpv_format {
        return @intFromEnum(self);
    }

    pub fn alloc_c_value(self: MpvFormat, allocator: Allocator) AllocatorError!*anyopaque {
        return switch (self) {
            .String, .OSDString => @ptrCast(try allocator.create([*:0]u8)),
            .Flag => @ptrCast(try allocator.create(c_int)),
            .INT64 => @ptrCast(try allocator.create(i64)),
            .Double => @ptrCast(try allocator.create(f64)),
            .Node => @ptrCast(try allocator.create(c.mpv_node)),
            .NodeArray, .NodeMap => @ptrCast(try allocator.create(c.mpv_node_list)),
            .ByteArray => @ptrCast(try allocator.create(c.mpv_byte_array)),
            .None => @panic("WTH ARE YOU DOING!!"),
        };
    }
};

test "MpvFormat from" {
    try testing.expect(MpvFormat.from(c.MPV_FORMAT_NONE) == .None);
    try testing.expect(MpvFormat.from(c.MPV_FORMAT_STRING) == .String);
    try testing.expect(MpvFormat.from(c.MPV_FORMAT_NODE) == .Node);
    try testing.expect(MpvFormat.from(c.MPV_FORMAT_NODE_ARRAY) == .NodeArray);
}

test "MpvFormat to" {
    try testing.expect(MpvFormat.to_c(.None) == c.MPV_FORMAT_NONE);
    try testing.expect(MpvFormat.to_c(.INT64) == c.MPV_FORMAT_INT64);
    try testing.expect(MpvFormat.to_c(.Double) == c.MPV_FORMAT_DOUBLE);
    try testing.expect(MpvFormat.to_c(.Node) == c.MPV_FORMAT_NODE);
}