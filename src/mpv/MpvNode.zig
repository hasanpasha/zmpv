const std = @import("std");
const testing = std.testing;
const c = @import("./c.zig");
const MpvFormat = @import("./mpv_format.zig").MpvFormat;
const MpvNodeHashMap = @import("./types.zig").MpvNodeHashMap;

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
            .String => MpvNodeData{ .String = std.mem.sliceTo(node_ptr.u.string, 0) },
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
        const key = std.mem.sliceTo(map.keys[index], 0);
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

pub fn to_c(self: Self, allocator: std.mem.Allocator) !*c.mpv_node {
    const node_ptr = try allocator.create(c.mpv_node);
    switch (self.data) {
        .None => {
            node_ptr.format = MpvFormat.None.to();
        },
        .String => |string| {
            node_ptr.format = MpvFormat.String.to();
            node_ptr.u.string = @constCast(string.ptr);
        },
        .Flag => |flag| {
            node_ptr.format = MpvFormat.Flag.to();
            node_ptr.u.flag = if (flag) 1 else 0;
        },
        .INT64 => |num| {
            node_ptr.format = MpvFormat.INT64.to();
            node_ptr.u.int64 = num;
        },
        .Double => |num| {
            node_ptr.format = MpvFormat.Double.to();
            node_ptr.u.double_ = num;
        },
        .NodeArray => |array| {
            node_ptr.format = MpvFormat.NodeArray.to();
            var node_list_ptr = try allocator.create(c.mpv_node_list);
            node_list_ptr.num = @intCast(array.len);
            var node_values = try allocator.alloc(c.mpv_node, array.len);
            for (0..array.len) |index| {
                const node: *c.mpv_node = @ptrCast(@alignCast(try array[index].to_c(allocator)));
                node_values[index] = node.*;
            }
            node_list_ptr.values = node_values.ptr;
            node_ptr.u.list = @ptrCast(node_list_ptr);
        },
        .NodeMap => |map| {
            node_ptr.format = MpvFormat.NodeMap.to();
            var node_list_ptr = try allocator.create(c.mpv_node_list);
            const map_len: usize = @intCast(map.count());

            node_list_ptr.num = @intCast(map_len);

            var node_values = try allocator.alloc(c.mpv_node, map_len);
            var value_iterator = map.valueIterator();
            var index: usize = 0;
            while (value_iterator.next()) |value| {
                const node: *c.mpv_node = @ptrCast(@alignCast(try value.to_c(allocator)));
                node_values[index] = node.*;
                index += 1;
            }
            node_list_ptr.values = node_values.ptr;

            var node_keys = try allocator.alloc([*c]u8, map_len + 1);
            node_keys[map_len - 1] = null;
            var keys_iterator = map.keyIterator();
            index = 0;
            while (keys_iterator.next()) |key| {
                node_keys[index] = @ptrCast(@constCast(key.*.ptr));
                index += 1;
            }
            node_list_ptr.keys = @ptrCast(node_keys);

            node_ptr.u.list = @ptrCast(node_list_ptr);
        },
        else => @panic("I don't know"),
    }
    return node_ptr;
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

test "MpvNodeData" {
    const none = MpvNodeData{ .None = {} };
    try testing.expect(none.None == {});

    const int = MpvNodeData{ .INT64 = 69 };
    switch (int) {
        .INT64 => |num| try testing.expect(num == 69),
        else => unreachable,
    }

    const flag = MpvNodeData{ .Flag = false };
    try testing.expect(@TypeOf(flag.Flag) == bool);
}

test "MpvNode to c" {
    return error.SkipZigTest;
    // const allocator = testing.allocator;
    // const node = Self{ .data = .{ .Double = 3.14 } };
    // const c_node = try node.to_c(allocator);
    // defer allocator.free(c_node);
}

test "MpvNode from c" {
    const allocator = testing.allocator;
    var num = c.mpv_node{
        .format = c.MPV_FORMAT_INT64,
        .u = .{ .int64 = 6996 },
    };
    const z_node = try Self.from(&num, allocator);
    z_node.free();
    try testing.expect(z_node.allocator != null);
    try testing.expect(z_node.c_node_ptr != null);
    try testing.expect(z_node.c_node_ptr.? == &num);
    try testing.expect(z_node.data.INT64 == 6996);
}
