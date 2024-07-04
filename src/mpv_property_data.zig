const std = @import("std");
const testing = std.testing;
const c = @import("./c.zig");
const MpvFormat = @import("./mpv_format.zig").MpvFormat;
const MpvNode = @import("./mpv_node.zig").MpvNode;
const types = @import("./types.zig");
const MpvNodeList = types.MpvNodeList;
const MpvNodeMap = types.MpvNodeMap;

pub const MpvPropertyData = union(MpvFormat) {
    None: void,
    String: []const u8,
    OSDString: []const u8,
    Flag: bool,
    INT64: i64,
    Double: f64,
    Node: MpvNode,
    NodeArray: MpvNodeList,
    NodeMap: MpvNodeMap,
    ByteArray: []const u8,

    pub fn from(format: MpvFormat, data: ?*anyopaque) MpvPropertyData {
        return switch (format) {
            .None => MpvPropertyData{ .None = {} },
            .String => value: {
                const string_ptr: *[*c]const u8 = @ptrCast(@alignCast(data));
                const string = string_ptr.*;
                const zig_string = std.mem.sliceTo(string, 0);
                break :value MpvPropertyData{
                    .String = zig_string,
                };
            },
            .OSDString => value: {
                const string_ptr: *[*c]const u8 = @ptrCast(@alignCast(data));
                const string = string_ptr.*;
                const zig_string = std.mem.sliceTo(string, 0);
                break :value MpvPropertyData{
                    .OSDString = zig_string,
                };
            },
            .Flag => value: {
                const ret_value_ptr: *c_int = @ptrCast(@alignCast(data));
                const ret_value = ret_value_ptr.*;
                break :value MpvPropertyData{ .Flag = (ret_value == 1) };
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
                break :value MpvPropertyData{ .Node = MpvNode.from(node_ptr) };
            },
            .NodeArray => value: {
                const list_ptr: *c.struct_mpv_node_list = @ptrCast(@alignCast(data));
                break :value MpvPropertyData{ .NodeArray = MpvNodeList.from(list_ptr) };
            },
            .NodeMap => value: {
                const map_ptr: *c.struct_mpv_node_list = @ptrCast(@alignCast(data));
                break :value MpvPropertyData{ .NodeMap = MpvNodeMap.from(map_ptr) };
            },
            .ByteArray => value: {
                const byte_ptr: *c.struct_mpv_byte_array = @ptrCast(@alignCast(data));
                if (byte_ptr.size == 0) {
                    break :value MpvPropertyData{ .ByteArray = &.{} };
                }
                const casted_bytes_data: [*:0]const u8 = @ptrCast(byte_ptr.data);
                break :value MpvPropertyData{ .ByteArray = casted_bytes_data[0..byte_ptr.size] };
            },
        };
    }

    // TODO a better way to free the allocated memory (maybe return a union type!)
    pub fn to_c(self: MpvPropertyData, allocator: std.mem.Allocator) !*anyopaque {
        return switch (self) {
            .String, .OSDString => |str| ptr: {
                const cstr_ptr = try allocator.create([*c]u8);
                cstr_ptr.* = try allocator.dupeZ(u8, str);
                break :ptr @ptrCast(cstr_ptr);
            },
            .Flag => |flag| ptr: {
                const value: c_int = if (flag) 1 else 0;
                const cflag_ptr = try allocator.create(c_int);
                cflag_ptr.* = value;
                break :ptr @ptrCast(cflag_ptr);
            },
            .INT64 => |num| ptr: {
                const cint_ptr = try allocator.create(i64);
                cint_ptr.* = num;
                break :ptr @ptrCast(cint_ptr);
            },
            .Double => |num| ptr: {
                const cdouble_ptr = try allocator.create(f64);
                cdouble_ptr.* = num;
                break :ptr @ptrCast(cdouble_ptr);
            },
            .Node => |node| ptr: {
                const cnode_ptr = try MpvNode.to_c(node, allocator);
                break :ptr @ptrCast(cnode_ptr);
            },
            else => @panic("MpvFormat not supported."),
        };
    }

    pub fn copy(self: MpvPropertyData, allocator: std.mem.Allocator) !MpvPropertyData {
        switch (self) {
            .String => |string| {
                return MpvPropertyData{ .String = try allocator.dupe(u8, string) };
            },
            .OSDString => |string| {
                return MpvPropertyData{ .OSDString = try allocator.dupe(u8, string) };
            },
            .Node => |node| {
                return MpvPropertyData{ .Node = try node.copy(allocator) };
            },
            .NodeArray => |*array| {
                var mut_array = @constCast(array);
                return MpvPropertyData{ .NodeArray = try mut_array.copy(allocator) };
            },
            .NodeMap => |*map| {
                var mut_map = @constCast(map);
                return MpvPropertyData{ .NodeMap = try mut_map.copy(allocator) };
            },
            .ByteArray => |bytes| {
                return MpvPropertyData{ .ByteArray = try allocator.dupe(u8, bytes) };
            },
            else => return self,
        }
    }
    pub fn free(self: MpvPropertyData, allocator: std.mem.Allocator) void {
        // _ = allocator;
        std.log.debug("freeing data", .{});
        switch (self) {
            .String => |string| {
                allocator.free(string);
            },
            .OSDString => |string| {
                allocator.free(string);
            },
            .Node => |node| {
                node.free(allocator);
            },
            .NodeArray => |*array| {
                var mut_array = @constCast(array);
                mut_array.free(allocator);
            },
            .NodeMap => |*map| {
                var mut_map = @constCast(map);
                mut_map.free(allocator);
            },
            .ByteArray => |bytes| {
                allocator.free(bytes);
            },
            else => {},
        }
    }
};

test "MpvNodeData from" {
    var num = c.mpv_node{
        .format = c.MPV_FORMAT_INT64,
        .u = .{ .int64 = 45 },
    };
    const z_num = MpvPropertyData.from(.INT64, &num);

    try testing.expect(z_num.INT64 == 45);
}

test "MpvNodeData to" {
    const allocator = testing.allocator;
    const z_num = MpvPropertyData{ .INT64 = 45 };
    const c_num_anon_ptr = try z_num.to_c(allocator);
    const c_num_ptr: *i64 = @ptrCast(@alignCast(c_num_anon_ptr));
    defer allocator.destroy(c_num_ptr);

    try testing.expect(z_num.INT64 == c_num_ptr.*);
}
