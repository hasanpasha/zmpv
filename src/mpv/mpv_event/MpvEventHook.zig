const c = @import("../c.zig");
const std = @import("std");
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
