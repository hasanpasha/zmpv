const c = @import("../c.zig");
const std = @import("std");
const testing = std.testing;
const mpv_event_utils = @import("./mpv_event_utils.zig");

const Self = @This();

name: []const u8,
id: u64,

pub fn from(data_ptr: *anyopaque) Self {
    const data = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_hook);

    return Self{
        .name = std.mem.sliceTo(data.name, 0),
        .id = data.id,
    };
}

test "MpvEventHook from" {
    var event_hook = c.mpv_event_hook{
        .id = 1,
        .name = "on_load",
    };
    const z_hook = Self.from(&event_hook);

    try testing.expect(z_hook.id == 1);
    try testing.expect(std.mem.eql(u8, z_hook.name, "on_load"));
}
