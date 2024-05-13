const std = @import("std");

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
        const slice: [:0]const u8 = std.mem.span(array[index]);
        allocator.free(slice);
    }
    allocator.free(array);
}

pub fn create_zstring_array(c_array: [*c][*c]const u8, n: usize, allocator: std.mem.Allocator) ![][]const u8 {
    const array = try allocator.alloc([]const u8, n);
    for (0..n) |index| {
        array[index] = try allocator.dupe(u8, std.mem.span(c_array[index]));
    }
    return array;
}

pub fn free_zstring_array(z_array: [][]const u8, allocator: std.mem.Allocator) void {
    for (0..z_array.len) |index| {
        allocator.free(z_array[index]);
    }
    allocator.free(z_array);
}
