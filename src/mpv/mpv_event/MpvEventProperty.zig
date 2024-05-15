const std = @import("std");
const mpv_error = @import("../errors/mpv_error.zig");
const MpvError = mpv_error.MpvError;
const MpvFormat = @import("../mpv_format.zig").MpvFormat;
const MpvNode = @import("../mpv_node.zig").MpvNode;
const MpvPropertyData = @import("../mpv_property_data.zig").MpvPropertyData;
const MpvNodehashMap = @import("../types.zig").MpvNodehashMap;
const mpv_event_utils = @import("./mpv_event_utils.zig");
const c = @import("../c.zig");

const Self = @This();

name: []const u8,
format: MpvFormat,
data: MpvPropertyData,

pub fn from(data_ptr: ?*anyopaque, allocator: std.mem.Allocator) !Self {
    const data = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_property);

    const format: MpvFormat = @enumFromInt(data.format);
    return Self{
        .name = std.mem.span(data.name),
        .format = format,
        .data = try MpvPropertyData.from(format, data.data, allocator),
    };
}
