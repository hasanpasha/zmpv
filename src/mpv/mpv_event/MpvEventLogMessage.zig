const c = @import("../c.zig");
const std = @import("std");
const mpv_event_utils = @import("./mpv_event_utils.zig");

const Self = @This();

prefix: []const u8,
level: []const u8,
text: []const u8,
log_level: MpvLogLevel,

pub fn from(data_ptr: *anyopaque) Self {
    const log = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_log_message);
    return Self{
        .prefix = std.mem.span(log.prefix),
        .level = std.mem.span(log.level),
        .text = std.mem.span(log.text),
        .log_level = @enumFromInt(log.log_level),
    };
}

pub const MpvLogLevel = enum(u8) {
    None = 0,
    Fatal = 10,
    Error = 20,
    Warn = 30,
    Info = 40,
    V = 50,
    Debug = 60,
    Trace = 70,

    pub fn to_c_string(self: MpvLogLevel) [*c]const u8 {
        return switch (self) {
            .None => "no",
            .Fatal => "fatal",
            .Error => "error",
            .Warn => "warn",
            .Info => "info",
            .V => "v",
            .Debug => "debug",
            .Trace => "trace",
        };
    }
};
