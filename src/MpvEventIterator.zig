const Mpv = @import("Mpv.zig");
const MpvEvent = @import("MpvEvent.zig");

handle: Mpv,
wait_flag: MpvEventIteratorWaitFlag = .{ .IndefiniteWait = {} },

pub const MpvEventIteratorWaitFlag = union(enum) {
    NoWait: void,
    IndefiniteWait: void,
    TimedWait: f64,
};

pub fn next(self: @This()) ?MpvEvent {
    const timeout: f64 = switch (self.wait_flag) {
        .NoWait => 0,
        .IndefiniteWait => -1,
        .TimedWait => |value| value,
    };

    const event = self.handle.wait_event(timeout);
    if (event.event_id == .None) return null;
    return event;
}