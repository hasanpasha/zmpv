const c = @import("../c.zig");
const std = @import("std");
const testing = std.testing;
const mpv_event_utils = @import("./mpv_event_utils.zig");

const Self = @This();

prefix: []const u8,
level: []const u8,
text: []const u8,
log_level: MpvLogLevel,

pub fn from(data_ptr: *anyopaque) Self {
    const log = mpv_event_utils.cast_event_data(data_ptr, c.mpv_event_log_message);
    return Self{
        .prefix = std.mem.sliceTo(log.prefix, 0),
        .level = std.mem.sliceTo(log.level, 0),
        .text = std.mem.sliceTo(log.text, 0),
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

    pub fn to_string(self: MpvLogLevel) []const u8 {
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

test "MpvEventLogMessage from" {
    var log_event_data = c.mpv_event_log_message{
        .log_level = c.MPV_LOG_LEVEL_V,
        .level = "v",
        .prefix = "simple",
        .text = "this is a test log",
    };
    const z_log = Self.from(&log_event_data);

    try testing.expect(z_log.log_level == .V);
    try testing.expect(std.mem.eql(u8, z_log.level, "v"));
    try testing.expect(std.mem.eql(u8, z_log.prefix, "simple"));
    try testing.expect(std.mem.eql(u8, z_log.text, "this is a test log"));
}
