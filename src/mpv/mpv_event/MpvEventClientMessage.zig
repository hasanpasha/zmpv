const c = @import("../c.zig");
const mpv_event_utils = @import("./mpv_event_utils.zig");
const std = @import("std");
const testing = std.testing;
const utils = @import("../utils.zig");

const Self = @This();

args: [][]const u8,
allocator: std.mem.Allocator,

pub fn from(data_ptr: *anyopaque, allocator: std.mem.Allocator) !Self {
    const data = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_client_message);

    const args = try utils.create_zstring_array(data.args, @intCast(data.num_args), allocator);

    return Self{
        .args = args,
        .allocator = allocator,
    };
}

pub fn free(self: Self) void {
    utils.free_zstring_array(self.args, self.allocator);
}

test "MpvEventClientMessage from" {
    const allocator = testing.allocator;
    var message_args = [_][*c]const u8{ "hello", "world" };
    var message = c.mpv_event_client_message{
        .args = &message_args,
        .num_args = 2,
    };
    const z_message = try from(&message, allocator);
    defer z_message.free();

    try testing.expect(z_message.args.len == 2);
    try testing.expect(std.mem.eql(u8, z_message.args[0], "hello"));
    try testing.expect(std.mem.eql(u8, z_message.args[1], "world"));
}
