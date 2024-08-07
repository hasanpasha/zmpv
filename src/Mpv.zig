const std = @import("std");
const c = @import("c.zig");
const mpv_error = @import("mpv_error.zig");
const generic_error = @import("generic_error.zig");
const MpvEvent = @import("MpvEvent.zig");
const MpvPropertyData = @import("mpv_property_data.zig").MpvPropertyData;
const MpvEventId = @import("mpv_event_id.zig").MpvEventId;
const types = @import("types.zig");
const MpvNodeList = types.MpvNodeList;
const MpvNodeMap = types.MpvNodeMap;
const MpvFormat = @import("mpv_format.zig").MpvFormat;
const MpvLogLevel = @import("mpv_event_data_types/MpvEventLogMessage.zig").MpvLogLevel;
const MpvNode = @import("mpv_node.zig").MpvNode;
const utils = @import("utils.zig");
const catch_mpv_error = utils.catch_mpv_error;
const testing = std.testing;

const MpvError = mpv_error.MpvError;
const GenericError = generic_error.GenericError;
const AllocatorError = std.mem.Allocator.Error;

const Self = @This();

handle: *c.mpv_handle,
allocator: std.mem.Allocator,

pub fn create(allocator: std.mem.Allocator) GenericError!Self {
    const handle = c.mpv_create() orelse return GenericError.NullValue;
    return Self{ .handle = handle, .allocator = allocator };
}

pub fn create_client(self: Self, args: struct {
    name: ?[]const u8 = null,
}) GenericError!Self {
    const name_arg = if (args.name) |name| name.ptr else null;
    const client_handle = c.mpv_create_client(self.handle, name_arg) orelse return GenericError.NullValue;

    return Self{ .handle = client_handle, .allocator = self.allocator };
}

pub fn create_weak_client(self: Self, args: struct {
    name: ?[]const u8 = null,
}) GenericError!Self {
    const name_arg = if (args.name) |name| name.ptr else null;
    const weak_client_handle = c.mpv_create_weak_client(self.handle, name_arg) orelse return GenericError.NullValue;

    return Self{ .handle = weak_client_handle, .allocator = self.allocator };
}

pub fn initialize(self: Self) MpvError!void {
    try catch_mpv_error(c.mpv_initialize(self.handle));
}

pub fn set_option(self: Self, key: []const u8, value: MpvPropertyData) (AllocatorError || MpvError)!void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const data_ptr = try value.to_c(arena.allocator());

    try catch_mpv_error(c.mpv_set_option(self.handle, key.ptr, std.meta.activeTag(value).to_c(), data_ptr));
}

pub fn set_option_string(self: Self, key: []const u8, value: []const u8) MpvError!void {
    try catch_mpv_error(c.mpv_set_option_string(self.handle, key.ptr, value.ptr));
}

pub fn load_config_file(self: Self, filepath: []const u8) MpvError!void {
    try catch_mpv_error(c.mpv_load_config_file(self.handle, filepath.ptr));
}

pub fn command(self: Self, args: []const []const u8) (AllocatorError || MpvError)!void {
    const c_args = try utils.create_cstring_array(args, self.allocator);
    defer utils.free_cstring_array(c_args, self.allocator);

    try catch_mpv_error(c.mpv_command(self.handle, c_args.ptr));
}

pub fn command_string(self: Self, args: []const u8) MpvError!void {
    try catch_mpv_error(c.mpv_command_string(self.handle, args.ptr));
}

/// The resulting MpvNode should be freed with `self.free(node)`
pub fn command_node(self: Self, args: MpvNode) (AllocatorError || MpvError)!MpvNode {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const c_node_ptr = try args.to_c(arena.allocator());

    var output: c.mpv_node = undefined;

    try catch_mpv_error(c.mpv_command_node(self.handle, c_node_ptr, &output));
    defer c.mpv_free_node_contents(&output);

    return try MpvNode.from(&output).copy(self.allocator);
}

/// The resulting MpvNode should be freed with `self.free(node)`
pub fn command_ret(self: Self, args: []const []const u8) (AllocatorError || MpvError)!MpvNode {
    const c_args = try utils.create_cstring_array(args, self.allocator);
    defer utils.free_cstring_array(c_args, self.allocator);

    var output: c.mpv_node = undefined;

    try catch_mpv_error(c.mpv_command_ret(self.handle, c_args.ptr, &output));
    defer c.mpv_free_node_contents(&output);

    return try MpvNode.from(&output).copy(self.allocator);
}

pub fn command_async(self: Self, reply_userdata: u64, args: []const []const u8) (AllocatorError || MpvError)!void {
    const c_args = try utils.create_cstring_array(args, self.allocator);
    defer utils.free_cstring_array(c_args, self.allocator);

    try catch_mpv_error(c.mpv_command_async(self.handle, reply_userdata, c_args.ptr));
}

pub fn command_node_async(self: Self, reply_userdata: u64, args: MpvNode) (AllocatorError || MpvError)!void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const c_node_ptr = try args.to_c(arena.allocator());

    try catch_mpv_error(c.mpv_command_node_async(self.handle, reply_userdata, c_node_ptr));
}

pub fn abort_async_command(self: Self, reply_userdata: u64) void {
    c.mpv_abort_async_command(self.handle, reply_userdata);
}

/// The returened value must be freed with self.free(value)
pub fn get_property(self: Self, name: []const u8, format: MpvFormat) (AllocatorError || MpvError)!MpvPropertyData {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const data_ptr = try format.alloc_c_value(arena.allocator());

    try catch_mpv_error(c.mpv_get_property(self.handle, name.ptr, format.to_c(), data_ptr));

    return try MpvPropertyData.from(format, data_ptr).copy(self.allocator);
}

/// The returened value must be freed with self.free(value)
pub fn get_property_string(self: Self, name: []const u8) (AllocatorError || GenericError)![]u8 {
    const returned_value = c.mpv_get_property_string(self.handle, name.ptr);
    if (returned_value == null) {
        return GenericError.NullValue;
    }
    defer c.mpv_free(returned_value);

    return try self.allocator.dupe(u8, std.mem.sliceTo(returned_value, 0));
}

/// The returened value must be freed with self.free(value)
pub fn get_property_osd_string(self: Self, name: []const u8) (AllocatorError || GenericError)![]u8 {
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

pub fn set_property(self: Self, name: []const u8, value: MpvPropertyData) (AllocatorError || MpvError)!void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const data_ptr = try value.to_c(arena.allocator());

    try catch_mpv_error(c.mpv_set_property(self.handle, name.ptr, std.meta.activeTag(value).to_c(), data_ptr));
}

pub fn set_property_string(self: Self, name: []const u8, value: []const u8) MpvError!void {
    try catch_mpv_error(c.mpv_set_property_string(self.handle, name.ptr, value.ptr));
}

pub fn set_property_async(self: Self, reply_userdata: u64, name: []const u8, value: MpvPropertyData) (AllocatorError || MpvError)!void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const data_ptr = try value.to_c(arena.allocator());

    try catch_mpv_error(c.mpv_set_property_async(self.handle, reply_userdata, name.ptr, std.meta.activeTag(value).to_c(), data_ptr));
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

pub fn hook_add(self: Self, reply_userdata: u64, name: []const u8, priority: i32) MpvError!void {
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

pub inline fn set_wakeup_callback(self: Self, callback: *const fn (?*anyopaque) void, data: ?*anyopaque) void {
    const c_wrapper = struct {
        pub fn cb(ctx: ?*anyopaque) callconv(.C) void {
            @call(.always_inline, callback, .{ctx});
        }
    }.cb;

    c.mpv_set_wakeup_callback(self.handle, c_wrapper, data);
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
}

pub usingnamespace @import("mpv_helper.zig");
pub usingnamespace @import("stream_cb.zig");

const test_filepath = "resources/sample.mp4";

test "Mpv simple test" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();
}

test "Mpv memory leak" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    try mpv.command(&.{ "loadfile", test_filepath });

    while (true) {
        const event = mpv.wait_event(10000);
        switch (event.event_id) {
            .Shutdown => break,
            .PlaybackRestart => break,
            else => {},
        }
    }
}

test "Mpv.create_client" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    const name = "simple_client";
    const client = try mpv.create_client(.{ .name = name });
    defer client.destroy();
    try testing.expectEqualStrings(name, client.client_name());
}

test "Mpv.create_weak_client" {
    const mpv = try Self.create(testing.allocator);
    try mpv.initialize();
    defer mpv.terminate_destroy();

    const client = try mpv.create_weak_client(.{});
    defer client.destroy();
}

test "Mpv.set_option" {
    const mpv = try Self.create(testing.allocator);
    try mpv.set_option("osc", .{ .Flag = true });
    try mpv.initialize();
    defer mpv.terminate_destroy();

    const format = MpvFormat.Flag;
    const osc = try mpv.get_property("osc", format);
    defer mpv.free(osc);

    try testing.expect(osc.Flag == true);
}

test "Mpv.set_option_string" {
    const mpv = try Self.create(testing.allocator);
    try mpv.set_option_string("title", "zmpv");
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

    try mpv.command(&.{ "loadfile", test_filepath });

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

    try mpv.command(&.{ "loadfile", test_filepath });

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

    try mpv.command_async(0, &.{ "loadfile", test_filepath });

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

    var args = [_]MpvNode{ .{ .String = "loadfile" }, .{ .String = test_filepath } };
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

    try mpv.command(&.{ "loadfile", test_filepath });

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
                try testing.expectEqualStrings(test_filepath, filename.?.String);
                const filename_pair = map_iter.next().?;
                try testing.expect(std.mem.eql(u8, filename_pair[0], "filename"));
                try testing.expect(std.mem.eql(u8, filename_pair[1].String, test_filepath));
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
