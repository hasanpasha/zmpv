const testing = @import("std").testing;
const utils = @import("../utils.zig");
const c = @import("../c.zig");

const Self = @This();

playlist_entry_id: i64,

pub fn from(data_ptr: *anyopaque) Self {
    const data = utils.cast_event_data(data_ptr, c.mpv_event_start_file);
    return Self{
        .playlist_entry_id = data.playlist_entry_id,
    };
}

test "MpvEventStartFile" {
    var start_file_event = c.mpv_event_start_file{
        .playlist_entry_id = 0,
    };
    const z_data = Self.from(&start_file_event);

    try testing.expect(z_data.playlist_entry_id == 0);
}
