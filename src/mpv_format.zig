const c = @import("./c.zig");
const testing = @import("std").testing;

pub const MpvFormat = enum(c.mpv_format) {
    const Self = @This();

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

    pub fn from(format: c.mpv_format) Self {
        return @enumFromInt(format);
    }

    pub fn to_c(self: Self) c.mpv_format {
        return @intFromEnum(self);
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
    try testing.expect(MpvFormat.to_c(.None) == c.MPV_FORMAT_NONE);
    try testing.expect(MpvFormat.to_c(.INT64) == c.MPV_FORMAT_INT64);
    try testing.expect(MpvFormat.to_c(.Double) == c.MPV_FORMAT_DOUBLE);
    try testing.expect(MpvFormat.to_c(.Node) == c.MPV_FORMAT_NODE);
}

test "MpvFormat ctype" {
    try testing.expect(MpvFormat.CDataType(.ByteArray) == c.mpv_byte_array);
    try testing.expect(MpvFormat.CDataType(.String) == [*c]u8);
    try testing.expect(MpvFormat.CDataType(.NodeMap) == c.mpv_node_list);
    try testing.expect(MpvFormat.CDataType(.INT64) != c_int);
}
