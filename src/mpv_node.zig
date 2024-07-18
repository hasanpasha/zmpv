const std = @import("std");
const c = @import("c.zig");
const MpvFormat = @import("mpv_format.zig").MpvFormat;
const types = @import("types.zig");
const MpvNodeList = types.MpvNodeList;
const MpvNodeMap = types.MpvNodeMap;
const testing = std.testing;

pub const MpvNode = union(enum) {
    None: void,
    String: []const u8,
    Flag: bool,
    INT64: i64,
    Double: f64,
    NodeArray: MpvNodeList,
    NodeMap: MpvNodeMap,
    ByteArray: []const u8,

    pub fn from(node_ptr: *c.mpv_node) MpvNode {
        const node_format: MpvFormat = @enumFromInt(node_ptr.format);
        return switch (node_format) {
            .None => MpvNode{ .None = {} },
            .Flag => MpvNode{ .Flag = (node_ptr.u.int64 == 1) },
            .String => MpvNode{ .String = std.mem.sliceTo(node_ptr.u.string, 0) },
            .INT64 => MpvNode{ .INT64 = node_ptr.u.int64 },
            .Double => MpvNode{ .Double = node_ptr.u.double_ },
            .NodeArray => MpvNode{ .NodeArray = MpvNodeList.from(node_ptr.u.list) },
            .NodeMap => MpvNode{ .NodeMap = MpvNodeMap.from(node_ptr.u.list) },
            .ByteArray => MpvNode{ .ByteArray = value: {
                if (node_ptr.u.ba.*.data == null) {
                    break :value &.{};
                }
                const casted_bytes_data: [*:0]const u8 = @ptrCast(node_ptr.u.ba.*.data);
                break :value casted_bytes_data[0..node_ptr.u.ba.*.size];
            } },
            else => MpvNode{ .None = {} },
        };
    }

    pub fn to_c(self: MpvNode, allocator: std.mem.Allocator) !*c.mpv_node {
        const node_ptr = try allocator.create(c.mpv_node);
        switch (self) {
            .None => {
                node_ptr.format = MpvFormat.None.to_c();
            },
            .String => |string| {
                node_ptr.format = MpvFormat.String.to_c();
                node_ptr.u.string = @constCast(string.ptr);
            },
            .Flag => |flag| {
                node_ptr.format = MpvFormat.Flag.to_c();
                node_ptr.u.flag = if (flag) 1 else 0;
            },
            .INT64 => |num| {
                node_ptr.format = MpvFormat.INT64.to_c();
                node_ptr.u.int64 = num;
            },
            .Double => |num| {
                node_ptr.format = MpvFormat.Double.to_c();
                node_ptr.u.double_ = num;
            },
            .NodeArray => |*array| {
                var mut_array: *MpvNodeList = @constCast(array);
                node_ptr.format = MpvFormat.NodeArray.to_c();
                node_ptr.u.list = @ptrCast(try mut_array.to_c(allocator));
            },
            .NodeMap => |*map| {
                var mut_map: *MpvNodeMap = @constCast(map);
                node_ptr.format = MpvFormat.NodeMap.to_c();
                node_ptr.u.list = @ptrCast(try mut_map.to_c(allocator));
            },
            else => @panic("I don't know"),
        }
        return node_ptr;
    }

    pub fn copy(self: MpvNode, allocator: std.mem.Allocator) !MpvNode {
        switch (self) {
            .String => |string| {
                return MpvNode{ .String = try allocator.dupe(u8, string) };
            },
            .NodeArray => |*array| {
                var mut_array = @constCast(array);
                return MpvNode{ .NodeArray = try mut_array.copy(allocator) };
            },
            .NodeMap => |*map| {
                var mut_map = @constCast(map);
                return MpvNode{ .NodeMap = try mut_map.copy(allocator) };
            },
            .ByteArray => |bytes| {
                return MpvNode{ .ByteArray = try allocator.dupe(u8, bytes) };
            },
            else => return self,
        }
    }

    pub fn free(self: MpvNode, allocator: std.mem.Allocator) void {
        switch (self) {
            .String => |string| {
                allocator.free(string);
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

test "MpvNode to c" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const node = MpvNode{ .Double = 3.14 };
    const c_node = try node.to_c(arena.allocator());
    try testing.expect(c_node.format == MpvFormat.Double.to_c());
    try testing.expect(c_node.u.double_ == 3.14);
}

test "MpvNode from c" {
    var num = c.mpv_node{
        .format = c.MPV_FORMAT_INT64,
        .u = .{ .int64 = 6996 },
    };
    const z_node = MpvNode.from(&num);
    try testing.expect(z_node.INT64 == 6996);
}
