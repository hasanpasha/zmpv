const c = @import("../c.zig");
const std = @import("std");
const testing = std.testing;
const utils = @import("../utils.zig");

const Self = @This();

args: [][*:0]const u8,

pub fn from(data_ptr: *anyopaque) Self {
    const data = utils.cast_event_data(data_ptr, c.mpv_event_client_message);
    const cstring: [*][*:0]const u8 = @ptrCast(data.args);

    return Self{
        .args = cstring[0..@intCast(data.num_args)],
    };
}

test "MpvEventClientMessage from" {
    var message_args = [_][*c]const u8{ "hello", "world" };
    var message = c.mpv_event_client_message{
        .args = &message_args,
        .num_args = 2,
    };
    const z_message = from(&message);

    try testing.expect(z_message.args.len == 2);
    try testing.expect(std.mem.eql(u8, std.mem.sliceTo(z_message.args[0], 0), "hello"));
    try testing.expect(std.mem.eql(u8, std.mem.sliceTo(z_message.args[1], 0), "world"));
}
