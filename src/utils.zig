const std = @import("std");
const testing = std.testing;

pub fn create_cstring_array(z_array: [][]const u8, allocator: std.mem.Allocator) ![][*c]const u8 {
    const array = try allocator.alloc([*c]const u8, z_array.len + 1);
    array[array.len - 1] = null;
    for (0..z_array.len) |index| {
        array[index] = try allocator.dupeZ(u8, z_array[index]);
    }
    return array;
}

pub fn free_cstring_array(c_array: [][*c]const u8, n: usize, allocator: std.mem.Allocator) void {
    const array = c_array;
    for (0..n) |index| {
        const slice: [:0]const u8 = std.mem.sliceTo(array[index], 0);
        allocator.free(slice);
    }
    allocator.free(array);
}

pub fn create_zstring_array(c_array: [*c][*c]const u8, n: usize, allocator: std.mem.Allocator) ![][]const u8 {
    const array = try allocator.alloc([]const u8, n);
    for (0..n) |index| {
        array[index] = try allocator.dupe(u8, std.mem.sliceTo(c_array[index], 0));
    }
    return array;
}

pub fn free_zstring_array(z_array: [][]const u8, allocator: std.mem.Allocator) void {
    for (0..z_array.len) |index| {
        allocator.free(z_array[index]);
    }
    allocator.free(z_array);
}

pub fn cast_event_data(data_ptr: ?*anyopaque, return_data: type) return_data {
    const casted_data: *return_data = @ptrCast(@alignCast(data_ptr));
    return casted_data.*;
}

test "zstring to cstring array" {
    const allocator = testing.allocator;

    var zstrings = [_][]const u8{ "hello", "world" };
    const cstrings = try create_cstring_array(&zstrings, allocator);
    defer free_cstring_array(cstrings, zstrings.len, allocator);
    try testing.expect(zstrings[0][0] == cstrings[0][0]);
    try testing.expect(zstrings[1][0] == cstrings[1][0]);
    try testing.expect(zstrings[0][0] != cstrings[1][0]);
    for (0.., zstrings) |i, string| {
        for (0.., string) |j, char| {
            try testing.expect(char == cstrings[i][j]);
        }
    }
}

test "cstring to zstring array" {
    const allocator = testing.allocator;

    var cstrings = [_][*c]const u8{ "hello", "world" };
    const zstrings = try create_zstring_array(&cstrings, 2, allocator);
    defer free_zstring_array(zstrings, allocator);
    try testing.expect(zstrings[0][0] == cstrings[0][0]);
    try testing.expect(zstrings[1][2] == cstrings[1][2]);
    try testing.expect(zstrings[0][0] != cstrings[1][1]);
    for (0.., zstrings) |i, string| {
        for (0.., string) |j, char| {
            try testing.expect(char == cstrings[i][j]);
        }
    }
}
