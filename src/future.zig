const std = @import("std");
const ResetEvent = std.Thread.ResetEvent;

pub fn Future(T: type) type {
    return struct {
        value: ?T = null,
        error_value: anyerror = error.Success,
        reset_event: ResetEvent = ResetEvent{},
        allocator: std.mem.Allocator,

        const FutureError = error {
            Canceled,
        };

        const Self = @This();

        pub fn new(allocator: std.mem.Allocator) !*Self {
            const this = try allocator.create(Self);
            this.* = .{
                .allocator = allocator,
            };
            return this;
        }

        pub fn free(self: *Self) void {
            const allocator = self.allocator;
            allocator.destroy(self);
        }

        pub fn wait_result(self: *Self, timeout: ?u64) !T {
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

        pub fn set_result(self: *Self, value: T) !void {
            self.value = value;

            self.set();
        }

        pub fn set_error(self: *Self, error_value: anyerror) void {
            self.error_value = error_value;
            self.set();
        }

        pub fn cancel(self: *Self) void {
            self.set_error(FutureError.Canceled);
        }
    };

}
