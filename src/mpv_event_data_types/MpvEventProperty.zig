const std = @import("std");
const testing = std.testing;
const MpvError = @import("../mpv_error.zig").MpvError;
const MpvFormat = @import("../mpv_format.zig").MpvFormat;
const MpvPropertyData = @import("../mpv_property_data.zig").MpvPropertyData;
const utils = @import("../utils.zig");
const c = @import("../c.zig");

const Self = @This();

name: []const u8,
format: MpvFormat,
data: MpvPropertyData,

pub fn from(data_ptr: *anyopaque) Self {
    const data = utils.cast_event_data(data_ptr, c.mpv_event_property);

    const format = MpvFormat.from(data.format);
    return Self{
        .name = std.mem.sliceTo(data.name, 0),
        .format = format,
        .data = MpvPropertyData.from(format, data.data),
    };
}

test "MpvEventProperty from" {
    var property_data: c_int = 0;
    var property_event = c.mpv_event_property{
        .format = c.MPV_FORMAT_FLAG,
        .data = &property_data,
        .name = "fullscreen",
    };
    const z_property = Self.from(&property_event);

    try testing.expect(z_property.format == .Flag);
    try testing.expect(z_property.data.Flag == false);
    try testing.expect(std.mem.eql(u8, z_property.name, "fullscreen"));
}
