const std = @import("std");
const Mpv = @import("./Mpv.zig");
const MpvEventId = @import("./mpv_event_id.zig").MpvEventId;

pub const MpvEventCallback = struct {
    registered_event_ids: []const MpvEventId,
    callback: *const fn (?*anyopaque) void,
    user_data: ?*anyopaque,

    pub fn call(self: MpvEventCallback, event_id: MpvEventId) !void {
        std.log.debug("MpvEventCallback called", .{});
        for (self.registered_event_ids) |registerd_event_id| {
            std.log.debug("trying cb", .{});
            if (registerd_event_id == event_id) {
                std.log.debug("calling cb", .{});
                self.callback(self.user_data);
            }
        }
    }
};

pub fn event_loop(self: *Mpv) !void {
    // std.log.debug("called event loop {}", .{self.threading});
    // if (!self.threading) {
    //     std.log.debug("cannot run event loop", .{});
    //     return;
    // }

    std.log.debug("started event loop", .{});
    while (true) {
        // std.log.debug("running event_loop", .{});
        const event = try self.wait_event(0);

        const locked = self.mutex.tryLock();
        if (locked) {
            // std.log.debug("num of cbs: {}", .{self.event_callbacks.?.items.len});
            for (self.event_callbacks.?.items) |cb| {
                try cb.call(event.event_id);
            }
            self.mutex.unlock();
        }

        switch (event.event_id) {
            .EndFile => break,
            else => {},
        }
    }
}

pub fn register_event_callback(self: *Mpv, event_callback: MpvEventCallback) !void {
    // if (!self.threading) return;
    // _ = event_callback;
    const locked = self.mutex.tryLock();
    if (locked) {
        std.log.debug("adding new callback", .{});
        try self.event_callbacks.?.append(event_callback);
        std.log.debug("size of cbs: {}", .{self.event_callbacks.?.items.len});
        self.mutex.unlock();
    }
}