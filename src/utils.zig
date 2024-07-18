const std = @import("std");
const mpv_error = @import("./mpv_error.zig");
const MpvError = mpv_error.MpvError;
const testing = std.testing;

pub fn create_cstring_array(z_array: []const []const u8, allocator: std.mem.Allocator) ![:0][*c]const u8 {
    const array = try allocator.allocSentinel([*c]const u8, z_array.len, 0);
    for (0..z_array.len) |index| {
        array[index] = try allocator.dupeZ(u8, z_array[index]);
    }
    return array;
}

pub fn free_cstring_array(c_array: [:0][*c]const u8, allocator: std.mem.Allocator) void {
    for (0..c_array.len) |index| {
        const slice: [:0]const u8 = std.mem.sliceTo(c_array[index], 0);
        allocator.free(slice);
    }
    allocator.free(c_array);
}

pub fn cast_anyopaque_ptr(T: type, ptr: ?*anyopaque) *T {
    return @ptrCast(@alignCast(ptr));
}

pub fn catch_mpv_error(ret_code: c_int) MpvError!void {
    if (ret_code < 0) {
        return mpv_error.from_mpv_c_error(ret_code);
    }
}

test "zstring to cstring array" {
    const allocator = testing.allocator;

    var zstrings = [_][]const u8{ "hello", "world" };
    const cstrings = try create_cstring_array(&zstrings, allocator);
    defer free_cstring_array(cstrings, allocator);
    try testing.expect(zstrings[0][0] == cstrings[0][0]);
    try testing.expect(zstrings[1][0] == cstrings[1][0]);
    try testing.expect(zstrings[0][0] != cstrings[1][0]);
    for (0.., zstrings) |i, string| {
        for (0.., string) |j, char| {
            try testing.expect(char == cstrings[i][j]);
        }
    }
}
