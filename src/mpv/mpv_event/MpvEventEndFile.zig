const mpv_error = @import("../errors/mpv_error.zig");
const MpvError = mpv_error.MpvError;
const mpv_event_utils = @import("./mpv_event_utils.zig");
const c = @import("../c.zig");

const Self = @This();

event_error: MpvError,

pub fn from(data_ptr: ?*anyopaque) Self {
    const data = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_end_file);
    return Self{
        .event_error = mpv_error.from_mpv_c_error(data.@"error"),
    };
}
