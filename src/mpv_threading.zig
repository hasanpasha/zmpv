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
const GenericError = @import("./generic_error.zig").GenericError;
const MpvError = @import("./mpv_error.zig").MpvError;
const utils = @import("./utils.zig");
const ResetEvent = std.Thread.ResetEvent;
const testing = std.testing;

pub fn create_with_threading(allocator: std.mem.Allocator) !*Mpv {
    const instance_ptr = try Mpv.create(allocator);
    instance_ptr.threading_info = try MpvThreadingInfo.new(instance_ptr);
    return instance_ptr;
}

pub const Future = struct {
    value: ?*anyopaque = null,
    error_value: anyerror = error.Success,
    reset_event: *ResetEvent,
    arena: std.heap.ArenaAllocator,

    const FutureError = error {
        Canceled,
    };

    pub fn new(allocator: std.mem.Allocator) !*@This() {
        var arena = std.heap.ArenaAllocator.init(allocator);

        const this = try arena.allocator().create(@This());
        var reset_event = ResetEvent{};
        this.* = .{
            .reset_event = &reset_event,
            .arena = arena,
        };
        return this;
    }

    pub fn free(self: *@This()) void {
        self.arena.deinit();
    }

    pub fn wait_result(self: @This(), timeout: ?u64) !*anyopaque {
        if (timeout) |t| {
            try self.reset_event.timedWait(t);
        } else {
            self.reset_event.wait();
        }

        return self.value orelse self.error_value;
    }

    fn set(self: @This()) void {
        if (!self.reset_event.isSet()) {
            self.reset_event.set();
        }
    }

    pub fn set_result(self: *@This(), value: anytype) !void {
        var arena = self.arena;
        const value_ptr = try arena.allocator().create(@TypeOf(value));
        value_ptr.* = value;

        self.value = value_ptr;
        self.set();
    }

    pub fn set_error(self: *@This(), error_value: anyerror) void {
        self.error_value = error_value;
        self.set();
    }

    pub fn cancel(self: *@This()) void {
        self.set_error(FutureError.Canceled);
    }
};

pub const MpvThreadingInfo = struct {
    allocator: std.mem.Allocator,
    event_handle: *Mpv,
    event_callbacks: std.ArrayList(MpvEventCallback),
    property_callbacks: std.StringHashMap(*std.ArrayList(MpvPropertyCallback)),
    command_reply_callbacks: std.AutoHashMap(u64, MpvCommandReplyCallback),
    log_callback: ?MpvLogMessageCallback = null,
    event_thread: std.Thread,
    mutex: std.Thread.Mutex = std.Thread.Mutex{},
    // thread_event: ResetEvent,
    futures: std.ArrayList(*Future),

    pub fn new(mpv: *Mpv) !*MpvThreadingInfo {
        const allocator = mpv.allocator;

        var event_thread = try std.Thread.spawn(.{}, event_loop, .{mpv});
        event_thread.detach();

        // var reset_event = ResetEvent{};

        const info_ptr = try allocator.create(@This());
        info_ptr.* = MpvThreadingInfo{
            .allocator = allocator,
            .event_handle = try mpv.create_client("MpvThreadHandle"),
            .event_thread = event_thread,
            .event_callbacks = std.ArrayList(MpvEventCallback).init(allocator),
            .property_callbacks = std.StringHashMap(*std.ArrayList(MpvPropertyCallback)).init(allocator),
            .command_reply_callbacks = std.AutoHashMap(u64, MpvCommandReplyCallback).init(allocator),
            .futures = std.ArrayList(*Future).init(allocator),
            // .thread_event = reset_event,
            // .thread_event = ResetEvent{},
        };
        return info_ptr;
    }

    pub fn free(self: *MpvThreadingInfo) void {
        const allocator = self.allocator;
        var mutux = self.mutex;

        mutux.lock();
        defer mutux.unlock();

        // allocator.destroy(self.thread_event);

        self.event_callbacks.deinit();

        var properties_cbs_iterator = self.property_callbacks.valueIterator();
        while (properties_cbs_iterator.next()) |cbs| {
            cbs.*.deinit();
            allocator.destroy(cbs.*);
        }
        self.property_callbacks.deinit();

        self.command_reply_callbacks.deinit();

        self.event_handle.destroy();

        allocator.destroy(self);
    }
};

pub const MpvEventCallback = struct {
    event_ids: []const MpvEventId,
    callback: *const fn (MpvEvent, ?*anyopaque) void,
    user_data: ?*anyopaque = null,
    cond_cb: ?*const fn (MpvEvent) bool = null,

    pub fn call(self: MpvEventCallback, event: MpvEvent) void {
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

    pub fn call(self: MpvPropertyCallback, property_event: MpvEventProperty) void {
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
        mpv: *Mpv,
        data: T,
        unregisterrer_func: *const fn (*Mpv, T) void,

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

pub fn event_loop(mpv: *Mpv) !void {
    // wait until MpvThreadingInfo is constructed and assigned to Mpv.threading_info
    while (mpv.threading_info == null) {}

    var threading_info = mpv.threading_info.?;
    defer {
        threading_info.free();
        mpv.threading_info = null;
    }
    var iter = event_iterator(threading_info.event_handle.*);
    while (iter.next()) |event| {
        const eid = event.event_id;
        if (eid == .Shutdown) {
            if (threading_info.mutex.tryLock()) {
                mpv.core_shutdown = true;
                threading_info.mutex.unlock();
            }
        }

        if (threading_info.mutex.tryLock()) {
            for (threading_info.event_callbacks.items) |cb| {
                cb.call(event);
            }
            threading_info.mutex.unlock();
        }

        switch (event.data) {
            .PropertyChange, .GetPropertyReply => |property| {
                // if (threading_info.mutex.tryLock()) {
                threading_info.mutex.lock();
                defer threading_info.mutex.unlock();
                if (threading_info.property_callbacks.get(property.name)) |cbs| {
                    for (cbs.items) |cb| {
                        cb.call(property);
                    }
                }
                // }
            },
            .LogMessage => |log| {
                threading_info.mutex.lock();
                defer threading_info.mutex.unlock();
                // if (threading_info.mutex.tryLock()) {
                if (threading_info.log_callback) |cb| {
                    cb.call(log);
                }
                // threading_info.mutex.unlock();
                // }
            },
            .CommandReply => |reply| {
                const key = event.reply_userdata;
                const cmd_error = event.event_error;
                const result = reply.result;
                threading_info.mutex.lock();
                defer threading_info.mutex.unlock();
                // if (threading_info.mutex.tryLock()) {
                if (threading_info.command_reply_callbacks.get(key)) |cb| {
                    cb.call(cmd_error, result);
                }
                // threading_info.mutex.unlock();
                // }
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
pub fn register_event_callback(mpv: *Mpv, callback: MpvEventCallback) !MpvEventCallbackUnregisterrer {
    std.debug.assert(mpv.threading_info != null);
    try mpv.check_core_shutdown();

    var threading_info = mpv.threading_info.?;
    {
        threading_info.mutex.lock();
        defer threading_info.mutex.unlock();
        try threading_info.event_callbacks.append(callback);
    }

    return .{
        .mpv = mpv,
        .data = callback,
        .unregisterrer_func = struct {
            pub fn cb(inner_mpv: *Mpv, inner_cb: MpvEventCallback) void {
                inner_mpv.unregister_event_callback(inner_cb) catch {};
            }
        }.cb,
    };
}

/// Unregister event callback.
pub fn unregister_event_callback(mpv: *Mpv, callback: MpvEventCallback) !void {
    std.debug.assert(mpv.threading_info != null);
    var threading_info = mpv.threading_info.?;

    threading_info.mutex.lock();
    defer threading_info.mutex.unlock();
    for (0.., threading_info.event_callbacks.items) |idx, cb| {
        if (std.meta.eql(cb, callback)) {
            _ = threading_info.event_callbacks.swapRemove(idx);
        }
    }
}

/// Register a callback that will be called on the specified property event occurance.
pub fn register_property_callback(mpv: *Mpv, callback: MpvPropertyCallback) !MpvPropertyCallbackUnregisterrer {
    std.debug.assert(mpv.threading_info != null);
    try mpv.check_core_shutdown();

    var threading_info = mpv.threading_info.?;
    const property_name = callback.property_name;
    const allocator = mpv.allocator;
    {
        threading_info.mutex.lock();
        defer threading_info.mutex.unlock();
        if (!threading_info.property_callbacks.contains(property_name)) {
            const list_ptr = try allocator.create(std.ArrayList(MpvPropertyCallback));
            list_ptr.* = std.ArrayList(MpvPropertyCallback).init(allocator);
            try threading_info.property_callbacks.put(property_name, list_ptr);
        }
        var property_observers = threading_info.property_callbacks.get(property_name).?;
        try property_observers.append(callback);
    }
    try threading_info.event_handle.observe_property(std.hash.Fnv1a_64.hash(property_name), property_name, .Node);

    return .{
        .mpv = mpv,
        .data = callback,
        .unregisterrer_func = struct {
            pub fn cb(inner_mpv: *Mpv, inner_callback: MpvPropertyCallback) void {
                inner_mpv.unregister_property_callback(inner_callback) catch |err| {
                    std.log.err("error while unregisterring event callback: {}", .{err});
                };
            }
        }.cb,
    };
}

/// Unregister property callback.
pub fn unregister_property_callback(mpv: *Mpv, callback: MpvPropertyCallback) !void {
    std.debug.assert(mpv.threading_info != null);
    var threading_info = mpv.threading_info.?;

    threading_info.mutex.lock();
    defer threading_info.mutex.unlock();
    if (threading_info.property_callbacks.get(callback.property_name)) |cbs| {
        for (0.., cbs.items) |idx, cb| {
            if (std.meta.eql(cb, callback)) {
                _ = cbs.swapRemove(idx);
            }

            if (cbs.items.len == 0) {
                try threading_info.event_handle.unobserve_property(std.hash.Fnv1a_64.hash(callback.property_name));
            }
        }
    }
}

/// Register a callback that will be called when the async command is finished.
pub fn register_command_reply_callback(mpv: *Mpv, callback: MpvCommandReplyCallback) !MpvCommandReplyCallbackUnegisterrer {
    std.debug.assert(mpv.threading_info != null);

    var threading_info = mpv.threading_info.?;
    const args_hash = try utils.string_array_hash(mpv.allocator, callback.command_args);
    {
        threading_info.mutex.lock();
        defer threading_info.mutex.unlock();
        try threading_info.command_reply_callbacks.put(args_hash, callback);
    }
    try threading_info.event_handle.command_async(args_hash, callback.command_args);

    return .{
        .mpv = mpv,
        .data = callback,
        .unregisterrer_func = struct {
            pub fn cb(inner_mpv: *Mpv, inner_callback: MpvCommandReplyCallback) void {
                inner_mpv.unregister_command_reply_callback(inner_callback) catch |err| {
                    std.log.err("error while unregisterring property callback: {}", .{err});
                };
            }
        }.cb,
    };
}

/// Unregister the async command callback. and abort the command if it's still not done.
pub fn unregister_command_reply_callback(mpv: *Mpv, callback: MpvCommandReplyCallback) !void {
    std.debug.assert(mpv.threading_info != null);

    var threading_info = mpv.threading_info.?;
    const args_hash = try utils.string_array_hash(mpv.allocator, callback.command_args);
    threading_info.event_handle.abort_async_command(args_hash);
    {
        threading_info.mutex.lock();
        defer threading_info.mutex.unlock();
        _ = threading_info.command_reply_callbacks.remove(args_hash);
    }
}

/// Register a callback that all of Mpv log messages will be passed to. only one callback can be set.
pub fn register_log_message_handler(mpv: *Mpv, callback: MpvLogMessageCallback) !MpvLogMessageCallbackUnregisterrer {
    std.debug.assert(mpv.threading_info != null);

    var threading_info = mpv.threading_info.?;
    try threading_info.event_handle.request_log_messages(callback.level);
    {
        threading_info.mutex.lock();
        defer threading_info.mutex.unlock();
        threading_info.log_callback = callback;
    }

    return .{
        .mpv = mpv,
        .data = {},
        .unregisterrer_func = struct {
            pub fn cb(inner_mpv: *Mpv, _: void) void {
                inner_mpv.unregister_log_message_handler() catch |err| {
                    std.log.err("error while unregistering log message handler: {}", .{err});
                };
            }
        }.cb,
    };
}

/// Unregister the current log message callback and set the log level to `.None`
pub fn unregister_log_message_handler(mpv: *Mpv) !void {
    std.debug.assert(mpv.threading_info != null);

    var threading_info = mpv.threading_info.?;
    try mpv.request_log_messages(.None);
    {
        threading_info.mutex.lock();
        defer threading_info.mutex.unlock();
        threading_info.log_callback = null;
    }
}

/// Wait for specified events, if `cond_cb` is specified then wait until cond_cb(event) is `true`.
/// returns `GenericError.CoreShutdown` when the core shutdowns befores reaching this wait, `Timeout`
/// error if timeout is specified, or `GenericError.NullValue` if the core shutdowns while waiting.
pub fn wait_for_event(mpv: *Mpv, event_ids: []const MpvEventId, args: struct {
    cond_cb: ?*const fn (MpvEvent) bool = null,
    timeout: ?u64 = null,
}) !MpvEvent {
    std.debug.assert(mpv.threading_info != null);
    try mpv.check_core_shutdown();
    const cb = struct {
        pub fn cb(event: MpvEvent, user_data: ?*anyopaque) void {
            var future: *Future = @ptrCast(@alignCast(user_data));
            future.set_result(event) catch |err| {
                future.set_error(err);
            };
        }
    }.cb;

    var future = try Future.new(mpv.allocator);
    defer future.free();

    const unregisterrer = try mpv.register_event_callback(MpvEventCallback{
        .event_ids = event_ids,
        .callback = &cb,
        .user_data = @ptrCast(future),
        .cond_cb = args.cond_cb,
    });
    defer {
        if (!mpv.core_shutdown) {
            unregisterrer.unregister();
        }
    }

    const result = try future.wait_result(args.timeout);
    const event_ptr: *MpvEvent = @ptrCast(@alignCast(result));
    return event_ptr.*;
}

/// Wait for specified property, if `cond_cb` is specified then wait until cond_cb(property_event) is `true`.
/// returns `GenericError.CoreShutdown` when the core shutdowns befores reaching this wait, `Timeout`
/// error if timeout is specified, or `GenericError.NullValue` if the core shutdowns while waiting.
pub fn wait_for_property(mpv: *Mpv, property_name: []const u8, args: struct {
    cond_cb: ?*const fn (MpvEventProperty) bool = null,
    timeout: ?u64 = null,
}) !MpvEventProperty {
    std.debug.assert(mpv.threading_info != null);
    try mpv.check_core_shutdown();
    const cb = struct {
        pub fn cb(event: MpvEventProperty, user_data: ?*anyopaque) void {
            var future: *Future = @ptrCast(@alignCast(user_data));
            future.set_result(event) catch |err| {
                future.set_error(err);
            };
        }
    }.cb;

    var future = try Future.new(mpv.allocator);
    defer future.free();

    const unregisterrer = try mpv.register_property_callback(MpvPropertyCallback{
        .property_name = property_name,
        .callback = &cb,
        .user_data = future,
        .cond_cb = args.cond_cb,
    });
    defer {
        if (!mpv.core_shutdown) {
            unregisterrer.unregister();
        }
    }

    const result = try future.wait_result(args.timeout);
    const property_event_ptr: *MpvEventProperty = @ptrCast(@alignCast(result));
    return property_event_ptr.*;
}

/// Wait until the playback has started
pub fn wait_until_playing(mpv: *Mpv, args: struct {
    timeout: ?u64 = null,
}) !MpvEventProperty {
    return try mpv.wait_for_property("core-idle", .{ .timeout = args.timeout, .cond_cb = struct {
        pub fn cb(event: MpvEventProperty) bool {
            return (!event.data.Node.Flag);
        }
    }.cb });
}

/// Wait until the current playback is paused or done
pub fn wait_until_paused(mpv: *Mpv, args: struct {
    timeout: ?u64 = null,
}) !MpvEventProperty {
    return try mpv.wait_for_property("core-idle", .{ .timeout = args.timeout, .cond_cb = struct {
        pub fn cb(event: MpvEventProperty) bool {
            return (event.data.Node.Flag);
        }
    }.cb });
}

// Wait until the current playback is finished
pub fn wait_for_playback(mpv: *Mpv, args: struct {
    timeout: ?u64 = null,
}) !MpvEvent {
    return try mpv.wait_for_event(&.{.EndFile}, .{ .timeout = args.timeout });
}

/// Wait until the core shutdown.
pub fn wait_for_shutdown(mpv: *Mpv, args: struct {
    timeout: ?u64 = null,
}) !MpvEvent {
    return try mpv.wait_for_event(&.{.Shutdown}, .{ .timeout = args.timeout });
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
