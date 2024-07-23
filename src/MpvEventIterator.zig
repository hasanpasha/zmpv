const Mpv = @import("Mpv.zig");
const MpvEvent = @import("MpvEvent.zig");

handle: Mpv,
wait_flag: MpvEventIteratorWaitFlag = .{ .IndefiniteWait = {} },

pub const MpvEventIteratorWaitFlag = union(enum) {
    NoWait: void,
    IndefiniteWait: void,
    TimedWait: f64,

    pub fn to_c(self: @This()) f64 {
        return switch (self) {
            .NoWait => 0,
            .IndefiniteWait => -1,
            .TimedWait => |value| value,
        };
    }
};

pub fn next(self: @This()) ?MpvEvent {
    const event = self.handle.wait_event(self.wait_flag.to_c());
    if (event.event_id == .None) return null;
    return event;
}