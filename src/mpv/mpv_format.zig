const c = @import("./c.zig");
const testing = @import("std").testing;

pub const MpvFormat = enum(u8) {
    const Self = @This();

    None = 0,
    String = 1,
    OSDString = 2,
    Flag = 3,
    INT64 = 4,
    Double = 5,
    Node = 6,
    NodeArray = 7,
    NodeMap = 8,
    ByteArray = 9,

    pub fn from(format: c.mpv_format) Self {
        return @enumFromInt(format);
    }

    pub fn to(self: Self) c.mpv_format {
        return @as(c.mpv_format, @intFromEnum(self));
    }

    pub inline fn CDataType(comptime self: Self) type {
        return switch (self) {
            .String, .OSDString => [*c]u8,
            .Flag => c_int,
            .INT64 => i64,
            .Double => f64,
            .Node => c.mpv_node,
            .NodeArray, .NodeMap => c.mpv_node_list,
            .ByteArray => c.mpv_byte_array,
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
    try testing.expect(MpvFormat.to(.None) == c.MPV_FORMAT_NONE);
    try testing.expect(MpvFormat.to(.INT64) == c.MPV_FORMAT_INT64);
    try testing.expect(MpvFormat.to(.Double) == c.MPV_FORMAT_DOUBLE);
    try testing.expect(MpvFormat.to(.Node) == c.MPV_FORMAT_NODE);
}

test "MpvFormat ctype" {
    try testing.expect(MpvFormat.CDataType(.ByteArray) == c.mpv_byte_array);
    try testing.expect(MpvFormat.CDataType(.String) == [*c]u8);
    try testing.expect(MpvFormat.CDataType(.NodeMap) == c.mpv_node_list);
    try testing.expect(MpvFormat.CDataType(.INT64) != c_int);
}
