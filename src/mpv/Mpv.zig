const std = @import("std");
const mpv_error = @import("./errors/mpv_error.zig");
const generic_error = @import("./errors/generic_error.zig");
const mpv_event = @import("./mpv_event.zig");

const c = @import("./c.zig");

const MpvEvent = mpv_event.MpvEvent;
const MpvFormat = @import("./mpv_format.zig").MpvFormat;

const MpvError = mpv_error.MpvError;
const GenericError = generic_error.GenericError;

const Self = @This();

handle: *c.mpv_handle,
// arena: std.heap.ArenaAllocator,
allocator: std.mem.Allocator,

pub fn new(allocator: std.mem.Allocator) GenericError!Self {
    const handle = c.mpv_create();
    if (handle == null) {
        return GenericError.NullValue;
    }

    // var arena = std.heap.ArenaAllocator.init(allocator);

    return Self{
        .handle = handle.?,
        // .arena = arena,
        .allocator = allocator,
    };
}

pub fn set_option_string(self: Self, key: []const u8, value: []const u8) MpvError!void {
    const ret = c.mpv_set_option_string(self.handle, @ptrCast(key), @ptrCast(value));
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn initialize(self: Self) MpvError!void {
    const ret = c.mpv_initialize(self.handle);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

/// args is a null terminal list of strings
/// e.g. [_][*c]const u8{"loadfile", "video.mp4", null}
/// TODO: Fix this function
pub fn command(self: Self, args: [][*:0]const u8) MpvError!void {
    const a: [*c][*c]const u8 = @ptrCast(args);
    std.debug.print("\n[type of command]: {}", .{@TypeOf(a)});
    // const ret = c.mpv_command(self.handle, @ptrCast(args));
    // const ret = c.mpv_command(self.handle, args);
    // const err = mpv_error.from_mpv_c_error(ret);

    // if (err != MpvError.Success) {
    // return err;
    // }
    _ = self;
}

pub fn command_string(self: Self, args: [*:0]const u8) MpvError!void {
    const ret = c.mpv_command_string(self.handle, @ptrCast(args));
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn get_property_string(self: Self, name: [*:0]const u8) ![]u8 {
    const returned_value = c.mpv_get_property_string(self.handle, name);
    if (returned_value == null) {
        return GenericError.NullValue;
    }
    defer free(returned_value);

    const string = try self.allocator.dupe(u8, std.mem.span(returned_value));
    // std.debug.print("\n[[{s}]]\n\n", .{string});
    return string;
}

pub fn set_property_string(self: Self, name: [*:0]const u8, value: [*:0]const u8) MpvError!void {
    const ret = c.mpv_set_property_string(self.handle, name, value);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn observe_property(self: Self, reply_userdata: u64, name: [*:0]const u8, format: MpvFormat) MpvError!void {
    const ret = c.mpv_observe_property(self.handle, reply_userdata, name, format.to());
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn wait_event(self: Self, timeout: f64) !MpvEvent {
    const event = c.mpv_wait_event(self.handle, timeout);

    return try MpvEvent.from(event, self.allocator);
}

pub fn terminate_destroy(self: Self) void {
    c.mpv_terminate_destroy(self.handle);
}

fn free(data: ?*anyopaque) void {
    c.mpv_free(data);
}
