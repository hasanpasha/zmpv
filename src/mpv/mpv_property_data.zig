const std = @import("std");
const testing = std.testing;
const c = @import("./c.zig");
const MpvFormat = @import("./mpv_format.zig").MpvFormat;
const MpvNode = @import("./MpvNode.zig");
const MpvNodeHashMap = @import("./types.zig").MpvNodeHashMap;

pub const MpvPropertyData = union(MpvFormat) {
    None: void,
    String: []const u8,
    OSDString: []const u8,
    Flag: bool,
    INT64: i64,
    Double: f64,
    Node: MpvNode,
    NodeArray: []MpvNode,
    NodeMap: MpvNodeHashMap,
    ByteArray: []const u8,

    pub fn from(format: MpvFormat, data: ?*anyopaque, allocator: std.mem.Allocator) !MpvPropertyData {
        return switch (format) {
            .None => MpvPropertyData{ .None = {} },
            // TODO mv .OSDString to its own branch to fix Mpv.set_option error on .OSDString format.
            .String, .OSDString => value: {
                const string: [*c]const u8 = @ptrCast(data);
                const zig_string = std.mem.sliceTo(string, 0);
                break :value MpvPropertyData{
                    .String = zig_string,
                };
            },
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
                break :value MpvPropertyData{ .Node = try MpvNode.from(node_ptr, allocator) };
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

    pub fn free(self: MpvPropertyData, allocator: std.mem.Allocator) void {
        switch (self) {
            .Node => |node| {
                node.free();
            },
            .NodeArray => |array| {
                for (array) |node| {
                    node.free();
                }
            },
            .NodeMap => |map| {
                var iter = map.keyIterator();
                while (iter.next()) |key| {
                    map.get(key.*).?.free();
                }
                var m: *MpvNodeHashMap = @constCast(&map);
                m.deinit();
            },
            .ByteArray => |bytes| {
                allocator.free(bytes);
            },
            else => {},
        }
    }
};

test "MpvNodeData from" {
    const allocator = testing.allocator;
    var num = c.mpv_node{
        .format = c.MPV_FORMAT_INT64,
        .u = .{ .int64 = 45 },
    };
    const z_num = try MpvPropertyData.from(.INT64, &num, allocator);
    defer MpvPropertyData.free(z_num, allocator);

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
