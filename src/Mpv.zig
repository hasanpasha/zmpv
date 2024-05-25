const std = @import("std");
const testing = std.testing;
const mpv_error = @import("./mpv_error.zig");
const generic_error = @import("./generic_error.zig");
const MpvEvent = @import("./MpvEvent.zig");
const utils = @import("./utils.zig");
const MpvPropertyData = @import("./mpv_property_data.zig").MpvPropertyData;
const MpvEventId = @import("./mpv_event_id.zig").MpvEventId;
const c = @import("./c.zig");

const MpvFormat = @import("./mpv_format.zig").MpvFormat;
const MpvLogLevel = @import("./mpv_event_data_types//MpvEventLogMessage.zig").MpvLogLevel;
const MpvNode = @import("./mpv_node.zig").MpvNode;

const MpvError = mpv_error.MpvError;
const GenericError = generic_error.GenericError;

const Self = @This();

handle: *c.mpv_handle,
allocator: std.mem.Allocator,

/// Create an `Mpv` instance and set options if provided
pub fn create(allocator: std.mem.Allocator, options: ?[]const struct{[]const u8, []const u8}) !Self {
    const n_handle = c.mpv_create();

    if (n_handle) |handle| {
        var instance = Self{
            .handle = handle,
            .allocator = allocator,
        };

        if (options) |unwrapped_options| {
            for (unwrapped_options) |option| {
                try instance.set_option_string(option[0], option[1]);
            }
        }

        return instance;

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

// TODO this should be in the helper struct.
pub fn loadfile(self: Self, filename: []const u8, args: struct {
    flag: LoadfileFlag = .Replace,
    index: usize = 0,
    options: []const u8 = "",
}) !void {
    const flag_str = args.flag.to_string();
    const index_str = try std.fmt.allocPrint(self.allocator, "{}", .{args.index});
    defer self.allocator.free(index_str);

    var cmd_args = std.ArrayList([]const u8).init(self.allocator);
    defer cmd_args.deinit();

    try cmd_args.appendSlice(&[_][]const u8{ "loadfile", filename, flag_str });
    if (args.flag == .InsertAt or args.flag == .InsertAtPlay) {
        try cmd_args.append(index_str);
    }
    try cmd_args.append(args.options);

    return self.command(cmd_args.items);
}

pub fn command_string(self: Self, args: []const u8) MpvError!void {
    const ret = c.mpv_command_string(self.handle, args.ptr);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

/// The resulting MpvNode should be freed with `Mpv.free_node(node)`
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
    defer c.mpv_free_node_contents(&output);
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

fn mpv_free_data(data_anon_ptr: *anyopaque, format: MpvFormat) void {
    switch (format) {
        .String, .OSDString => {
            const str_ptr: *[*c]u8 = @ptrCast(@alignCast(data_anon_ptr));
            const str = str_ptr.*;
            c.mpv_free(str);
        },
        .Node, .NodeArray, .NodeMap => {
            c.mpv_free_node_contents(@ptrCast(@alignCast(data_anon_ptr)));
        },
        else => {},
    }
}

pub fn get_property(self: Self, name: []const u8, comptime format: MpvFormat) !MpvPropertyData {
    var output_mem: format.CDataType() = undefined;
    const data_ptr: *anyopaque = @ptrCast(@alignCast(&output_mem));
    const ret = c.mpv_get_property(self.handle, name.ptr, format.to(), data_ptr);
    defer mpv_free_data(data_ptr, format);
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
    defer c.mpv_free(returned_value);

    return try self.allocator.dupe(u8, std.mem.sliceTo(returned_value, 0));
}

/// free returned string with self.free(string);
pub fn get_property_osd_string(self: Self, name: []const u8) ![]u8 {
    const returned_value = c.mpv_get_property_osd_string(self.handle, name.ptr);
    if (returned_value == null) {
        return GenericError.NullValue;
    }
    defer c.mpv_free(returned_value);

    return try self.allocator.dupe(u8, std.mem.sliceTo(returned_value, 0));
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

/// the caller have to free allocated memory with `MpvEvent.free(event)`
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
    return std.mem.sliceTo(name, 0);
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
    return std.mem.sliceTo(error_str, 0);
}

pub fn free_property_data(self: Self, data: MpvPropertyData) void {
    data.free(self.allocator);
}

pub fn free_node(self: Self, node: MpvNode) void {
    node.free(self.allocator);
}

pub fn free(self: Self, data: anytype) void {
    self.allocator.free(data);
}

pub const MpvStreamCBInfo = struct {
    cookie: ?*anyopaque,
    read_fn: *const fn (?*anyopaque, []u8, u64) MpvError!u64,
    seek_fn: ?*const fn (?*anyopaque, u64) MpvError!u64,
    size_fn: ?*const fn (?*anyopaque) MpvError!u64,
    close_fn: ?*const fn (?*anyopaque) void,
    cancel_fn: ?*const fn (?*anyopaque) void,
};

const MpvStreamOpenState = struct {
    cb: *const fn (?*anyopaque, []u8, std.mem.Allocator) MpvError!MpvStreamCBInfo,
    user_data: ?*anyopaque,
    arena: std.heap.ArenaAllocator,
};

const MpvStreamState = struct {
    cbs: MpvStreamCBInfo,
    arena: std.heap.ArenaAllocator,
};

const s_cbs = struct {
    pub fn read_cb(inner_state_op: ?*anyopaque, buf: [*c]u8, size: u64) callconv(.C) i64 {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));

        var read_buf: []u8 = undefined;
        read_buf.ptr = buf;
        read_buf.len = size;

        const read_size = inner_state_ptr.cbs.read_fn(inner_state_ptr.cbs.cookie, read_buf, size) catch |err| {
            return mpv_error.to_mpv_c_error(err);
        };

        return @intCast(read_size);
    }

    pub fn close_cb(inner_state_op: ?*anyopaque) callconv(.C) void {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));
        var inner_arena = inner_state_ptr.*.arena;
        defer inner_arena.deinit();
        defer inner_arena.allocator().destroy(inner_state_ptr);

        if (inner_state_ptr.cbs.close_fn) |close_fn| {
            close_fn(inner_state_ptr.cbs.cookie);
        }
    }

    pub fn seek_cb(inner_state_op: ?*anyopaque, offset: i64) callconv(.C) i64 {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));

        if (inner_state_ptr.cbs.seek_fn) |seek_fn| {
            const npos = seek_fn(inner_state_ptr.cbs.cookie, @intCast(offset)) catch |err| {
                return mpv_error.to_mpv_c_error(err);
            };
            return @intCast(npos);
        } else {
            return mpv_error.to_mpv_c_error(MpvError.Unsupported);
        }
    }

    pub fn size_cb(inner_state_op: ?*anyopaque) callconv(.C) i64 {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));

        if (inner_state_ptr.cbs.size_fn) |size_fn| {
            const npos = size_fn(inner_state_ptr.cbs.cookie) catch |err| {
                return mpv_error.to_mpv_c_error(err);
            };
            return @intCast(npos);
        } else {
            return mpv_error.to_mpv_c_error(MpvError.Unsupported);
        }
    }

    pub fn cancel_cb(inner_state_op: ?*anyopaque) callconv(.C) void {
        const inner_state_ptr: *MpvStreamState = @ptrCast(@alignCast(inner_state_op));

        if (inner_state_ptr.cbs.close_fn) |cancel_fn| {
            cancel_fn(inner_state_ptr.cbs.cookie);
        }
    }
};

const s_open_cb = struct {
    pub fn cb(state_op: ?*anyopaque, c_protocol: [*c]u8, info: [*c]c.mpv_stream_cb_info) callconv(.C) c_int {
        const state_ptr: *MpvStreamOpenState = @ptrCast(@alignCast(state_op));

        var arena = state_ptr.arena;
        const allocator = arena.allocator();
        defer allocator.destroy(state_ptr);

        const z_info = state_ptr.cb(
            state_ptr.user_data,
            std.mem.sliceTo(c_protocol, 0),
            allocator,
        ) catch |err| {
            return mpv_error.to_mpv_c_error(err);
        };

        const info_state_ptr = allocator.create(MpvStreamState) catch {
            return mpv_error.to_mpv_c_error(MpvError.LoadingFailed);
        };

        info_state_ptr.*.cbs = z_info;
        info_state_ptr.*.arena = arena;

        info.*.cookie = @ptrCast(@alignCast(info_state_ptr));
        info.*.read_fn = s_cbs.read_cb;
        info.*.close_fn = s_cbs.close_cb;
        info.*.seek_fn = s_cbs.seek_cb;
        info.*.size_fn = s_cbs.size_cb;
        info.*.cancel_fn = s_cbs.cancel_cb;

        return mpv_error.to_mpv_c_error(MpvError.Success);
    }
}.cb;

pub fn stream_cb_add_ro(
    self: Self,
    protocol: []const u8,
    user_data: ?*anyopaque,
    open_fn: *const fn (?*anyopaque, []u8, std.mem.Allocator) MpvError!MpvStreamCBInfo,
) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    const state_ptr = try arena.allocator().create(MpvStreamOpenState);
    state_ptr.*.cb = open_fn;
    state_ptr.*.user_data = user_data;
    state_ptr.*.arena = arena;

    const ret = c.mpv_stream_cb_add_ro(self.handle, protocol.ptr, state_ptr, s_open_cb);
    const err = mpv_error.from_mpv_c_error(ret);

    if (err != MpvError.Success) {
        return err;
    }
}

test "Mpv simple test" {
    const mpv = try Self.create(std.testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();
}

test "Mpv memory leak" {
    const allocator = testing.allocator;

    const mpv = try Self.create(allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();
    try mpv.loadfile("sample.mp4", .{});

    while (true) {
        const event = try mpv.wait_event(10000);
        switch (event.event_id) {
            .Shutdown => break,
            .PlaybackRestart => break,
            else => {},
        }
    }
}

test "Mpv.set_option" {
    const allocator = testing.allocator;

    const mpv = try Self.create(allocator);
    try mpv.set_option("osc", .Flag, .{ .Flag = true });
    try mpv.initialize();
    defer mpv.terminate_destroy();

    const osc = try mpv.get_property("osc", .Flag);
    defer mpv.free_property_data(osc);

    try testing.expect(osc.Flag == true);
}

test "Mpv.set_option_string" {
    const allocator = testing.allocator;

    const mpv = try Self.create(allocator);
    try mpv.set_option("title", .String, .{ .String = "zmpv" });
    try mpv.initialize();
    defer mpv.terminate_destroy();

    const title = try mpv.get_property("title", .String);
    defer mpv.free_property_data(title);

    try testing.expect(std.mem.eql(u8, title.String, "zmpv"));
}


test "Mpv.load_config_file" {
    return error.SkipZigTest;
}

test "Mpv.command" {
    const allocator = testing.allocator;

    const mpv = try Self.create(allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    var args = [_][]const u8{"loadfile", "sample.mp4"};
    try mpv.command(&args);

    while (true) {
        const event = try mpv.wait_event(0);
        defer event.free();
        switch (event.event_id) {
            .FileLoaded => break,
            else => {}
        }
    }
}

test "Mpv.command_string" {
    const allocator = testing.allocator;

    const mpv = try Self.create(allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");

    while (true) {
        const event = try mpv.wait_event(0);
        defer event.free();
        switch (event.event_id) {
            .FileLoaded => break,
            else => {}
        }
    }
}

test "Mpv.command_async" {
    const allocator = testing.allocator;

    const mpv = try Self.create(allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    var args = [_][]const u8{"loadfile", "sample.mp4"};
    try mpv.command_async(0, &args);

    while (true) {
        const event = try mpv.wait_event(0);
        defer event.free();
        switch (event.event_id) {
            .FileLoaded => break,
            else => {}
        }
    }
}

test "Mpv.command_node" {
    const allocator = testing.allocator;

    const mpv = try Self.create(allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    var args = [_]MpvNode{ .{ .String = "loadfile" }, .{ .String = "sample.mp4" } };
    const result = try mpv.command_node(.{ .NodeArray = &args });
    defer mpv.free_node(result);

    while (true) {
        const event = try mpv.wait_event(0);
        defer event.free();
        switch (event.event_id) {
            .FileLoaded => break,
            else => {}
        }
    }
}