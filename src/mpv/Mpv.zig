const std = @import("std");
const mpv_error = @import("./errors/mpv_error.zig");
const generic_error = @import("./errors/generic_error.zig");
const mpv_event = @import("./mpv_event.zig");
const utils = @import("./utils.zig");
const MpvPropertyData = @import("./mpv_event/MpvEventProperty.zig").MpvPropertyData;
const c = @import("./c.zig");

const MpvEvent = mpv_event.MpvEvent;
const MpvFormat = @import("./mpv_format.zig").MpvFormat;
const MpvLogLevel = @import("./mpv_event/MpvEventLogMessage.zig").MpvLogLevel;

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

pub fn initialize(self: Self) MpvError!void {
    const ret = c.mpv_initialize(self.handle);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

// TODO: Fix option `title` error on OSDString format
pub fn set_option(self: Self, key: [:0]const u8, format: MpvFormat, value: MpvPropertyData) !void {
    const data_ptr = try value.to_c(self.allocator);
    std.log.debug("[c_data]: format:{}", .{format});

    const ret = c.mpv_set_option(self.handle, key, format.to(), data_ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn set_option_string(self: Self, key: [:0]const u8, value: [:0]const u8) MpvError!void {
    const ret = c.mpv_set_option_string(self.handle, key, value);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn command(self: Self, args: [][]const u8) !void {
    const c_args = try utils.create_cstring_array(args, self.allocator);
    defer utils.free_cstring_array(c_args, args.len, self.allocator);

    const ret = c.mpv_command(self.handle, @ptrCast(c_args));
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub const LoadfileFlag = enum {
    Replace,
    Append,
    AppendPlay,
    InsertNext,
    InsertNextPlay,
    InsertAt,
    InsertAtPlay,

    pub fn to_string(self: LoadfileFlag) []const u8 {
        return switch (self) {
            .Replace => "replace",
            .Append => "append",
            .AppendPlay => "append-play",
            .InsertNext => "insert-next",
            .InsertNextPlay => "insert-next-play",
            .InsertAt => "insert-at",
            .InsertAtPlay => "insert-at-play",
        };
    }
};

pub fn loadfile(self: Self, filename: []const u8, args: struct {
    flag: LoadfileFlag = .Replace,
    index: usize = 0,
    options: []const u8 = "",
}) !void {
    const flag_str = args.flag.to_string();
    const index_str = try std.fmt.allocPrint(self.allocator, "{}", .{args.index});
    var cmd_args = [_][]const u8{ "loadfile", filename, flag_str, index_str, args.options };

    return self.command(&cmd_args);
}

pub fn command_string(self: Self, args: [*:0]const u8) MpvError!void {
    const ret = c.mpv_command_string(self.handle, @ptrCast(args));
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn command_async(self: Self, reply_userdata: u64, args: [][]const u8) !void {
    const c_args = try utils.create_cstring_array(args, self.allocator);
    defer utils.free_cstring_array(c_args, args.len, self.allocator);

    const ret = c.mpv_command_async(self.handle, reply_userdata, @ptrCast(c_args));
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

// TODO mpv_free allocated memory
// TODO empty string on MpvFormat.String
pub fn get_property(self: Self, name: [*:0]const u8, comptime format: MpvFormat) !MpvPropertyData {
    var output_mem: format.CDataType() = undefined;
    const data_ptr: *anyopaque = @ptrCast(@alignCast(&output_mem));
    const ret = c.mpv_get_property(self.handle, name, format.to(), data_ptr);
    defer {
        // TODO better way to free memory
        // IDEA: store a c data reference in the zig equivlent struct and free both together when user requests..
        // Freeing memory here
        // switch (format) {
        //     .String => {
        //         free(output_mem);
        //     },
        //     .Node => {
        //         free_cnode_content(data_ptr);
        //     },
        //     else => {},
        // }
    }
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }

    return try MpvPropertyData.from(format, data_ptr, self.allocator);
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

pub fn request_log_messages(self: Self, level: MpvLogLevel) MpvError!void {
    const ret = c.mpv_request_log_messages(self.handle, level.to_c_string());
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

fn free_cnode_content(data: ?*anyopaque) void {
    c.mpv_free_node_contents(@ptrCast(@alignCast(data)));
}
