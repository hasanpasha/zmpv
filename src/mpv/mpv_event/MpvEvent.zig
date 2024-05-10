const mpv_error = @import("../errors/mpv_error.zig");
const MpvError = mpv_error.MpvError;
const MpvEventEndFile = @import("./MpvEventEndFile.zig");
const MpvEventStartFile = @import("./MpvEventStartFile.zig");
const MpvEventProperty = @import("./MpvEventProperty.zig");
const MpvEventId = @import("./mpv_event_id.zig").MpvEventId;
const c = @import("../c.zig");

const Self = @This();

event_id: MpvEventId,
event_error: MpvError,
data: ?MpvEventData,

pub fn from(c_event: [*c]c.struct_mpv_event) Self {
    const event: *c.mpv_event = @ptrCast(c_event);

    const event_id: MpvEventId = @enumFromInt(event.event_id);

    return Self{
        .event_id = event_id,
        .event_error = mpv_error.from_mpv_c_error(event.@"error"),
        .data = switch (event_id) {
            .EndFile => MpvEventData{
                .EndFile = MpvEventEndFile.from(event.data),
            },
            .StartFile => MpvEventData{
                .StartFile = MpvEventStartFile.from(event.data),
            },
            .PropertyChange => MpvEventData{
                .PropertyChange = MpvEventProperty.from(event.data),
            },
            else => null,
        },
    };
}

pub const MpvEventData = union(enum) {
    // None: void,
    // Shutdown: void,
    // LogMessage: void,
    // GetPropertyReply: void,
    // SetPropertyReply: void,
    // CommandReply: void,
    StartFile: MpvEventStartFile,
    EndFile: MpvEventEndFile,
    // FileLoaded: void,
    // Idle: void,
    // Tick: void,
    // ClientMessage: void,
    // VideoReconfig: void,
    // AudioReconfig: void,
    // Seek: void,
    // PlaybackRestart: void,
    PropertyChange: MpvEventProperty,
    // QueueOverflow: void,
    // Hook: void,
};
