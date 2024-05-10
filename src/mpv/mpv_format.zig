const c = @import("./c.zig");

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

    pub fn to(self: Self) c.mpv_format {
        return @as(c.mpv_format, @intFromEnum(self));
    }
};
