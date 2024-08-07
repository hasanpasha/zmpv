const std = @import("std");
const c = @import("../c.zig");
const utils = @import("../utils.zig");
const AllocatorError = std.mem.Allocator.Error;
const testing = std.testing;

const Self = @This();

args: [][*:0]const u8,

pub fn from(data_ptr: *anyopaque) Self {
    const data = utils.cast_anyopaque_ptr(c.mpv_event_client_message, data_ptr).*;

    var args: [][*:0]const u8 = undefined;
    if (data.num_args == 0) {
        args = &.{};
    } else {
        const cstring: [*][*:0]const u8 = @ptrCast(data.args);
        args = cstring[0..@intCast(data.num_args)];
    }

    return Self{
        .args = args,
    };
}

pub fn copy(self: Self, allocator: std.mem.Allocator) AllocatorError!Self {
    return Self{
        .args = string_array: {
            var strings = try allocator.alloc([*:0]const u8, self.args.len);
            for (0..self.args.len) |idx| {
                strings[idx] = try allocator.dupeZ(u8, std.mem.sliceTo(self.args[idx], 0));
            }
            break :string_array strings;
        }
    };
}

pub fn free(self: Self, allocator: std.mem.Allocator) void {
    for (0..self.args.len) |idx| {
        allocator.free(std.mem.sliceTo(self.args[idx], 0));
    }
    allocator.free(self.args);
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

test "MpvEventClientMessage copy" {
    const allocator = testing.allocator;

    var msgs = [_][*:0]const u8{"hello", "world", "from", "copy"};
    const message = Self{
        .args = &msgs,
    };
    const message_copy = try message.copy(allocator);
    defer message_copy.free(allocator);

    try testing.expectEqualStrings("hello", std.mem.sliceTo(message_copy.args[0], 0));
    try testing.expectEqualStrings("world", std.mem.sliceTo(message_copy.args[1], 0));
    try testing.expectEqualStrings("from", std.mem.sliceTo(message_copy.args[2], 0));
    try testing.expectEqualStrings("copy", std.mem.sliceTo(message_copy.args[3], 0));
}
