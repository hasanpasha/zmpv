const std = @import("std");
const c = @import("./c.zig");
const MpvFormat = @import("./mpv_format.zig").MpvFormat;
const MpvNodeHashMap = @import("./types.zig").MpvNodehashMap;

const Self = @This();

data: MpvNodeData,
c_node_ptr: ?*c.mpv_node,
allocator: ?std.mem.Allocator,

pub fn new(data: MpvNodeData) Self {
    return Self{
        .data = data,
        .c_node_ptr = null,
        .allocator = null,
    };
}

pub fn from(node_ptr: *c.mpv_node, allocator: std.mem.Allocator) std.mem.Allocator.Error!Self {
    const node_format: MpvFormat = @enumFromInt(node_ptr.format);

    return Self{
        .c_node_ptr = node_ptr,
        .allocator = allocator,
        .data = switch (node_format) {
            .None => MpvNodeData{ .None = {} },
            .Flag => MpvNodeData{ .Flag = (node_ptr.u.int64 == 1) },
            .String => MpvNodeData{ .String = std.mem.span(node_ptr.u.string) },
            .INT64 => MpvNodeData{ .INT64 = node_ptr.u.int64 },
            .Double => MpvNodeData{ .Double = node_ptr.u.double_ },
            .NodeArray => MpvNodeData{ .NodeArray = try from_node_list(node_ptr.u.list.*, allocator) },
            .NodeMap => MpvNodeData{ .NodeMap = try from_node_map(node_ptr.u.list.*, allocator) },
            .ByteArray => MpvNodeData{ .ByteArray = try from_byte_array(node_ptr.u.ba.*, allocator) },
            else => MpvNodeData{ .None = {} },
        },
    };
}

pub fn free(self: Self) void {
    if (self.allocator == null) return;
    switch (self.data) {
        .NodeArray => |array| {
            for (0..array.len) |index| {
                array[index].free();
            }
            self.allocator.?.free(array);
        },
        .NodeMap => |map| {
            var iterator = map.keyIterator();
            while (iterator.next()) |key| {
                map.get(key.*).?.free();
            }
            var m: *MpvNodeHashMap = @constCast(&map);
            m.deinit();
        },
        .ByteArray => |bytes| {
            self.allocator.?.free(bytes);
        },
        else => {},
    }
}

pub fn from_node_list(list: c.struct_mpv_node_list, allocator: std.mem.Allocator) std.mem.Allocator.Error![]Self {
    const array_len: usize = @intCast(list.num);
    const node_list = try allocator.alloc(Self, array_len);
    for (0..array_len) |index| {
        node_list[index] = try Self.from(@ptrCast(&list.values[index]), allocator);
    }
    return node_list;
}

pub fn from_node_map(map: c.struct_mpv_node_list, allocator: std.mem.Allocator) std.mem.Allocator.Error!MpvNodeHashMap {
    const hash_map_len: usize = @intCast(map.num);
    var hash_map = MpvNodeHashMap.init(allocator);
    for (0..hash_map_len) |index| {
        const key = std.mem.span(map.keys[index]);
        const value = try Self.from(@ptrCast(&map.values[index]), allocator);
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

pub fn to_c(self: Self, allocator: std.mem.Allocator) !*anyopaque {
    const node_ptr = try allocator.create(c.mpv_node);
    switch (self.data) {
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

pub const MpvNodeData = union(enum) {
    None: void,
    String: []const u8,
    Flag: bool,
    INT64: i64,
    Double: f64,
    NodeArray: []Self,
    NodeMap: MpvNodeHashMap,
    ByteArray: []const u8,
};