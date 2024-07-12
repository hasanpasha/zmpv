const std = @import("std");
const Mpv = @import("./Mpv.zig");
const MpvNode = @import("./mpv_node.zig").MpvNode;
const MpvEvent = @import("./MpvEvent.zig");
const MpvEventData = MpvEvent.MpvEventData;
const MpvEventId = @import("./mpv_event_id.zig").MpvEventId;
const MpvEventProperty = @import("./mpv_event_data_types/MpvEventProperty.zig");
const MpvEventLogMessage = @import("./mpv_event_data_types/MpvEventLogMessage.zig");
const MpvPropertyData = @import("./mpv_property_data.zig").MpvPropertyData;
const MpvLogLevel = @import("./mpv_event_data_types/MpvEventLogMessage.zig").MpvLogLevel;
const MpvError = @import("./mpv_error.zig").MpvError;
const utils = @import("./utils.zig");
const ResetEvent = std.Thread.ResetEvent;
const Future = @import("./Future.zig");
const testing = std.testing;

const Self = @This();

pub const MpvEventLoopError = error {
    CoreShutdown,
    LoopNotRunning,
};

mpv_event_handle: *Mpv,
event_callbacks: std.ArrayList(MpvEventCallback),
property_callbacks: std.StringHashMap(*std.ArrayList(MpvPropertyCallback)),
command_reply_callbacks: std.AutoHashMap(u64, MpvCommandReplyCallback),
log_callback: ?MpvLogMessageCallback = null,
mutex: std.Thread.Mutex = std.Thread.Mutex{},
futures: std.ArrayList(*Future),
core_shutdown: bool = false,
running: bool = false,
allocator: std.mem.Allocator,

pub fn new(mpv: *Mpv) !*Self {
    const allocator = mpv.allocator;

    const instance_ptr = try allocator.create(Self);
    instance_ptr.* = Self{
        .mpv_event_handle = try mpv.create_client("MpvThreadHandle"),
        .event_callbacks = std.ArrayList(MpvEventCallback).init(allocator),
        .property_callbacks = std.StringHashMap(*std.ArrayList(MpvPropertyCallback)).init(allocator),
        .command_reply_callbacks = std.AutoHashMap(u64, MpvCommandReplyCallback).init(allocator),
        .futures = std.ArrayList(*Future).init(allocator),
        .allocator = allocator,
    };
    return instance_ptr;
}

pub fn free(self: *Self) void {
    const allocator = self.allocator;
    var mutux = self.mutex;

    mutux.lock();
    defer mutux.unlock();

    self.event_callbacks.deinit();

    var properties_cbs_iterator = self.property_callbacks.valueIterator();
    while (properties_cbs_iterator.next()) |cbs| {
        cbs.*.deinit();
        allocator.destroy(cbs.*);
    }
    self.property_callbacks.deinit();

    self.command_reply_callbacks.deinit();

    self.mpv_event_handle.destroy();

    allocator.destroy(self);
}

pub fn check_core_shutdown(self: Self) MpvEventLoopError!void {
    if (self.core_shutdown) return MpvEventLoopError.CoreShutdown;
}

pub fn check_running(self: Self) MpvEventLoopError!void {
    if (!self.running) return MpvEventLoopError.LoopNotRunning;
}

pub const MpvEventCallback = struct {
    event_ids: []const MpvEventId,
    callback: *const fn (MpvEvent, ?*anyopaque) void,
    user_data: ?*anyopaque = null,
    cond_cb: ?*const fn (MpvEvent) bool = null,

    pub fn tryCall(self: MpvEventCallback, event: MpvEvent) void {
        const event_id = event.event_id;
        for (self.event_ids) |registerd_event_id| {
            if (registerd_event_id == event_id) {
                if (self.cond_cb) |cond| {
                    if (cond(event)) {
                        self.callback(event, self.user_data);
                    }
                } else {
                    self.callback(event, self.user_data);
                }
            }
        }
    }
};

pub const MpvPropertyCallback = struct {
    property_name: []const u8,
    callback: *const fn (MpvEventProperty, ?*anyopaque) void,
    user_data: ?*anyopaque = null,
    cond_cb: ?*const fn (MpvEventProperty) bool = null,

    pub fn tryCall(self: MpvPropertyCallback, property_event: MpvEventProperty) void {
        if (self.cond_cb) |cond| {
            if (cond(property_event)) {
                self.callback(property_event, self.user_data);
            }
        } else {
            self.callback(property_event, self.user_data);
        }
    }
};

pub const MpvCommandReplyCallback = struct {
    command_args: [][]const u8,
    callback: *const fn (MpvError, MpvNode, ?*anyopaque) void,
    user_data: ?*anyopaque = null,

    pub fn call(self: MpvCommandReplyCallback, cmd_error: MpvError, result: MpvNode) void {
        self.callback(cmd_error, result, self.user_data);
    }
};

pub const MpvLogMessageCallback = struct {
    level: MpvLogLevel,
    callback: *const fn (MpvLogLevel, []const u8, []const u8, ?*anyopaque) void,
    user_data: ?*anyopaque = null,

    pub fn call(self: MpvLogMessageCallback, log: MpvEventLogMessage) void {
        self.callback(log.log_level, log.prefix, log.text, self.user_data);
    }
};

pub fn MpvCallbackUnregisterrer(T: type) type {
    return struct {
        mpv: *Self,
        data: T,
        unregisterrer_func: *const fn (*Self, T) void,

        pub fn unregister(self: @This()) void {
            self.unregisterrer_func(self.mpv, self.data);
        }
    };
}

const MpvEventCallbackUnregisterrer = MpvCallbackUnregisterrer(MpvEventCallback);
const MpvPropertyCallbackUnregisterrer = MpvCallbackUnregisterrer(MpvPropertyCallback);
const MpvLogMessageCallbackUnregisterrer = MpvCallbackUnregisterrer(void);
const MpvCommandReplyCallbackUnegisterrer = MpvCallbackUnregisterrer(MpvCommandReplyCallback);

pub const EventIterator = struct {
    handle: Mpv,

    pub fn next(self: EventIterator) ?MpvEvent {
        const event = self.handle.wait_event(-1);
        if (event.event_id == .None) return null;
        return event;
    }
};

pub fn event_iterator(mpv: Mpv) EventIterator {
    return .{ .handle = mpv };
}

pub fn start(self: *Self, args: struct {
    start_new_thread: bool = false,
}) !void {
    if (args.start_new_thread) {
        var event_thread = try std.Thread.spawn(.{}, start_event_loop, .{self});
        event_thread.detach();
    } else {
        try self.start_event_loop();
    }
}

pub fn start_event_loop(self: *Self) !void {
    self.running = true;
    defer self.running = false;

    var iter = event_iterator(self.mpv_event_handle.*);
    while (iter.next()) |event| {
        const eid = event.event_id;
        if (eid == .Shutdown) {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.core_shutdown = true;
        }

        {
            self.mutex.lock();
            defer self.mutex.unlock();
            for (self.event_callbacks.items) |cb| {
                cb.tryCall(event);
            }
        }

        switch (event.data) {
            .PropertyChange, .GetPropertyReply => |property| {
                self.mutex.lock();
                defer self.mutex.unlock();
                if (self.property_callbacks.get(property.name)) |cbs| {
                    for (cbs.items) |cb| {
                        cb.call(property);
                    }
                }
                // }
            },
            .LogMessage => |log| {
                self.mutex.lock();
                defer self.mutex.unlock();
                if (self.log_callback) |cb| {
                    cb.call(log);
                }
            },
            .CommandReply => |reply| {
                const key = event.reply_userdata;
                const cmd_error = event.event_error;
                const result = reply.result;
                self.mutex.lock();
                defer self.mutex.unlock();
                // if (threading_info.mutex.tryLock()) {
                if (self.command_reply_callbacks.get(key)) |cb| {
                    cb.call(cmd_error, result);
                }
            },
            .ClientMessage => {}, // TODO: implement callback handler for client messages
            .Hook => {}, // TODO: same!
            else => {},
        }

        if (eid == .Shutdown) {
            // mpv.threading_info.?.thread_event.set();
            // if (!mpv.threading_info.?.thread_event.isSet()) {
            // }
            break;
        }
    }
}

/// Register a callback that will be called on the specified event occurance.
pub fn register_event_callback(self: *Self, callback: MpvEventCallback) !MpvEventCallbackUnregisterrer {
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.event_callbacks.append(callback);
    }

    return .{
        .mpv = self,
        .data = callback,
        .unregisterrer_func = struct {
            pub fn cb(mpv_event_loop: *Self, inner_cb: MpvEventCallback) void {
                mpv_event_loop.unregister_event_callback(inner_cb) catch {};
            }
        }.cb,
    };
}

/// Unregister event callback.
pub fn unregister_event_callback(self: *Self, callback: MpvEventCallback) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    for (0.., self.event_callbacks.items) |idx, cb| {
        if (std.meta.eql(cb, callback)) {
            _ = self.event_callbacks.swapRemove(idx);
        }
    }
}

/// Register a callback that will be called on the specified property event occurance.
pub fn register_property_callback(self: *Self, callback: MpvPropertyCallback) !MpvPropertyCallbackUnregisterrer {
    const property_name = callback.property_name;
    const allocator = self.allocator;
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (!self.property_callbacks.contains(property_name)) {
            const list_ptr = try allocator.create(std.ArrayList(MpvPropertyCallback));
            list_ptr.* = std.ArrayList(MpvPropertyCallback).init(allocator);
            try self.property_callbacks.put(property_name, list_ptr);
        }
        var property_observers = self.property_callbacks.get(property_name).?;
        try property_observers.append(callback);
    }
    try self.mpv_event_handle.observe_property(std.hash.Fnv1a_64.hash(property_name), property_name, .Node);

    return .{
        .mpv = self,
        .data = callback,
        .unregisterrer_func = struct {
            pub fn cb(mpv_event_loop: *Self, inner_callback: MpvPropertyCallback) void {
                mpv_event_loop.unregister_property_callback(inner_callback) catch |err| {
                    std.log.err("error while unregisterring event callback: {}", .{err});
                };
            }
        }.cb,
    };
}

/// Unregister property callback.
pub fn unregister_property_callback(self: *Self, callback: MpvPropertyCallback) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    if (self.property_callbacks.get(callback.property_name)) |cbs| {
        for (0.., cbs.items) |idx, cb| {
            if (std.meta.eql(cb, callback)) {
                _ = cbs.swapRemove(idx);
            }

            if (cbs.items.len == 0) {
                try self.mpv_event_handle.unobserve_property(std.hash.Fnv1a_64.hash(callback.property_name));
            }
        }
    }
}

/// Register a callback that will be called when the async command is finished.
pub fn register_command_reply_callback(self: *Self, callback: MpvCommandReplyCallback) !MpvCommandReplyCallbackUnegisterrer {
    const args_hash = try utils.string_array_hash(self.allocator, callback.command_args);
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.command_reply_callbacks.put(args_hash, callback);
    }
    try self.event_handle.command_async(args_hash, callback.command_args);

    return .{
        .mpv = self,
        .data = callback,
        .unregisterrer_func = struct {
            pub fn cb(mpv_event_loop: *Self, inner_callback: MpvCommandReplyCallback) void {
                mpv_event_loop.unregister_command_reply_callback(inner_callback) catch |err| {
                    std.log.err("error while unregisterring property callback: {}", .{err});
                };
            }
        }.cb,
    };
}

/// Unregister the async command callback. and abort the command if it's still not done.
pub fn unregister_command_reply_callback(self: *Self, callback: MpvCommandReplyCallback) !void {
    const args_hash = try utils.string_array_hash(self.allocator, callback.command_args);
    self.event_handle.abort_async_command(args_hash);
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        _ = self.command_reply_callbacks.remove(args_hash);
    }
}

/// Register a callback that all of Mpv log messages will be passed to. only one callback can be set.
pub fn register_log_message_handler(self: *Self, callback: MpvLogMessageCallback) !MpvLogMessageCallbackUnregisterrer {
    try self.mpv_event_handle.request_log_messages(callback.level);
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.log_callback = callback;
    }

    return .{
        .mpv = self,
        .data = {},
        .unregisterrer_func = struct {
            pub fn cb(mpv_event_loop: *Self, _: void) void {
                mpv_event_loop.unregister_log_message_handler() catch |err| {
                    std.log.err("error while unregistering log message handler: {}", .{err});
                };
            }
        }.cb,
    };
}

/// Unregister the current log message callback and set the log level to `.None`
pub fn unregister_log_message_handler(self: *Self) !void {
    try self.mpv_event_handle.request_log_messages(.None);
    {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.log_callback = null;
    }
}

/// Wait for specified events, if `cond_cb` is specified then wait until cond_cb(event) is `true`.
/// returns `MpvEventLoopError.CoreShutdown` when the core shutdowns befores reaching this wait, `Timeout`
/// error if timeout is specified, `GenericError.NullValue` if the core shutdowns while waiting, or
/// `MpvEventLoopError.LoopNotRunning` if this functions is called before starting the loop.
pub fn wait_for_event(self: *Self, event_ids: []const MpvEventId, args: struct {
    cond_cb: ?*const fn (MpvEvent) bool = null,
    timeout: ?u64 = null,
}) !MpvEvent {
    self.check_running();

    const cb = struct {
        pub fn cb(event: MpvEvent, user_data: ?*anyopaque) void {
            var future: *Future = @ptrCast(@alignCast(user_data));
            future.set_result(event) catch |err| {
                future.set_error(err);
            };
        }
    }.cb;

    var future = try Future.new(self.allocator);
    defer future.free();

    try self.check_core_shutdown();
    const unregisterrer = try self.register_event_callback(MpvEventCallback{
        .event_ids = event_ids,
        .callback = &cb,
        .user_data = @ptrCast(future),
        .cond_cb = args.cond_cb,
    });
    defer {
        if (!self.core_shutdown) {
            unregisterrer.unregister();
        }
    }

    const result = try future.wait_result(args.timeout);
    const event_ptr: *MpvEvent = @ptrCast(@alignCast(result));
    return event_ptr.*;
}

/// Wait for specified property, if `cond_cb` is specified then wait until cond_cb(property_event) is `true`.
/// returns `MpvEventLoopError.CoreShutdown` when the core shutdowns befores reaching this wait, `Timeout`
/// error if timeout is specified, `GenericError.NullValue` if the core shutdowns while waiting, or
/// `MpvEventLoopError.LoopNotRunning` if this functions is called before starting the loop.
pub fn wait_for_property(self: *Self, property_name: []const u8, args: struct {
    cond_cb: ?*const fn (MpvEventProperty) bool = null,
    timeout: ?u64 = null,
}) !MpvEventProperty {
    self.check_running();

    const cb = struct {
        pub fn cb(event: MpvEventProperty, user_data: ?*anyopaque) void {
            var future: *Future = @ptrCast(@alignCast(user_data));
            future.set_result(event) catch |err| {
                future.set_error(err);
            };
        }
    }.cb;

    var future = try Future.new(self.allocator);
    defer future.free();

    try self.check_core_shutdown();
    const unregisterrer = try self.register_property_callback(MpvPropertyCallback{
        .property_name = property_name,
        .callback = &cb,
        .user_data = future,
        .cond_cb = args.cond_cb,
    });
    defer {
        if (!self.core_shutdown) {
            unregisterrer.unregister();
        }
    }

    const result = try future.wait_result(args.timeout);
    const property_event_ptr: *MpvEventProperty = @ptrCast(@alignCast(result));
    return property_event_ptr.*;
}

/// Wait until the playback has started
pub fn wait_until_playing(self: *Self, args: struct {
    timeout: ?u64 = null,
}) !MpvEventProperty {
    return try self.wait_for_property("core-idle", .{ .timeout = args.timeout, .cond_cb = struct {
        pub fn cb(event: MpvEventProperty) bool {
            return (!event.data.Node.Flag);
        }
    }.cb });
}

/// Wait until the current playback is paused or done
pub fn wait_until_paused(self: *Self, args: struct {
    timeout: ?u64 = null,
}) !MpvEventProperty {
    return try self.wait_for_property("core-idle", .{ .timeout = args.timeout, .cond_cb = struct {
        pub fn cb(event: MpvEventProperty) bool {
            return (event.data.Node.Flag);
        }
    }.cb });
}

// Wait until the current playback is finished
pub fn wait_for_playback(self: *Self, args: struct {
    timeout: ?u64 = null,
}) !MpvEvent {
    return try self.wait_for_event(&.{.EndFile}, .{ .timeout = args.timeout });
}

/// Wait until the core shutdown.
pub fn wait_for_shutdown(self: *Self, args: struct {
    timeout: ?u64 = null,
}) !MpvEvent {
    return try self.wait_for_event(&.{.Shutdown}, .{ .timeout = args.timeout });
}

test "threaded: simple" {
    const allocator = testing.allocator;

    var mpv = try Mpv.new(allocator, .{
        .start_event_thread = true,
        .options = &.{},
    });
    defer mpv.terminate_destroy();

    try mpv.loadfile("sample.mp4", .{});

    _ = try std.Thread.spawn(.{}, struct {
        pub fn cb(player: *Mpv) void {
            std.time.sleep(1 * 1e9);
            player.command_string("quit") catch {};
        }
    }.cb, .{mpv});

    _ = try mpv.wait_for_shutdown(.{});
}

test "threaded: register_event" {
    const allocator = testing.allocator;

    var mpv = try Mpv.new(allocator, .{
        .start_event_thread = true,
        .options = &.{},
    });
    defer mpv.terminate_destroy();

    var callback_event = ResetEvent{};
    _ = try mpv.register_event_callback(MpvEventCallback{ .event_ids = &.{MpvEventId.FileLoaded}, .callback = struct {
        pub fn cb(event: MpvEvent, user_data: ?*anyopaque) void {
            _ = event;
            const called_ptr: *ResetEvent = @ptrCast(@alignCast(user_data));
            called_ptr.set();
        }
    }.cb, .user_data = @ptrCast(&callback_event) });
    try mpv.loadfile("sample.mp4", .{});
    try callback_event.timedWait(1 * 1e9);

    _ = try std.Thread.spawn(.{}, struct {
        pub fn cb(player: *Mpv) void {
            std.time.sleep(1 * 1e9);
            player.command_string("quit") catch {};
        }
    }.cb, .{mpv});

    _ = try mpv.wait_for_shutdown(.{});
}
