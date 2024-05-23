const std = @import("std");
const testing = std.testing;
const MpvError = @import("../errors/mpv_error.zig").MpvError;
const MpvFormat = @import("../mpv_format.zig").MpvFormat;
const MpvPropertyData = @import("../mpv_property_data.zig").MpvPropertyData;
const mpv_event_utils = @import("./mpv_event_utils.zig");
const c = @import("../c.zig");

const Self = @This();

name: []const u8,
format: MpvFormat,
data: MpvPropertyData,

c_data_ptr: *anyopaque,
allocator: std.mem.Allocator,

pub fn from(data_ptr: *anyopaque, allocator: std.mem.Allocator) !Self {
    const data = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_property);

    const format: MpvFormat = @enumFromInt(data.format);
    return Self{
        .name = std.mem.sliceTo(data.name, 0),
        .format = format,
        .data = try MpvPropertyData.from(format, data.data, allocator),
        .c_data_ptr = data_ptr,
        .allocator = allocator,
    };
}

pub fn free(self: Self) void {
    self.data.free(self.allocator);
}

test "MpvEventProperty from" {
    const allocator = testing.allocator;
    var property_data: c_int = 0;
    var property_event = c.mpv_event_property{
        .format = c.MPV_FORMAT_FLAG,
        .data = &property_data,
        .name = "fullscreen",
    };
    const z_property = try Self.from(&property_event, allocator);
    defer z_property.free();

    try testing.expect(z_property.format == .Flag);
    try testing.expect(z_property.data.Flag == false);
    try testing.expect(std.mem.eql(u8, z_property.name, "fullscreen"));
}
