const std = @import("std");
const ResetEvent = std.Thread.ResetEvent;

const Self = @This();

value: ?*anyopaque = null,
error_value: anyerror = error.Success,
reset_event: ResetEvent,
arena: std.heap.ArenaAllocator,

const FutureError = error {
    Canceled,
};

pub fn new(allocator: std.mem.Allocator) !*Self {
    var arena = std.heap.ArenaAllocator.init(allocator);

    const this = try arena.allocator().create(Self);
    this.* = .{
        .reset_event = ResetEvent{},
        .arena = arena,
    };
    return this;
}

pub fn free(self: *Self) void {
    self.arena.deinit();
}

pub fn wait_result(self: *Self, timeout: ?u64) !*anyopaque {
    if (timeout) |t| {
        try self.reset_event.timedWait(t);
    } else {
        self.reset_event.wait();
    }

    return self.value orelse self.error_value;
}

fn set(self: *Self) void {
    if (!self.reset_event.isSet()) {
        self.reset_event.set();
    }
}

pub fn set_result(self: *Self, value: anytype) !void {
    var arena = self.arena;
    const value_ptr = try arena.allocator().create(@TypeOf(value));
    value_ptr.* = value;

    self.value = value_ptr;
    self.set();
}

pub fn set_error(self: *Self, error_value: anyerror) void {
    self.error_value = error_value;
    self.set();
}

pub fn cancel(self: *Self) void {
    self.set_error(FutureError.Canceled);
}