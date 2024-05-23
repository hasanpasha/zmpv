const c = @import("../c.zig");
const testing = @import("std").testing;

pub const MpvEventId = enum(u8) {
    None = 0,
    Shutdown = 1,
    LogMessage = 2,
    GetPropertyReply = 3,
    SetPropertyReply = 4,
    CommandReply = 5,
    StartFile = 6,
    EndFile = 7,
    FileLoaded = 8,
    Idle = 11,
    Tick = 14,
    ClientMessage = 16,
    VideoReconfig = 17,
    AudioReconfig = 18,
    Seek = 20,
    PlaybackRestart = 21,
    PropertyChange = 22,
    QueueOverflow = 24,
    Hook = 25,

    pub fn to_c(self: MpvEventId) c.mpv_event_id {
        return @intCast(@intFromEnum(self));
    }
};

test "MpvEventId to" {
    try testing.expect(MpvEventId.AudioReconfig.to_c() == c.MPV_EVENT_AUDIO_RECONFIG);
    try testing.expect(MpvEventId.Tick.to_c() == c.MPV_EVENT_TICK);
    try testing.expect(MpvEventId.QueueOverflow.to_c() == c.MPV_EVENT_QUEUE_OVERFLOW);
    try testing.expect(MpvEventId.FileLoaded.to_c() != c.MPV_EVENT_COMMAND_REPLY);
}
