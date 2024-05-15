const MpvNode = @import("../MpvNode.zig");
const std = @import("std");
const c = @import("../c.zig");
const mpv_event_utils = @import("./mpv_event_utils.zig");

const Self = @This();

result: MpvNode,
allocator: std.mem.Allocator,

pub fn from(data_ptr: *anyopaque, allocator: std.mem.Allocator) !Self {
    const data = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_command);

    return Self{
        .result = try MpvNode.from(@constCast(&data.result), allocator),
        .allocator = allocator,
    };
}

pub fn free(self: Self) void {
    self.result.free();
}
