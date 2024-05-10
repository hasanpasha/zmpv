const std = @import("std");
const mpv_error = @import("../errors/mpv_error.zig");
const MpvError = mpv_error.MpvError;
const MpvFormat = @import("../mpv_format.zig").MpvFormat;
const mpv_event_utils = @import("./mpv_event_utils.zig");
const c = @import("../c.zig");

const Self = @This();

name: []const u8,
format: MpvFormat,
data: MpvPropertyData,

pub fn from(data_ptr: ?*anyopaque) Self {
    const data = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_property);

    const format: MpvFormat = @enumFromInt(data.format);
    return Self{
        .name = std.mem.span(data.name),
        .format = format,
        .data = switch (format) {
            .None => MpvPropertyData{ .None = {} },
            .String => value: {
                const string: [*c]const u8 = @ptrCast(data.data);
                const sanitized = std.mem.span(string);
                break :value MpvPropertyData{
                    .String = sanitized,
                };
            },
            .OSDString => MpvPropertyData{ .None = {} },
            .Flag => value: {
                const value: *c_int = @ptrCast(@alignCast(data.data.?));
                break :value MpvPropertyData{ .Flag = if (value.* == 1) true else false };
            },
            .INT64 => MpvPropertyData{ .INT64 = 3 },
            .Double => MpvPropertyData{ .Double = 3.14 },
            .Node => MpvPropertyData{ .None = {} },
            .NodeArray => MpvPropertyData{ .None = {} },
            .NodeMap => MpvPropertyData{ .None = {} },
            .ByteArray => MpvPropertyData{ .None = {} },
        },
    };
}

pub const MpvPropertyData = union(MpvFormat) {
    None: void,
    String: []const u8,
    OSDString: []const u8,
    Flag: bool,
    INT64: i64,
    Double: f64,
    Node: void,
    NodeArray: void,
    NodeMap: void,
    ByteArray: void,
};
