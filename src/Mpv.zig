const std = @import("std");
const testing = std.testing;
const mpv_error = @import("./mpv_error.zig");
const generic_error = @import("./generic_error.zig");
const MpvEvent = @import("./MpvEvent.zig");
const utils = @import("./utils.zig");
const catch_mpv_error = utils.catch_mpv_error;
const MpvPropertyData = @import("./mpv_property_data.zig").MpvPropertyData;
const MpvEventId = @import("./mpv_event_id.zig").MpvEventId;
const c = @import("./c.zig");
const types = @import("./types.zig");
const MpvNodeList = types.MpvNodeList;
const MpvNodeMap = types.MpvNodeMap;
const MpvFormat = @import("./mpv_format.zig").MpvFormat;
const MpvLogLevel = @import("./mpv_event_data_types/MpvEventLogMessage.zig").MpvLogLevel;
const MpvNode = @import("./mpv_node.zig").MpvNode;

const MpvError = mpv_error.MpvError;
const GenericError = generic_error.GenericError;

const Self = @This();

handle: *c.mpv_handle,
allocator: std.mem.Allocator,

pub fn create(allocator: std.mem.Allocator) !*Self {
    const handle = c.mpv_create() orelse return GenericError.NullValue;

    const instance_ptr = try allocator.create(Self);
    instance_ptr.* = Self{ .handle = handle, .allocator = allocator };

    return instance_ptr;
}

pub fn create_client(self: Self, name: []const u8) !*Self {
    const client_handle = c.mpv_create_client(self.handle, name.ptr) orelse return GenericError.NullValue;

    const instance_ptr = try self.allocator.create(Self);
    instance_ptr.* = Self{ .handle = client_handle, .allocator = self.allocator };

    return instance_ptr;
}

pub fn create_weak_client(self: Self, name: []const u8) !*Self {
    const weak_client_handle = c.mpv_create_weak_client(self.handle, name.ptr) orelse return GenericError.NullValue;

    const instance_ptr = try self.allocator.create(Self);
    instance_ptr.* = Self{ .handle = weak_client_handle, .allocator = self.allocator };

    return instance_ptr;
}

pub fn initialize(self: Self) MpvError!void {
    try catch_mpv_error(c.mpv_initialize(self.handle));
}

pub fn set_option(self: Self, key: []const u8, format: MpvFormat, value: MpvPropertyData) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const data_ptr = try value.to_c(arena.allocator());

    try catch_mpv_error(c.mpv_set_option(self.handle, key.ptr, format.to_c(), data_ptr));
}

pub fn set_option_string(self: Self, key: []const u8, value: []const u8) MpvError!void {
    try catch_mpv_error(c.mpv_set_option_string(self.handle, key.ptr, value.ptr));
}

pub fn load_config_file(self: Self, filename: []const u8) MpvError!void {
    try catch_mpv_error(c.mpv_load_config_file(self.handle, filename.ptr));
}

pub fn command(self: Self, args: []const []const u8) !void {
    const c_args = try utils.create_cstring_array(args, self.allocator);
    defer utils.free_cstring_array(c_args, self.allocator);

    try catch_mpv_error(c.mpv_command(self.handle, @ptrCast(c_args)));
}

pub fn command_string(self: Self, args: []const u8) MpvError!void {
    try catch_mpv_error(c.mpv_command_string(self.handle, args.ptr));
}

/// The resulting MpvNode should be freed with `self.free(node)`
pub fn command_node(self: Self, args: MpvNode) !MpvNode {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const c_node_ptr = try args.to_c(arena.allocator());

    var output: c.mpv_node = undefined;

    try catch_mpv_error(c.mpv_command_node(self.handle, @ptrCast(c_node_ptr), @ptrCast(&output)));
    defer c.mpv_free_node_contents(&output);

    return try MpvNode.from(@ptrCast(&output)).copy(self.allocator);
}

/// The resulting MpvNode should be freed with `self.free(node)`
pub fn command_ret(self: Self, args: []const []const u8) !MpvNode {
    const c_args = try utils.create_cstring_array(args, self.allocator);
    defer utils.free_cstring_array(c_args, self.allocator);

    var output: c.mpv_node = undefined;

    try catch_mpv_error(c.mpv_command_ret(self.handle, @ptrCast(c_args), @ptrCast(&output)));
    defer c.mpv_free_node_contents(&output);

    return try MpvNode.from(@ptrCast(&output)).copy(self.allocator);
}

pub fn command_async(self: Self, reply_userdata: u64, args: []const []const u8) !void {
    const c_args = try utils.create_cstring_array(args, self.allocator);
    defer utils.free_cstring_array(c_args, self.allocator);

    try catch_mpv_error(c.mpv_command_async(self.handle, reply_userdata, @ptrCast(c_args)));
}

pub fn command_node_async(self: Self, reply_userdata: u64, args: MpvNode) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const c_node_ptr = try args.to_c(arena.allocator());

    try catch_mpv_error(c.mpv_command_node_async(self.handle, reply_userdata, @ptrCast(c_node_ptr)));
}

pub fn abort_async_command(self: Self, reply_userdata: u64) void {
    c.mpv_abort_async_command(self.handle, reply_userdata);
}

/// The returened value must be freed with self.free(value)
pub fn get_property(self: Self, name: []const u8, comptime format: MpvFormat) !MpvPropertyData {
    var output_mem: format.CDataType() = undefined;
    const data_ptr: *anyopaque = @ptrCast(@alignCast(&output_mem));

    try catch_mpv_error(c.mpv_get_property(self.handle, name.ptr, format.to_c(), data_ptr));
    defer {
        switch (format) {
            .String, .OSDString => {
                c.mpv_free(output_mem);
            },
            .Node, .NodeArray, .NodeMap => {
                c.mpv_free_node_contents(&output_mem);
            }, else => {},
        }
    }

    return try MpvPropertyData.from(format, data_ptr).copy(self.allocator);
}

/// The returened value must be freed with self.free(value)
pub fn get_property_string(self: Self, name: []const u8) ![]u8 {
    const returned_value = c.mpv_get_property_string(self.handle, name.ptr);
    if (returned_value == null) {
        return GenericError.NullValue;
    }
    defer c.mpv_free(returned_value);

    return try self.allocator.dupe(u8, std.mem.sliceTo(returned_value, 0));
}

/// The returened value must be freed with self.free(value)
pub fn get_property_osd_string(self: Self, name: []const u8) ![]u8 {
    const returned_value = c.mpv_get_property_osd_string(self.handle, name.ptr);
    if (returned_value == null) {
        return GenericError.NullValue;
    }
    defer c.mpv_free(returned_value);

    return try self.allocator.dupe(u8, std.mem.sliceTo(returned_value, 0));
}

pub fn get_property_async(self: Self, reply_userdata: u64, name: []const u8, format: MpvFormat) MpvError!void {
    try catch_mpv_error(c.mpv_get_property_async(self.handle, reply_userdata, name.ptr, format.to_c()));
}

pub fn set_property(self: Self, name: []const u8, format: MpvFormat, value: MpvPropertyData) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const data_ptr = try value.to_c(arena.allocator());

    try catch_mpv_error(c.mpv_set_property(self.handle, name.ptr, format.to_c(), data_ptr));
}

pub fn set_property_string(self: Self, name: []const u8, value: []const u8) MpvError!void {
    try catch_mpv_error(c.mpv_set_property_string(self.handle, name.ptr, value.ptr));
}

pub fn set_property_async(self: Self, reply_userdata: u64, name: []const u8, format: MpvFormat, value: MpvPropertyData) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const data_ptr = try value.to_c(arena.allocator());

    try catch_mpv_error(c.mpv_set_property_async(self.handle, reply_userdata, name.ptr, format.to_c(), data_ptr));
}

pub fn del_property(self: Self, name: []const u8) MpvError!void {
    try catch_mpv_error(c.mpv_del_property(self.handle, name.ptr));
}

pub fn observe_property(self: Self, reply_userdata: u64, name: []const u8, format: MpvFormat) MpvError!void {
    try catch_mpv_error(c.mpv_observe_property(self.handle, reply_userdata, name.ptr, format.to_c()));
}

pub fn unobserve_property(self: Self, registered_reply_userdata: u64) MpvError!void {
    try catch_mpv_error(c.mpv_unobserve_property(self.handle, registered_reply_userdata));
}

pub fn request_log_messages(self: Self, level: MpvLogLevel) MpvError!void {
    try catch_mpv_error(c.mpv_request_log_messages(self.handle, level.to_string().ptr));
}

pub fn hook_add(self: Self, reply_userdata: u64, name: []const u8, priority: i64) MpvError!void {
    try catch_mpv_error(c.mpv_hook_add(self.handle, reply_userdata, name.ptr, @intCast(priority)));
}

pub fn hook_continue(self: Self, id: u64) MpvError!void {
    try catch_mpv_error(c.mpv_hook_continue(self.handle, id));
}

pub fn request_event(self: Self, event_id: MpvEventId, enable: bool) MpvError!void {
    try catch_mpv_error(c.mpv_request_event(self.handle, event_id.to_c(), if (enable) 1 else 0));
}

pub fn wait_event(self: Self, timeout: f64) MpvEvent {
    const event = c.mpv_wait_event(self.handle, timeout);

    return MpvEvent.from(event);
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
    try catch_mpv_error(ret);

    return ret;
}

pub fn client_name(self: Self) []const u8 {
    const name = c.mpv_client_name(self.handle);
    return std.mem.sliceTo(name, 0);
}

pub fn client_id(self: Self) i64 {
    return c.mpv_client_id(self.handle);
}

pub fn client_api_version() u32 {
    return @intCast(c.mpv_client_api_version());
}

pub fn get_time_ns(self: Self) i64 {
    return c.mpv_get_time_ns(self.handle);
}

pub fn get_time_us(self: Self) i64 {
    return c.mpv_get_time_us(self.handle);
}

pub fn destroy(self: *Self) void {
    c.mpv_destroy(self.handle);
    self.allocator.destroy(self);
}

pub fn terminate_destroy(self: *Self) void {
    c.mpv_terminate_destroy(self.handle);
    self.allocator.destroy(self);
}

pub fn error_string(err: MpvError) []const u8 {
    const error_str = c.mpv_error_string(mpv_error.to_mpv_c_error(err));
    return std.mem.sliceTo(error_str, 0);
}

pub fn free(self: Self, data: anytype) void {
    switch (@TypeOf(data)) {
        MpvNode, MpvPropertyData => {
            data.free(self.allocator);
        },
        []u8, []const u8 => {
            self.allocator.free(data);
        },
        else => {},
    }
    std.log.debug("{any}", .{@TypeOf(data)});
}

pub usingnamespace @import("./mpv_helper.zig");
pub usingnamespace @import("./stream_cb.zig");

test "Mpv simple test" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();
}

test "Mpv memory leak" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();
    
    try mpv.command_string("loadfile sample.mp4");

    while (true) {
        const event = mpv.wait_event(10000);
        switch (event.event_id) {
            .Shutdown => break,
            .PlaybackRestart => break,
            else => {},
        }
    }
}

test "Mpv.set_option" {
    const mpv = try Self.create(testing.allocator);
    try mpv.set_option("osc", .Flag, .{ .Flag = true });
    try mpv.initialize();
    defer mpv.terminate_destroy();

    const osc = try mpv.get_property("osc", .Flag);
    defer mpv.free(osc);

    try testing.expect(osc.Flag == true);
}

test "Mpv.set_option_string" {
    const mpv = try Self.create(testing.allocator);
    try mpv.set_option("title", .String, .{ .String = "zmpv" });
    try mpv.initialize();
    defer mpv.terminate_destroy();

    const title = try mpv.get_property("title", .String);
    defer mpv.free(title);

    try testing.expect(std.mem.eql(u8, title.String, "zmpv"));
}

test "Mpv.load_config_file" {
    return error.SkipZigTest;
}

test "Mpv.command" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.command(&.{ "loadfile", "sample.mp4" });

    while (true) {
        const event = mpv.wait_event(0);
        switch (event.event_id) {
            .FileLoaded => break,
            else => {},
        }
    }
}

test "Mpv.command_string" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.command_string("loadfile sample.mp4");

    while (true) {
        const event = mpv.wait_event(0);
        switch (event.event_id) {
            .FileLoaded => break,
            else => {},
        }
    }
}

test "Mpv.command_async" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.command_async(0, &.{ "loadfile", "sample.mp4" });

    while (true) {
        const event = mpv.wait_event(0);
        switch (event.event_id) {
            .FileLoaded => break,
            else => {},
        }
    }
}

test "Mpv.command_node" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    var args = [_]MpvNode{ .{ .String = "loadfile" }, .{ .String = "sample.mp4" } };
    const result = try mpv.command_node(.{ .NodeArray = MpvNodeList.new(&args) });
    defer mpv.free(result);

    while (true) {
        const event = mpv.wait_event(0);
        switch (event.event_id) {
            .FileLoaded => break,
            else => {},
        }
    }
}

test "Mpv.get_property list" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.command(&.{ "loadfile", "sample.mp4" });

    while (true) {
        const event = mpv.wait_event(0);
        switch (event.event_id) {
            .StartFile => {
                const playlist = try mpv.get_property("playlist", .Node);
                defer mpv.free(playlist);
                var iter = playlist.Node.NodeArray.iterator();
                var array = try playlist.Node.NodeArray.to_owned_arraylist(mpv.allocator);
                defer array.deinit();
                defer MpvNodeList.free_owned_arraylist(array, mpv.allocator);
                try testing.expect(array.items.len == 1);
                try testing.expect(iter.size() == 1);
                const map = iter.next().?.NodeMap;
                var map_iter = map.iterator();
                try testing.expect(map_iter.size() == 4);
                var hashmap = try map.to_owned_hashmap(mpv.allocator);
                defer hashmap.deinit();
                defer MpvNodeMap.free_owned_hashmap(hashmap, mpv.allocator);
                const filename = hashmap.get("filename");
                try testing.expect(filename != null);
                try testing.expectEqualStrings("sample.mp4" ,filename.?.String);
                const filename_pair = map_iter.next().?;
                try testing.expect(std.mem.eql(u8, filename_pair[0], "filename"));
                try testing.expect(std.mem.eql(u8, filename_pair[1].String, "sample.mp4"));
                const current_pair = map_iter.next().?;
                try testing.expect(std.mem.eql(u8, current_pair[0], "current"));
                const playing_pair = map_iter.next().?;
                try testing.expect(std.mem.eql(u8, playing_pair[0], "playing"));
                const id_pair = map_iter.next().?;
                try testing.expect(std.mem.eql(u8, id_pair[0], "id"));
                try testing.expect(id_pair[1].INT64 == 1);
                break;
            },
            else => {},
        }
    }
}
