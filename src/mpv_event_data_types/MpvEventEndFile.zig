const mpv_error = @import("../mpv_error.zig");
const MpvError = mpv_error.MpvError;
const utils = @import("../utils.zig");
const c = @import("../c.zig");
const testing = @import("std").testing;

const Self = @This();

reason: MpvEventEndFileReason,
playlist_entry_id: i64,
playlist_insert_id: i64,
playlist_insert_num_entries: i64,
event_error: MpvError,

pub fn from(data_ptr: *anyopaque) Self {
    const data = utils.casted_anyopaque_ptr_value(c.mpv_event_end_file, data_ptr);
    return Self{
        .reason = MpvEventEndFileReason.from(data.reason),
        .playlist_entry_id = data.playlist_entry_id,
        .playlist_insert_id = data.playlist_insert_id,
        .playlist_insert_num_entries = @intCast(data.playlist_insert_num_entries),
        .event_error = mpv_error.from_mpv_c_error(data.@"error"),
    };
}

const MpvEventEndFileReason = enum(c.mpv_end_file_reason) {
    Eof = c.MPV_END_FILE_REASON_EOF,
    Stop = c.MPV_END_FILE_REASON_STOP,
    Quit = c.MPV_END_FILE_REASON_QUIT,
    Error = c.MPV_END_FILE_REASON_ERROR,
    Redirect = c.MPV_END_FILE_REASON_REDIRECT,

    pub fn from(reason: c.mpv_end_file_reason) MpvEventEndFileReason {
        return @enumFromInt(reason);
    }
};

test "MpvEventEndFile from" {
    var event_end_file = c.mpv_event_end_file{
        .@"error" = c.MPV_ERROR_SUCCESS,
        .playlist_entry_id = 0,
        .playlist_insert_id = 0,
        .playlist_insert_num_entries = 0,
        .reason = c.MPV_END_FILE_REASON_QUIT,
    };
    const z_event_end_file = Self.from(&event_end_file);

    try testing.expect(z_event_end_file.event_error == MpvError.Success);
    try testing.expect(z_event_end_file.playlist_entry_id == 0);
    try testing.expect(z_event_end_file.playlist_insert_id == 0);
    try testing.expect(z_event_end_file.playlist_insert_num_entries == 0);
    try testing.expect(z_event_end_file.reason == .Quit);
}
