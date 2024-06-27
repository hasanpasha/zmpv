const std = @import("std");
const Mpv = @import("./Mpv.zig");
const MpvLogLevel = @import("./mpv_event_data_types/MpvEventLogMessage.zig").MpvLogLevel;
const MpvNode = @import("./mpv_node.zig").MpvNode;
const MpvEvent = @import("./MpvEvent.zig");
const MpvEventProperty = @import("./mpv_event_data_types/MpvEventProperty.zig");
const MpvEventLogMessage = @import("./mpv_event_data_types/MpvEventLogMessage.zig");
const MpvPropertyData = @import("./mpv_property_data.zig").MpvPropertyData;
const MpvEventId = @import("./mpv_event_id.zig").MpvEventId;
const GenericError = @import("./generic_error.zig").GenericError;
const MpvError = @import("./mpv_error.zig").MpvError;
const utils = @import("./utils.zig");

pub const MpvThreadedInfo = struct {
    event_handle: *Mpv,
    event_callbacks: std.ArrayList(MpvEventCallback),
    property_callbacks: std.StringHashMap(*std.ArrayList(MpvPropertyCallback)),
    command_reply_callbacks: std.AutoHashMap(u64, MpvCommandReplyCallback),
    log_callback: ?MpvLogMessageCallback = null,
    event_thread: std.Thread,
    mutex: std.Thread.Mutex = std.Thread.Mutex{},
    core_shutdown: bool = false,
    // callback_events: std.ArrayList(*std.Thread.ResetEvent),

    pub fn new(mpv: *Mpv) !*MpvThreadedInfo {
        const allocator = mpv.allocator;

        var event_thread = try std.Thread.spawn(.{}, event_loop, .{ mpv });
        event_thread.detach();

        const event_handle_ptr = try allocator.create(Mpv);
        event_handle_ptr.* = try mpv.create_client("MpvThreadHandle");

        const info_ptr = try allocator.create(@This());
        info_ptr.* = MpvThreadedInfo{
            .event_handle = event_handle_ptr,
            .event_thread = event_thread,
            .event_callbacks = std.ArrayList(MpvEventCallback).init(allocator),
            .property_callbacks = std.StringHashMap(*std.ArrayList(MpvPropertyCallback)).init(allocator),
            .command_reply_callbacks = std.AutoHashMap(u64, MpvCommandReplyCallback).init(allocator),
            // .callback_events = std.ArrayList(*std.Thread.ResetEvent).init(allocator),
        };
        return info_ptr;
    }
};

pub const MpvEventCallback = struct {
    event_ids: []const MpvEventId,
    callback: *const fn (?*anyopaque, MpvEvent) void,
    callback_cond: ?*const fn (MpvEvent) bool = null,
    user_data: ?*anyopaque = null,

    pub fn call(self: MpvEventCallback, event: MpvEvent) void {
        const event_id = event.event_id;
        for (self.event_ids) |registerd_event_id| {
            if (registerd_event_id == event_id) {
                if (self.callback_cond) |cond| {
                    if (cond(event)) {
                        self.callback(self.user_data, event);
                    }
                } else {
                    self.callback(self.user_data, event);
                }
            }
        }
    }
};

pub const MpvPropertyCallback = struct {
    property_name: []const u8,
    callback: *const fn (?*anyopaque, MpvPropertyData) void,
    user_data: ?*anyopaque = null,

    pub fn call(self: MpvPropertyCallback, property_event: MpvEventProperty) void {
        self.callback(self.user_data, property_event.data);
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
    while (mpv.threading_info == null) {}

    var thread_info = mpv.threading_info.?;
    var iter = event_iterator(thread_info.event_handle.*);
    while (iter.next()) |event| {
        const eid = event.event_id;
        if (eid == .Shutdown) {
            thread_info.mutex.lock();
            thread_info.core_shutdown = true;
            thread_info.mutex.unlock();
        }

        thread_info.mutex.lock();
        for (thread_info.event_callbacks.items) |cb| {
            cb.call(event);
        }
        thread_info.mutex.unlock();

        if (eid == .PropertyChange) {
            const property = event.data.PropertyChange;
            if (thread_info.property_callbacks.get(property.name)) |cbs| {
                for (cbs.items) |cb| {
                    cb.call(property);
                }
            }
        }

        if (eid == .LogMessage) {
            if (thread_info.log_callback) |cb| {
                cb.call(event.data.LogMessage);
            }
        }

        if (eid == .CommandReply) {
            const key = event.reply_userdata;
            const cmd_error = event.event_error;
            const result = event.data.CommandReply.result;
            if (thread_info.command_reply_callbacks.get(key)) |cb| {
                cb.call(cmd_error, result);
            }
        }

        if (eid == .Shutdown) {
            thread_info.event_handle.destroy();
            break;
        }
    }
}

pub fn check_core_shutdown(mpv: Mpv) GenericError!void {
    if (mpv.threading_info) |thread_info| {
        if (thread_info.core_shutdown) return GenericError.CoreShutdown;
    }

}

pub fn register_event_callback(mpv: *Mpv, callback: MpvEventCallback) !MpvEventCallbackUnregisterrer {
    try mpv.check_core_shutdown();

    var thread_info = mpv.threading_info.?;
    try thread_info.event_callbacks.append(callback);

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
    var thread_info = mpv.threading_info.?;

    for (0.., thread_info.event_callbacks.items) |idx, cb| {
        if (std.meta.eql(cb, callback)) {
            _ = thread_info.event_callbacks.swapRemove(idx);
        }
    }
}

pub fn register_property_callback(mpv: *Mpv, callback: MpvPropertyCallback) !MpvPropertyCallbackUnregisterrer {
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
    var thread_info = mpv.threading_info.?;
    const args_hash = try utils.string_array_hash(mpv.allocator, callback.command_args);
    thread_info.event_handle.abort_async_command(args_hash);
    _ = thread_info.command_reply_callbacks.remove(args_hash);
}

pub fn register_log_message_handler(mpv: *Mpv, callback: MpvLogMessageCallback) !MpvLogMessageCallbackUnregisterrer {
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
    if (mpv.threading_info) |thread_info| {
        try mpv.request_log_messages(.None);
        thread_info.log_callback = null;
    }
}

pub fn wait_for_event(mpv: *Mpv, event_ids: []const MpvEventId) !void {
    try mpv.check_core_shutdown();
    const cb = struct {
        pub fn cb(user_data: ?*anyopaque, event: MpvEvent) void {
            _ = event;
            var received_event: *std.Thread.ResetEvent = @ptrCast(@alignCast(user_data.?));
            received_event.set();
        }
    }.cb;

    var received_event = std.Thread.ResetEvent{};
    const unregisterrer = try mpv.register_event_callback(MpvEventCallback{
        .event_ids = event_ids,
        .callback = &cb,
        .user_data = &received_event,
        .callback_cond = null,
    });
    received_event.wait();
    unregisterrer.unregister();
}

pub fn wait_for_property(mpv: *Mpv, property_name: []const u8) !void {
    try mpv.check_core_shutdown();
    const cb = struct {
        pub fn cb(user_data: ?*anyopaque, data: MpvPropertyData) void {
            // _ = data;
            std.log.debug("property-data {}", .{data});
            var received_event: *std.Thread.ResetEvent = @ptrCast(@alignCast(user_data.?));
            received_event.set();
        }
    }.cb;

    var received_event = std.Thread.ResetEvent{};
    try mpv.register_property_callback(MpvPropertyCallback{
        .property_name = property_name,
        .callback = &cb,
        .user_data = &received_event,
    });
    received_event.wait();
}



pub fn wait_for_playback(mpv: *Mpv) !void {
    try mpv.wait_for_event(&.{ .EndFile });
}

pub fn wait_until_playing(mpv: *Mpv) !void {
    try mpv.wait_for_event(&.{ .StartFile });
}

pub fn wait_until_pause(mpv: *Mpv) !void {
    try mpv.wait_for_property("core-idle");
}

pub fn wait_for_shutdown(mpv: *Mpv) !void {
    try mpv.wait_for_event(&.{.Shutdown});
}