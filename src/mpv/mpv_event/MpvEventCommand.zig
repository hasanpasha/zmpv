const MpvNode = @import("../MpvNode.zig");
const std = @import("std");
const testing = std.testing;
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

test "MpvEventCommand from" {
    const allocator = testing.allocator;
    const command_result = c.mpv_node{
        .format = c.MPV_FORMAT_DOUBLE,
        .u = .{ .double_ = 3.14 },
    };
    var command_event = c.mpv_event_command{
        .result = command_result,
    };
    const z_command = try Self.from(&command_event, allocator);
    defer z_command.free();

    try testing.expect(z_command.result.data.Double == 3.14);
}
