const c = @import("./c.zig");
const testing = @import("std").testing;

pub const MpvEventId = enum(c.mpv_event_id) {
    None = c.MPV_EVENT_NONE,
    Shutdown = c.MPV_EVENT_SHUTDOWN,
    LogMessage = c.MPV_EVENT_LOG_MESSAGE,
    GetPropertyReply = c.MPV_EVENT_GET_PROPERTY_REPLY,
    SetPropertyReply = c.MPV_EVENT_SET_PROPERTY_REPLY,
    CommandReply = c.MPV_EVENT_COMMAND_REPLY,
    StartFile = c.MPV_EVENT_START_FILE,
    EndFile = c.MPV_EVENT_END_FILE,
    FileLoaded = c.MPV_EVENT_FILE_LOADED,
    Idle = c.MPV_EVENT_IDLE,
    Tick = c.MPV_EVENT_TICK,
    ClientMessage = c.MPV_EVENT_CLIENT_MESSAGE,
    VideoReconfig = c.MPV_EVENT_VIDEO_RECONFIG,
    AudioReconfig = c.MPV_EVENT_AUDIO_RECONFIG,
    Seek = c.MPV_EVENT_SEEK,
    PlaybackRestart = c.MPV_EVENT_PLAYBACK_RESTART,
    PropertyChange = c.MPV_EVENT_PROPERTY_CHANGE,
    QueueOverflow = c.MPV_EVENT_QUEUE_OVERFLOW,
    Hook = c.MPV_EVENT_HOOK,

    pub fn from(event_id: c.mpv_event_id) MpvEventId {
        return @enumFromInt(event_id);
    }

    pub fn to_c(self: MpvEventId) c.mpv_event_id {
        return @intFromEnum(self);
    }
};

test "MpvEventId to" {
    try testing.expect(MpvEventId.AudioReconfig.to_c() == c.MPV_EVENT_AUDIO_RECONFIG);
    try testing.expect(MpvEventId.Tick.to_c() == c.MPV_EVENT_TICK);
    try testing.expect(MpvEventId.QueueOverflow.to_c() == c.MPV_EVENT_QUEUE_OVERFLOW);
    try testing.expect(MpvEventId.FileLoaded.to_c() != c.MPV_EVENT_COMMAND_REPLY);
}
