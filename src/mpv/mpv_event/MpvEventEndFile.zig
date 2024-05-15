const mpv_error = @import("../errors/mpv_error.zig");
const MpvError = mpv_error.MpvError;
const mpv_event_utils = @import("./mpv_event_utils.zig");
const c = @import("../c.zig");

const Self = @This();

reason: MpvEventEndFileReason,
playlist_entry_id: i64,
playlist_insert_id: i64,
playlist_insert_num_entries: i64,
event_error: MpvError,

pub fn from(data_ptr: *anyopaque) Self {
    const data = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_end_file);
    return Self{
        .reason = @enumFromInt(data.reason),
        .playlist_entry_id = data.playlist_entry_id,
        .playlist_insert_id = data.playlist_insert_id,
        .playlist_insert_num_entries = @intCast(data.playlist_insert_num_entries),
        .event_error = mpv_error.from_mpv_c_error(data.@"error"),
    };
}

const MpvEventEndFileReason = enum(u8) {
    Eof = 0,
    Stop = 2,
    Quit = 3,
    Error = 4,
    Redirect = 5,
};
