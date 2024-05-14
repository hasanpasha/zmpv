const std = @import("std");
const c = @import("./c.zig");
const MpvFormat = @import("./mpv_format.zig").MpvFormat;

pub const MpvNodehashMap = std.StringHashMap(MpvNode);

pub const MpvNode = union(enum) {
    None: void,
    String: []const u8,
    Flag: bool,
    INT64: i64,
    Double: f64,
    NodeArray: []MpvNode,
    NodeMap: MpvNodehashMap,
    ByteArray: []const u8,

    const Self = @This();

    pub fn from(node_value: c.mpv_node, allocator: std.mem.Allocator) std.mem.Allocator.Error!Self {
        const node_format: MpvFormat = @enumFromInt(node_value.format);
        return switch (node_format) {
            .None => Self{ .None = {} },
            .Flag => Self{ .Flag = (node_value.u.int64 == 1) },
            .String => Self{ .String = std.mem.span(node_value.u.string) },
            .INT64 => Self{ .INT64 = node_value.u.int64 },
            .Double => Self{ .Double = node_value.u.double_ },
            .NodeArray => Self{ .NodeArray = try from_node_list(node_value.u.list.*, allocator) },
            .NodeMap => Self{ .NodeMap = try from_node_map(node_value.u.list.*, allocator) },
            .ByteArray => Self{ .ByteArray = try from_byte_array(node_value.u.ba.*, allocator) },
            else => Self{ .None = {} },
        };
    }

    pub fn from_node_list(list: c.struct_mpv_node_list, allocator: std.mem.Allocator) std.mem.Allocator.Error![]MpvNode {
        const array_len: usize = @intCast(list.num);
        const node_list = try allocator.alloc(MpvNode, array_len);
        for (0..array_len) |index| {
            node_list[index] = try MpvNode.from(list.values[index], allocator);
        }
        return node_list;
    }

    pub fn from_node_map(map: c.struct_mpv_node_list, allocator: std.mem.Allocator) std.mem.Allocator.Error!MpvNodehashMap {
        const hash_map_len: usize = @intCast(map.num);
        var hash_map = MpvNodehashMap.init(allocator);
        for (0..hash_map_len) |index| {
            const key = std.mem.span(map.keys[index]);
            const value = try MpvNode.from(map.values[index], allocator);
            try hash_map.put(key, value);
        }
        return hash_map;
    }

    pub fn from_byte_array(bytes: c.struct_mpv_byte_array, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
        const casted_bytes_data: [*c]const u8 = @ptrCast(bytes.data);
        const zig_bytes = try allocator.alloc(u8, bytes.size + 1);
        for (0..bytes.size) |index| {
            zig_bytes[index] = casted_bytes_data[index];
        }
        zig_bytes[bytes.size] = 0;
        return zig_bytes;
    }

    pub fn to_c(self: MpvNode, allocator: std.mem.Allocator) !*anyopaque {
        const node_ptr = try allocator.create(c.mpv_node);
        switch (self) {
            .None => {
                node_ptr.format = @intFromEnum(MpvFormat.None);
            },
            .Flag => |flag| {
                node_ptr.format = @intFromEnum(MpvFormat.Flag);
                node_ptr.u.flag = if (flag) 1 else 0;
            },
            else => @panic("I don't know"),
        }
        return @ptrCast(node_ptr);
    }
};
