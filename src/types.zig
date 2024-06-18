const std = @import("std");
const c = @import("./c.zig");
const MpvNode = @import("./mpv_node.zig").MpvNode;
const MpvFormat = @import("./mpv_format.zig").MpvFormat;
const testing = std.testing;

pub const MpvNodeListIterator = struct {
    list: ?[]const T = null,
    c_list: ?*c.mpv_node_list = null,
    index: usize = 0,

    const T: type = MpvNode;
    const Self = @This();

    pub fn new(list: []const T) Self {
        return .{
            .list = list,
        };
    }

    pub fn next(self: *Self) ?T {
        if (self.index >= self.size()) return null;

        const idx = self.index;
        var node: ?T = undefined;
        if (self.list) |l| {
            node = l[idx];
        } else if (self.c_list) |l| {
            node = MpvNode.from(@ptrCast(&l.values[idx]));
        } else {
            node = null;
        }
        if (node == null) {
            self.index = 0;
        } else {
            self.index += 1;
        }

        return node;
    }

    pub fn to_c(self: *Self, allocator: std.mem.Allocator) anyerror!*c.mpv_node_list {
        const len = self.size();

        var node_list_ptr = try allocator.create(c.mpv_node_list);
        var node_values = try allocator.alloc(c.mpv_node, len);

        var idx: usize = 0;
        while (self.next()) |node| {
            const cnode: *c.mpv_node = @ptrCast(@alignCast(try node.to_c(allocator)));
            node_values[idx] = cnode.*;
            idx += 1;
        }

        node_list_ptr.num = @intCast(len);
        node_list_ptr.values = node_values.ptr;
        return node_list_ptr;
    }

    pub fn copy(self: *Self, allocator: std.mem.Allocator) anyerror!Self {
        var list = try allocator.alloc(T, self.size());
        var idx: usize = 0;
        while (self.next()) |node| {
            list[idx] = try node.copy(allocator);
            idx += 1;
        }
        return Self.new(list);
    }

    pub fn free(self: *Self, allocator: std.mem.Allocator) void {
        while (self.next()) |node| {
            node.free(allocator);
        }
        allocator.free(self.list.?);
    }

    pub fn size(self: *Self) usize {
        if (self.list) |l| {
            return l.len;
        } else if (self.c_list) |l| {
            return @intCast(l.num);
        } else {
            return 0;
        }
    }
};

pub const MpvNodeMapIterator = struct {
    list: ?[]const T = null,
    c_list: ?*c.mpv_node_list = null,
    index: usize = 0,

    const T: type = struct { []u8, MpvNode };
    const Self = @This();

    pub fn new(list: []const T) Self {
        return .{
            .list = list,
        };
    }

    pub fn next(self: *Self) ?T {
        if (self.index >= self.size()) return null;

        const idx = self.index;
        var pair: ?T = undefined;
        if (self.list) |l| {
            pair = l[idx];
        } else if (self.c_list) |l| {
            pair = .{ std.mem.sliceTo(l.keys[idx], 0), MpvNode.from(@ptrCast(&l.values[idx])) };
        } else {
            pair = null;
        }
        if (pair == null) {
            self.index = 0;
        } else {
            self.index += 1;
        }

        return pair;
    }

    pub fn to_c(self: *Self, allocator: std.mem.Allocator) anyerror!*c.mpv_node_list {
        const len = self.size();

        var node_list_ptr = try allocator.create(c.mpv_node_list);
        var node_values = try allocator.alloc(c.mpv_node, len);
        var node_keys = try allocator.allocSentinel([*c]u8, len, null);

        var idx: usize = 0;
        while (self.next()) |node| {
            node_keys[idx] = node[0].ptr;
            const cnode: *c.mpv_node = @ptrCast(@alignCast(try node[1].to_c(allocator)));
            node_values[idx] = cnode.*;
            idx += 1;
        }

        node_list_ptr.num = @intCast(len);
        node_list_ptr.keys = @ptrCast(node_keys);
        node_list_ptr.values = node_values.ptr;
        return node_list_ptr;
    }

    pub fn copy(self: *Self, allocator: std.mem.Allocator) anyerror!Self {
        var list = try allocator.alloc(T, self.size());
        var idx: usize = 0;
        while (self.next()) |pair| {
            list[idx] = .{ try allocator.dupe(u8, pair[0]), try pair[1].copy(allocator) };
            idx += 1;
        }
        return Self.new(list);
    }

    pub fn free(self: *Self, allocator: std.mem.Allocator) void {
        while (self.next()) |pair| {
            allocator.free(pair[0]);
            pair[1].free(allocator);
        }
        allocator.free(self.list.?);
    }

    pub fn size(self: *Self) usize {
        if (self.list) |l| {
            return l.len;
        } else if (self.c_list) |l| {
            return @intCast(l.num);
        } else {
            return 0;
        }
    }
};
