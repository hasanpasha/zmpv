const std = @import("std");
const c = @import("c.zig");
const MpvNode = @import("mpv_node.zig").MpvNode;
const MpvFormat = @import("mpv_format.zig").MpvFormat;
const testing = std.testing;

pub const MpvNodeList = struct {
    value: T,

    const Self = @This();
    const T = union(enum) { CValue: *c.mpv_node_list, ZigValue: []const Element };
    pub const Element = MpvNode;

    pub fn new(list: []const Element) Self {
        return .{
            .value = .{ .ZigValue = list },
        };
    }

    pub const Iterator = struct {
        value: T,
        index: usize = 0,

        pub fn next(it: *Iterator) ?Element {
            const len: usize = it.size();
            if (it.index >= len) {
                it.index = 0;
                return null;
            }

            var node: Element = undefined;
            switch (it.value) {
                .CValue => |value| {
                    node = MpvNode.from(@ptrCast(&value.values[it.index]));
                },
                .ZigValue => |value| {
                    node = value[it.index];
                },
            }
            it.index += 1;

            return node;
        }

        pub fn size(self: *Iterator) usize {
            switch (self.value) {
                .CValue => |value| {
                    return @intCast(value.num);
                },
                .ZigValue => |value| {
                    return value.len;
                },
            }
        }
    };

    pub fn iterator(self: Self) Iterator {
        return .{
            .value = self.value,
        };
    }

    pub fn from(data: *c.mpv_node_list) Self {
        return .{ .value = .{ .CValue = data } };
    }

    pub fn to_c(self: *Self, allocator: std.mem.Allocator) anyerror!*c.mpv_node_list {
        var iter = self.iterator();
        const len = iter.size();

        var node_list_ptr = try allocator.create(c.mpv_node_list);
        var node_values = try allocator.alloc(c.mpv_node, len);

        var idx: usize = 0;
        while (iter.next()) |node| : (idx += 1) {
            node_values[idx] = (try node.to_c(allocator)).*;
        }

        node_list_ptr.num = @intCast(len);
        node_list_ptr.values = node_values.ptr;
        return node_list_ptr;
    }

    pub fn copy(self: *Self, allocator: std.mem.Allocator) anyerror!Self {
        var iter = self.iterator();
        const len = iter.size();

        var list = try allocator.alloc(Element, len);

        var idx: usize = 0;
        while (iter.next()) |node| : (idx += 1) {
            list[idx] = try node.copy(allocator);
        }
        return Self.new(list);
    }

    pub fn free(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.value) {
            .ZigValue => |value| {
                for (value) |node| {
                    node.free(allocator);
                }
                allocator.free(value);
            },
            else => {},
        }
    }

    pub fn to_arraylist(self: Self, allocator: std.mem.Allocator) !std.ArrayList(MpvNode) {
        var array = std.ArrayList(MpvNode).init(allocator);

        var iter = self.iterator();
        while (iter.next()) |node| {
            try array.append(node);
        }

        return array;
    }

    /// Must be freed with `MpvNodeList.free_owned_arraylist` before calling `.deinit()` on it.
    pub fn to_owned_arraylist(self: Self, allocator: std.mem.Allocator) !std.ArrayList(MpvNode) {
        var array = std.ArrayList(MpvNode).init(allocator);

        var iter = self.iterator();
        while (iter.next()) |node| {
            try array.append(try node.copy(allocator));
        }

        return array;
    }

    /// free the allocated `MpvNode`s
    pub fn free_owned_arraylist(array: std.ArrayList(MpvNode), allocator: std.mem.Allocator) void {
        for (array.items) |node| {
            node.free(allocator);
        }
    }
};

pub const MpvNodeMap = struct {
    value: T,

    const Self = @This();
    const T = union(enum) { CValue: *c.mpv_node_list, ZigValue: []const Element };
    pub const Element = struct { []const u8, MpvNode };

    pub fn new(list: []const Element) Self {
        return .{
            .value = .{ .ZigValue = list },
        };
    }

    pub const Iterator = struct {
        value: T,
        index: usize = 0,

        pub fn next(it: *Iterator) ?Element {
            const len: usize = it.size();
            if (it.index >= len) {
                it.index = 0;
                return null;
            }

            var pair: Element = undefined;
            switch (it.value) {
                .CValue => |value| {
                    pair = .{
                        std.mem.sliceTo(value.keys[it.index], 0),
                        MpvNode.from(@ptrCast(&value.values[it.index])),
                    };
                },
                .ZigValue => |value| {
                    pair = value[it.index];
                },
            }
            it.index += 1;

            return pair;
        }

        pub fn size(self: *Iterator) usize {
            switch (self.value) {
                .CValue => |value| {
                    return @intCast(value.num);
                },
                .ZigValue => |value| {
                    return value.len;
                },
            }
        }
    };

    pub fn iterator(self: Self) Iterator {
        return .{
            .value = self.value,
        };
    }

    pub fn from(data: *c.mpv_node_list) Self {
        return .{ .value = .{ .CValue = data } };
    }

    pub fn to_c(self: *Self, allocator: std.mem.Allocator) anyerror!*c.mpv_node_list {
        var iter = self.iterator();
        const len = iter.size();

        var node_list_ptr = try allocator.create(c.mpv_node_list);
        var node_values = try allocator.alloc(c.mpv_node, len);
        var node_keys = try allocator.allocSentinel([*c]u8, len, null);

        var idx: usize = 0;
        while (iter.next()) |pair| : (idx += 1) {
            node_keys[idx] = @constCast(pair[0].ptr);
            node_values[idx] = (try pair[1].to_c(allocator)).*;
        }

        node_list_ptr.num = @intCast(len);
        node_list_ptr.keys = @ptrCast(node_keys);
        node_list_ptr.values = node_values.ptr;
        return node_list_ptr;
    }

    pub fn copy(self: *Self, allocator: std.mem.Allocator) anyerror!Self {
        var iter = self.iterator();
        const len = iter.size();

        var list = try allocator.alloc(Element, len);

        var idx: usize = 0;
        while (iter.next()) |pair| : (idx += 1) {
            list[idx] = .{ try allocator.dupe(u8, pair[0]), try pair[1].copy(allocator) };
        }
        return Self.new(list);
    }

    pub fn free(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.value) {
            .ZigValue => |value| {
                for (value) |pair| {
                    allocator.free(pair[0]);
                    pair[1].free(allocator);
                }
                allocator.free(value);
            },
            else => {},
        }
    }

    pub fn to_hashmap(self: Self, allocator: std.mem.Allocator) !std.StringHashMap(MpvNode) {
        var map = std.StringHashMap(MpvNode).init(allocator);

        var iter = self.iterator();
        while (iter.next()) |pair| {
            try map.put(pair[0], pair[1]);
        }
        return map;
    }

    /// Must be freed with with `MpvNodeMap.free_owned_hashmap` before calling `.deinit()` on it.
    pub fn to_owned_hashmap(self: Self, allocator: std.mem.Allocator) !std.StringHashMap(MpvNode) {
        var map = std.StringHashMap(MpvNode).init(allocator);

        var iter = self.iterator();
        while (iter.next()) |pair| {
            try map.put(try allocator.dupe(u8, pair[0]), try pair[1].copy(allocator));
        }
        return map;
    }

    /// Free the allocated key strings and Value `MapNode`
    pub fn free_owned_hashmap(map: std.StringHashMap(MpvNode), allocator: std.mem.Allocator) void {
        var iter = map.iterator();
        while (iter.next()) |pair| {
            allocator.free(pair.key_ptr.*);
            pair.value_ptr.free(allocator);
        }
    }
};
