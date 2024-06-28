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

pub fn create_with_threading(allocator: std.mem.Allocator) !*Mpv {
    const instance_ptr = try Mpv.create(allocator);
    instance_ptr.threading_info = try MpvThreadingInfo.new(instance_ptr);
    return instance_ptr;
}

pub const MpvThreadingInfo = struct {
    allocator: std.mem.Allocator,
    event_handle: *Mpv,
    event_callbacks: std.ArrayList(MpvEventCallback),
    property_callbacks: std.StringHashMap(*std.ArrayList(MpvPropertyCallback)),
    command_reply_callbacks: std.AutoHashMap(u64, MpvCommandReplyCallback),
    log_callback: ?MpvLogMessageCallback = null,
    event_thread: std.Thread,
    mutex: std.Thread.Mutex = std.Thread.Mutex{},
    thread_event: ?*ResetEvent = null,

    pub fn new(mpv: *Mpv) !*MpvThreadingInfo {
        const allocator = mpv.allocator;

        var event_thread = try std.Thread.spawn(.{}, event_loop, .{ mpv });
        event_thread.detach();

        const event_handle_ptr = try mpv.create_client("MpvThreadHandle");

        const info_ptr = try allocator.create(@This());
        info_ptr.* = MpvThreadingInfo{
            .allocator = allocator,
            .event_handle = event_handle_ptr,
            .event_thread = event_thread,
            .event_callbacks = std.ArrayList(MpvEventCallback).init(allocator),
            .property_callbacks = std.StringHashMap(*std.ArrayList(MpvPropertyCallback)).init(allocator),
            .command_reply_callbacks = std.AutoHashMap(u64, MpvCommandReplyCallback).init(allocator),
        };
        return info_ptr;
    }

    pub fn free(self: *MpvThreadingInfo) void {
        const allocator = self.allocator;

        self.event_callbacks.deinit();

        var properties_cbs_iterator = self.property_callbacks.valueIterator();
        while (properties_cbs_iterator.next()) |cbs| {
            cbs.*.deinit();
            allocator.destroy(cbs.*);
        }
        self.property_callbacks.deinit();

        self.command_reply_callbacks.deinit();

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

    var thread_info = mpv.threading_info.?;
    var iter = event_iterator(thread_info.event_handle.*);
    while (iter.next()) |event| {
        const eid = event.event_id;
        if (eid == .Shutdown) {
            if (thread_info.mutex.tryLock()) {
                mpv.core_shutdown = true;
                thread_info.mutex.unlock();
            }
        }

        if (thread_info.mutex.tryLock()) {
            for (thread_info.event_callbacks.items) |cb| {
                cb.call(event);
            }
            thread_info.mutex.unlock();
        }

        if (eid == .PropertyChange) {
            const property = event.data.PropertyChange;
            if (thread_info.mutex.tryLock()) {
                if (thread_info.property_callbacks.get(property.name)) |cbs| {
                    for (cbs.items) |cb| {
                        cb.call(property);
                    }
                }
                thread_info.mutex.unlock();
            }
        }

        if (eid == .LogMessage) {
            if (thread_info.mutex.tryLock()) {
                if (thread_info.log_callback) |cb| {
                    cb.call(event.data.LogMessage);
                }
                thread_info.mutex.unlock();
            }
        }

        if (eid == .CommandReply) {
            const key = event.reply_userdata;
            const cmd_error = event.event_error;
            const result = event.data.CommandReply.result;
            if (thread_info.mutex.tryLock()) {
                if (thread_info.command_reply_callbacks.get(key)) |cb| {
                    cb.call(cmd_error, result);
                }
                thread_info.mutex.unlock();
            }
        }

        if (eid == .Shutdown) {
            thread_info.event_handle.destroy();
            if (thread_info.thread_event) |te| {
                te.set();
            }
            thread_info.free();
            break;
        }
    }
}

pub fn register_event_callback(mpv: *Mpv, callback: MpvEventCallback) !MpvEventCallbackUnregisterrer {
    std.debug.assert(mpv.threading_info != null);
    try mpv.check_core_shutdown();

    var thread_info = mpv.threading_info.?;
    thread_info.mutex.lock();
    try thread_info.event_callbacks.append(callback);
    thread_info.mutex.unlock();

    const unregisterrer = MpvEventCallbackUnregisterrer {
        .mpv = mpv,
        .data = callback,
        .unregisterrer_func = struct {
            pub fn cb(inner_mpv: *Mpv, inner_cb: MpvEventCallback) void {
                inner_mpv.unregister_event_callback(inner_cb) catch {};
            }
        }.cb,
    };
    return unregisterrer;
}

pub fn unregister_event_callback(mpv: *Mpv, callback: MpvEventCallback) !void {
    std.debug.assert(mpv.threading_info != null);
    var thread_info = mpv.threading_info.?;

    for (0.., thread_info.event_callbacks.items) |idx, cb| {
        if (std.meta.eql(cb, callback)) {
            _ = thread_info.event_callbacks.swapRemove(idx);
        }
    }
}

pub fn register_property_callback(mpv: *Mpv, callback: MpvPropertyCallback) !MpvPropertyCallbackUnregisterrer {
    std.debug.assert(mpv.threading_info != null);
    try mpv.check_core_shutdown();

    var thread_info = mpv.threading_info.?;

    const property_name = callback.property_name;
    if (!thread_info.property_callbacks.contains(property_name)) {
        const allocator = mpv.allocator;
        const list_ptr = try allocator.create(std.ArrayList(MpvPropertyCallback));
        list_ptr.* = std.ArrayList(MpvPropertyCallback).init(allocator);
        try thread_info.property_callbacks.put(property_name, list_ptr);
    }
    var property_observers = thread_info.property_callbacks.get(property_name).?;
    try property_observers.append(callback);
    try thread_info.event_handle.observe_property(utils.hash(property_name), property_name, .Node);

    const unregisterrer = MpvPropertyCallbackUnregisterrer {
        .mpv = mpv,
        .data = callback,
        .unregisterrer_func = struct {
            pub fn cb(inner_mpv: *Mpv, inner_callback: MpvPropertyCallback) void {
                inner_mpv.unregister_property_callback(inner_callback) catch {};
            }
        }.cb,
    };
    return unregisterrer;
}

pub fn unregister_property_callback(mpv: *Mpv, callback: MpvPropertyCallback) !void {
    std.debug.assert(mpv.threading_info != null);
    var thread_info = mpv.threading_info.?;
    if (thread_info.property_callbacks.get(callback.property_name)) |cbs| {
        for (0.., cbs.items) |idx, cb| {
            if (std.meta.eql(cb, callback)) {
                _ = cbs.swapRemove(idx);
            }
        }
    }
}

pub fn register_command_reply_callback(mpv: *Mpv, callback: MpvCommandReplyCallback) !MpvCommandReplyCallbackUnegisterrer {
    std.debug.assert(mpv.threading_info != null);

    var thread_info = mpv.threading_info.?;
    const args_hash = try utils.string_array_hash(mpv.allocator, callback.command_args);
    try thread_info.command_reply_callbacks.put(args_hash, callback);
    try thread_info.event_handle.command_async(args_hash, callback.command_args);

    const unregisterrer = MpvCommandReplyCallbackUnegisterrer {
        .mpv = mpv,
        .data = callback,
        .unregisterrer_func = struct {
            pub fn cb(inner_mpv: *Mpv, inner_callback: MpvCommandReplyCallback) void {
                inner_mpv.unregister_command_reply_callback(inner_callback) catch {};
            }
        }.cb,
    };
    return unregisterrer;
}

pub fn unregister_command_reply_callback(mpv: *Mpv, callback: MpvCommandReplyCallback) !void {
    std.debug.assert(mpv.threading_info != null);

    var thread_info = mpv.threading_info.?;
    const args_hash = try utils.string_array_hash(mpv.allocator, callback.command_args);
    thread_info.event_handle.abort_async_command(args_hash);
    _ = thread_info.command_reply_callbacks.remove(args_hash);
}

pub fn register_log_message_handler(mpv: *Mpv, callback: MpvLogMessageCallback) !MpvLogMessageCallbackUnregisterrer {
    std.debug.assert(mpv.threading_info != null);

    var thread_info = mpv.threading_info.?;
    try thread_info.event_handle.request_log_messages(callback.level);
    thread_info.log_callback = callback;

    const unregisterrer = MpvLogMessageCallbackUnregisterrer {
        .mpv = mpv,
        .data = {},
        .unregisterrer_func = struct {
            pub fn cb(inner_mpv: *Mpv, _: void) void {
                inner_mpv.unregister_log_message_handler() catch {};
            }
        }.cb,
    };
    return unregisterrer;
}

pub fn unregister_log_message_handler(mpv: *Mpv) !void {
    std.debug.assert(mpv.threading_info != null);

    var thread_info = mpv.threading_info.?;
    try mpv.request_log_messages(.None);
    thread_info.log_callback = null;
}

pub fn wait_for_event(mpv: *Mpv, event_ids: []const MpvEventId, args: struct {
    cond_cb: ?*const fn (MpvEvent) bool = null,
    timeout: ?u32 = null,
}) !MpvEvent {
    std.debug.assert(mpv.threading_info != null);
    try mpv.check_core_shutdown();
    const cb = struct {
        pub fn cb(event: MpvEvent, user_data: ?*anyopaque) void {
            const data_struct = struct {*ResetEvent,*?MpvEvent};
            const data_ptr: *data_struct = @ptrCast(@alignCast(user_data.?));
            var received_event: *ResetEvent = data_ptr.*[0];
            const event_ptr: *?MpvEvent = data_ptr.*[1];

            event_ptr.* = event;
            received_event.set();
        }
    }.cb;

    const data_struct = struct {*ResetEvent, *?MpvEvent};
    const sent_data_ptr = try mpv.allocator.create(data_struct);
    const event_ptr = try mpv.allocator.create(?MpvEvent);
    event_ptr.* = null;
    var received_event = ResetEvent{};
    sent_data_ptr.* = data_struct{&received_event, event_ptr};
    defer {
        mpv.allocator.destroy(event_ptr);
        mpv.allocator.destroy(sent_data_ptr);
    }

    const unregisterrer = try mpv.register_event_callback(MpvEventCallback{
        .event_ids = event_ids,
        .callback = &cb,
        .user_data = @ptrCast(sent_data_ptr),
        .cond_cb = args.cond_cb,
    });
    defer unregisterrer.unregister();

    mpv.threading_info.?.thread_event = &received_event;
    defer {
        if (event_ptr.*) |ev| {
            if (ev.event_id != .Shutdown) {
                mpv.threading_info.?.thread_event = null;
            }
        }
    }

    if (args.timeout) |timeout| {
        try received_event.timedWait(@as(u64, timeout*@as(u64, 1e9)));
    } else {
        received_event.wait();
    }

    if (event_ptr.*) |ev| {
        return ev;
    }
    else {
        return GenericError.NullValue;
    }

}

pub fn wait_for_property(mpv: *Mpv, property_name: []const u8, args: struct {
    cond_cb: ?*const fn (MpvEventProperty) bool = null,
    timeout: ?u32 = null,
}) !MpvEventProperty {
    std.debug.assert(mpv.threading_info != null);
    try mpv.check_core_shutdown();
    const cb = struct {
        pub fn cb(event: MpvEventProperty, user_data: ?*anyopaque) void {
            const data_struct = struct {*ResetEvent, *?MpvEventProperty};
            const data_ptr: *data_struct = @ptrCast(@alignCast(user_data.?));
            var received_event: *ResetEvent = data_ptr.*[0];
            const property_data_ptr: *?MpvEventProperty = data_ptr.*[1];

            property_data_ptr.* = event;
            received_event.set();
        }
    }.cb;

    const data_struct = struct {*ResetEvent, *?MpvEventProperty};
    const sent_data_ptr = try mpv.allocator.create(data_struct);
    const property_data_ptr = try mpv.allocator.create(?MpvEventProperty);
    property_data_ptr.* = null;
    var received_event = ResetEvent{};
    sent_data_ptr.* = data_struct{&received_event, property_data_ptr};
    defer {
        mpv.allocator.destroy(property_data_ptr);
        mpv.allocator.destroy(sent_data_ptr);
    }

    const unregisterrer = try mpv.register_property_callback(MpvPropertyCallback{
        .property_name = property_name,
        .callback = &cb,
        .user_data = @ptrCast(sent_data_ptr),
        .cond_cb = args.cond_cb,
    });
    defer unregisterrer.unregister();

    mpv.threading_info.?.thread_event = &received_event;
    defer mpv.threading_info.?.thread_event = null;

    if (args.timeout) |timeout| {
        try received_event.timedWait(@as(u64, timeout*@as(u64, 1e9)));
    } else {
        received_event.wait();
    }

    if (property_data_ptr.*) |pd| {
        return pd;
    }
    else {
        return GenericError.NullValue;
    }
}

pub fn wait_until_playing(mpv: *Mpv, args: struct {
    timeout: ?u32 = null,
}) !MpvEventProperty {
    return try mpv.wait_for_property("core-idle", .{ .timeout = args.timeout,
    .cond_cb = struct {
        pub fn cb(event: MpvEventProperty) bool {
            return (!event.data.Node.Flag);
        }
    }.cb});
}

pub fn wait_until_paused(mpv: *Mpv, args: struct {
    timeout: ?u32 = null,
}) !MpvEventProperty {
    return try mpv.wait_for_property("core-idle", .{ .timeout = args.timeout,
    .cond_cb = struct {
        pub fn cb(event: MpvEventProperty) bool {
            return (event.data.Node.Flag);
        }
    }.cb});
}

pub fn wait_for_playback(mpv: *Mpv, args: struct {
    timeout: ?u32 = null,
}) !MpvEvent {
    return try mpv.wait_for_event(&.{.EndFile}, .{ .timeout = args.timeout });
}

pub fn wait_for_shutdown(mpv: *Mpv, args: struct {
    timeout: ?u32 = null,
}) !MpvEvent {
    return try mpv.wait_for_event(&.{.Shutdown}, .{ .timeout = args.timeout });
}