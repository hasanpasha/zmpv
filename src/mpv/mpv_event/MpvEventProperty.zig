const std = @import("std");
const mpv_error = @import("../errors/mpv_error.zig");
const MpvError = mpv_error.MpvError;
const MpvFormat = @import("../mpv_format.zig").MpvFormat;
const MpvNode = @import("../mpv_node.zig").MpvNode;
const MpvNodehashMap = @import("../mpv_node.zig").MpvNodehashMap;
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
        .data = try MpvPropertyData.extract_value(format, data.data, allocator),
    };
}

pub const MpvPropertyData = union(MpvFormat) {
    None: void,
    String: []const u8,
    OSDString: []const u8,
    Flag: bool,
    INT64: i64,
    Double: f64,
    Node: MpvNode,
    NodeArray: []const MpvNode,
    NodeMap: MpvNodehashMap,
    ByteArray: []const u8,

    fn extract_value(format: MpvFormat, data: ?*anyopaque, allocator: std.mem.Allocator) !MpvPropertyData {
        return switch (format) {
            .None => MpvPropertyData{ .None = {} },
            .String => value: {
                const string: [*c]const u8 = @ptrCast(data);
                const zig_string = std.mem.span(string);
                break :value MpvPropertyData{
                    .String = zig_string,
                };
            },
            .OSDString => MpvPropertyData{ .None = {} },
            .Flag => value: {
                const ret_value_ptr: *c_int = @ptrCast(@alignCast(data));
                const ret_value = ret_value_ptr.*;
                break :value MpvPropertyData{ .Flag = if (ret_value == 1) true else false };
            },
            .INT64 => value: {
                const ret_value_ptr: *i64 = @ptrCast(@alignCast(data));
                const ret_value = ret_value_ptr.*;
                break :value MpvPropertyData{ .INT64 = ret_value };
            },
            .Double => value: {
                const ret_value_ptr: *f64 = @ptrCast(@alignCast(data));
                const ret_value = ret_value_ptr.*;
                break :value MpvPropertyData{ .Double = ret_value };
            },
            .Node => value: {
                const node_ptr: *c.mpv_node = @ptrCast(@alignCast(data));
                break :value MpvPropertyData{ .Node = try MpvNode.from(node_ptr.*, allocator) };
            },
            .NodeArray => value: {
                const list_ptr: *c.struct_mpv_node_list = @ptrCast(@alignCast(data));
                break :value MpvPropertyData{ .NodeArray = try MpvNode.from_node_list(list_ptr.*, allocator) };
            },
            .NodeMap => value: {
                const map_ptr: *c.struct_mpv_node_list = @ptrCast(@alignCast(data));
                break :value MpvPropertyData{ .NodeMap = try MpvNode.from_node_map(map_ptr.*, allocator) };
            },
            .ByteArray => value: {
                const byte_ptr: *c.struct_mpv_byte_array = @ptrCast(@alignCast(data));
                break :value MpvPropertyData{ .ByteArray = try MpvNode.from_byte_array(byte_ptr.*, allocator) };
            },
        };
    }
};
