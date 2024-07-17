const c = @import("../c.zig");
const std = @import("std");
const testing = std.testing;
const utils = @import("../utils.zig");

const Self = @This();

name: []const u8,
id: u64,

pub fn from(data_ptr: *anyopaque) Self {
    const data = utils.casted_anyopaque_ptr_value(c.mpv_event_hook, data_ptr);

    return Self{
        .name = std.mem.sliceTo(data.name, 0),
        .id = data.id,
    };
}

pub fn copy(self: Self, allocator: std.mem.Allocator) !Self {
    return Self{
        .id = self.id,
        .name = try allocator.dupe(u8, self.name),
    };
}

pub fn free(self: Self, allocator: std.mem.Allocator) void {
    allocator.free(self.name);
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

test "MpvEventHook copy" {
    const allocator = testing.allocator;

    const hook = Self{
        .id = 69,
        .name = "on_update"
    };
    const hook_copy = try hook.copy(allocator);
    defer hook_copy.free(allocator);

    try testing.expect(hook_copy.id == 69);
    try testing.expectEqualStrings("on_update", hook_copy.name);
}
