const std = @import("std");
const c = @import("../c.zig");
const MpvNode = @import("../mpv_node.zig").MpvNode;
const utils = @import("../utils.zig");
const AllocatorError = std.mem.Allocator.Error;
const testing = std.testing;

const Self = @This();

result: MpvNode,

pub fn from(data_ptr: *anyopaque) Self {
    const data = utils.cast_anyopaque_ptr(c.mpv_event_command, data_ptr).*;

    return Self{
        .result = MpvNode.from(@constCast(&data.result)),
    };
}

pub fn copy(self: Self, allocator: std.mem.Allocator) AllocatorError!Self {
    return .{
        .result = try self.result.copy(allocator),
    };
}

pub fn free(self: Self, allocator: std.mem.Allocator) void {
    self.result.free(allocator);
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

test "MpvEventCommand copy" {
    const allocator = testing.allocator;

    const command_reply = Self {
        .result = .{ .String = "done" },
    };
    const command_reply_copy = try command_reply.copy(allocator);
    defer command_reply_copy.free(allocator);

    try testing.expectEqualStrings("done", command_reply_copy.result.String);
}

