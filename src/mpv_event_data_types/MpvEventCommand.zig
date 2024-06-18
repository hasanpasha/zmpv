const MpvNode = @import("../mpv_node.zig").MpvNode;
const std = @import("std");
const testing = std.testing;
const c = @import("../c.zig");
const utils = @import("../utils.zig");

const Self = @This();

result: MpvNode,

pub fn from(data_ptr: *anyopaque) Self {
    const data = utils.cast_event_data(data_ptr, c.mpv_event_command);

    return Self{
        .result = MpvNode.from(@constCast(&data.result)),
    };
}

test "MpvEventCommand from" {
    const command_result = c.mpv_node{
        .format = c.MPV_FORMAT_DOUBLE,
        .u = .{ .double_ = 3.14 },
    };
    var command_event = c.mpv_event_command{
        .result = command_result,
    };
    const z_command = Self.from(&command_event);

    try testing.expect(z_command.result.Double == 3.14);
}
