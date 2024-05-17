const std = @import("std");
const mpv_error = @import("./errors/mpv_error.zig");
const generic_error = @import("./errors/generic_error.zig");
const mpv_event = @import("./mpv_event.zig");
const utils = @import("./utils.zig");
const MpvPropertyData = @import("./mpv_property_data.zig").MpvPropertyData;
const MpvEventId = @import("./mpv_event/mpv_event_id.zig").MpvEventId;
const c = @import("./c.zig");

const MpvEvent = mpv_event.MpvEvent;
const MpvFormat = @import("./mpv_format.zig").MpvFormat;
const MpvLogLevel = @import("./mpv_event/MpvEventLogMessage.zig").MpvLogLevel;
const MpvNode = @import("./MpvNode.zig");

const MpvError = mpv_error.MpvError;
const GenericError = generic_error.GenericError;

const Self = @This();

handle: *c.mpv_handle,
allocator: std.mem.Allocator,

pub fn create(allocator: std.mem.Allocator) GenericError!Self {
    const n_handle = c.mpv_create();

    if (n_handle) |handle| {
        return Self{
            .handle = handle,
            .allocator = allocator,
        };
    } else {
        return GenericError.NullValue;
    }
}

pub fn create_client(self: Self, name: []const u8) GenericError!Self {
    const n_client_handle = c.mpv_create_client(self.handle, name.ptr);

    if (n_client_handle) |handle| {
        return Self{
            .handle = handle,
            .allocator = self.allocator,
        };
    } else {
        return GenericError.NullValue;
    }
}

pub fn create_weak_client(self: Self, name: []const u8) GenericError!Self {
    const n_weak_client_handle = c.mpv_create_weak_client(self.handle, name.ptr);

    if (n_weak_client_handle) |handle| {
        return Self{
            .handle = handle,
            .allocator = self.allocator,
        };
    } else {
        return GenericError.NullValue;
    }
}

pub fn initialize(self: Self) MpvError!void {
    const ret = c.mpv_initialize(self.handle);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

// TODO: Fix option `title` error on OSDString format
pub fn set_option(self: Self, key: []const u8, format: MpvFormat, value: MpvPropertyData) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const this_allocator = arena.allocator();
    const data_ptr = try value.to_c(this_allocator);

    const ret = c.mpv_set_option(self.handle, key.ptr, format.to(), data_ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn set_option_string(self: Self, key: []const u8, value: []const u8) MpvError!void {
    const ret = c.mpv_set_option_string(self.handle, key.ptr, value.ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn load_config_file(self: Self, filename: []const u8) MpvError!void {
    const ret = c.mpv_load_config_file(self.handle, filename.ptr);
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
    defer self.allocator.free(index_str);
    var cmd_args = [_][]const u8{ "loadfile", filename, flag_str, index_str, args.options };

    return self.command(&cmd_args);
}

pub fn command_string(self: Self, args: []const u8) MpvError!void {
    const ret = c.mpv_command_string(self.handle, args.ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn command_node(self: Self, args: MpvNode) !MpvNode {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const c_node_ptr = try args.to_c(arena.allocator());

    var output: c.mpv_node = undefined;

    const ret = c.mpv_command_node(self.handle, @ptrCast(c_node_ptr), @ptrCast(&output));
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }

    return try MpvNode.from(@ptrCast(&output), self.allocator);
}

pub fn command_ret(self: Self, args: [][]const u8) !MpvNode {
    const c_args = try utils.create_cstring_array(args, self.allocator);
    defer utils.free_cstring_array(c_args, args.len, self.allocator);

    var output: c.mpv_node = undefined;

    const ret = c.mpv_command_ret(self.handle, @ptrCast(c_args), @ptrCast(&output));
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }

    return try MpvNode.from(@ptrCast(&output), self.allocator);
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

pub fn command_node_async(self: Self, reply_userdata: u64, args: MpvNode) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const c_node_ptr = try args.to_c(arena.allocator());

    const ret = c.mpv_command_node_async(self.handle, reply_userdata, @ptrCast(c_node_ptr));
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn abort_async_command(self: Self, reply_userdata: u64) void {
    c.mpv_abort_async_command(self.handle, reply_userdata);
}

pub fn get_property(self: Self, name: []const u8, comptime format: MpvFormat) !MpvPropertyData {
    var output_mem: format.CDataType() = undefined;
    const data_ptr: *anyopaque = @ptrCast(@alignCast(&output_mem));
    const ret = c.mpv_get_property(self.handle, name.ptr, format.to(), data_ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }

    return try MpvPropertyData.from(format, data_ptr, self.allocator);
}

/// The returened value should be freed with self.free(string)
pub fn get_property_string(self: Self, name: []const u8) ![]u8 {
    const returned_value = c.mpv_get_property_string(self.handle, name.ptr);
    if (returned_value == null) {
        return GenericError.NullValue;
    }
    defer mpv_free(returned_value);

    return try self.allocator.dupe(u8, std.mem.span(returned_value));
}

/// free returned string with self.free(string);
pub fn get_property_osd_string(self: Self, name: []const u8) ![]u8 {
    const returned_value = c.mpv_get_property_osd_string(self.handle, name.ptr);
    if (returned_value == null) {
        return GenericError.NullValue;
    }
    defer mpv_free(returned_value);

    return try self.allocator.dupe(u8, std.mem.span(returned_value));
}

pub fn get_property_async(self: Self, reply_userdata: u64, name: []const u8, format: MpvFormat) MpvError!void {
    const ret = c.mpv_get_property_async(self.handle, reply_userdata, name.ptr, format.to());
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn set_property(self: Self, name: []const u8, format: MpvFormat, value: MpvPropertyData) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const data_ptr = try value.to_c(arena.allocator());

    const ret = c.mpv_set_property(self.handle, name.ptr, format.to(), data_ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn set_property_string(self: Self, name: []const u8, value: []const u8) MpvError!void {
    const ret = c.mpv_set_property_string(self.handle, name.ptr, value.ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn set_property_async(self: Self, reply_userdata: u64, name: []const u8, format: MpvFormat, value: MpvPropertyData) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const data_ptr = try value.to_c(arena.allocator());

    const ret = c.mpv_set_property_async(self.handle, reply_userdata, name.ptr, format.to(), data_ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn del_property(self: Self, name: []const u8) MpvError!void {
    const ret = c.mpv_del_property(self.handle, name.ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn observe_property(self: Self, reply_userdata: u64, name: []const u8, format: MpvFormat) MpvError!void {
    const ret = c.mpv_observe_property(self.handle, reply_userdata, name.ptr, format.to());
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn unobserve_property(self: Self, registered_reply_userdata: u64) MpvError!void {
    const ret = c.mpv_unobserve_property(self.handle, registered_reply_userdata);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn request_log_messages(self: Self, level: MpvLogLevel) MpvError!void {
    const ret = c.mpv_request_log_messages(self.handle, level.to_string().ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn hook_add(self: Self, reply_userdata: u64, name: []const u8, priority: i64) MpvError!void {
    const ret = c.mpv_hook_add(self.handle, reply_userdata, name.ptr, @intCast(priority));
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn hook_continue(self: Self, id: u64) MpvError!void {
    const ret = c.mpv_hook_continue(self.handle, id);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn request_event(self: Self, event_id: MpvEventId, enable: bool) MpvError!void {
    const ret = c.mpv_request_event(self.handle, event_id.to_c(), if (enable) 1 else 0);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

pub fn wait_event(self: Self, timeout: f64) !MpvEvent {
    const event = c.mpv_wait_event(self.handle, timeout);

    return try MpvEvent.from(event, self.allocator);
}

pub fn wait_async_requests(self: Self) void {
    c.mpv_wait_async_requests(self.handle);
}

pub fn wakeup(self: Self) void {
    c.mpv_wakeup(self.handle);
}

pub fn set_wakeup_callback(self: Self, callback_function: *const fn (?*anyopaque) void, data: ?*anyopaque) void {
    c.mpv_set_wakeup_callback(self.handle, @ptrCast(callback_function), data);
}

pub fn get_wakeup_pipe(self: Self) MpvError!c_int {
    const ret = c.mpv_get_wakeup_pipe(self.handle);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }

    return ret;
}

pub fn client_name(self: Self) []const u8 {
    const name = c.mpv_client_name(self.handle);
    return std.mem.span(name);
}

pub fn client_id(self: Self) i64 {
    return c.mpv_client_id(self.handle);
}

pub fn get_time_ns(self: Self) i64 {
    return c.mpv_get_time_ns(self.handle);
}

pub fn get_time_us(self: Self) i64 {
    return c.mpv_get_time_us(self.handle);
}

pub fn destroy(self: Self) void {
    c.mpv_destroy(self.handle);
}

pub fn terminate_destroy(self: Self) void {
    c.mpv_terminate_destroy(self.handle);
}

pub fn error_string(err: MpvError) []const u8 {
    const error_str = c.mpv_error_string(mpv_error.to_mpv_c_error(err));
    return std.mem.span(error_str);
}

pub fn free_property_data(self: Self, data: MpvPropertyData) void {
    data.free(self.allocator);
}

pub fn free(self: Self, data: anytype) void {
    self.allocator.free(data);
}

fn mpv_free(data: ?*anyopaque) void {
    c.mpv_free(data);
}

fn mpv_free_node_content(data: ?*anyopaque) void {
    c.mpv_free_node_contents(@ptrCast(@alignCast(data)));
}
